extends VenueScreen

const UPGRADE: StringName = &"upgrade"
const LIE_LOW: StringName = &"lie_low"
const GREETINGS: Array[String] = [
	"Four walls and a lock. Nobody knows about this place.",
	"Home, for now. Nobody followed me.",
]

var _player: PlayerDef


func _ready() -> void:
	var district: DistrictDef = GameState.current_district() if GameState.run != null else null
	var venue := Content.venue(Safehouse.VENUE)
	if district == null or venue == null or not Safehouse.is_here(GameState.run):
		SceneRouter.go_to.call_deferred(SceneRouter.TITLE_SCREEN if district == null else SceneRouter.DISTRICT_SCREEN)
		return
	_player = Content.player(GameState.run.player_id)
	setup(venue.background if venue.background != null else district.background, venue.display_name, _player, GREETINGS.pick_random())


func _refresh() -> void:
	super()
	var run := GameState.run
	var capacity := Safehouse.stash_capacity(run)
	if capacity > 0:
		_add_label("%s  %d / %d" % [Safehouse.stash_name(run).to_upper(), Inventory.stash_used(run), capacity], &"ListHeading")
		if run.stash.is_empty():
			_add_label("Nothing stored. Goods kept here are safe from raids.", &"MutedLabel")
		for item_id: StringName in run.stash:
			var item := Content.item(item_id)
			if item == null:
				continue
			var can_take := Inventory.max_from_stash(run, item) > 0
			var row := _add_row()
			row.display(item, "x%d" % Inventory.stashed(run, item_id), "Stored, safe from raids", "TAP TO TAKE" if can_take else "BAG FULL", Palette.TEXT_CREAM if can_take else Palette.TEXT_MUTED)
			row.item_selected.connect(_ask_amount.bind(false))
	else:
		_add_label("STASH", &"ListHeading")
		_add_label("No stash yet. Put in a lockbox below to keep goods off the street and away from raids.", &"MutedLabel")

	_add_label("YOUR BAG", &"ListHeading")
	if run.inventory.is_empty():
		_add_label("Your bag is empty.", &"MutedLabel")
	for item_id: StringName in run.inventory:
		var item := Content.item(item_id)
		if item == null:
			continue
		var detail := ""
		if capacity > 0:
			detail = "TAP TO STASH" if Inventory.max_to_stash(run, item) > 0 else "STASH FULL"
		var row := _add_row()
		row.display(item, "x%d" % Inventory.count(run, item_id), "Paid %s each" % Format.money(int(run.cost_basis.get(item_id, 0))), detail, Palette.TEXT_CREAM if detail == "TAP TO STASH" else Palette.TEXT_MUTED)
		if capacity > 0:
			row.item_selected.connect(_ask_amount.bind(true))

	_add_label("UPGRADES", &"ListHeading")
	_add_upgrade_row()
	_add_label("REST", &"ListHeading")
	var lie_low := _add_row()
	lie_low.show_entry(Safehouse.LIE_LOW_ICON, "Lie low", "1 phase", "Skip a phase, lose %d extra heat" % Safehouse.LIE_LOW_HEAT, "TAP TO REST", Palette.TEXT_CREAM)
	lie_low.item_selected.connect(func(_item: ItemDef) -> void: _talk_about_lying_low())


func _add_upgrade_row() -> void:
	var run := GameState.run
	var upgrade := Safehouse.next_upgrade(run)
	if upgrade.is_empty():
		_add_label("The vault is in. There is nothing left to build.", &"MutedLabel")
		return
	var affordable := Safehouse.can_upgrade(run)
	var caption := "Room for %d slots, safe from raids" % int(upgrade.capacity)
	var row := _add_row()
	row.show_entry(Safehouse.UPGRADE_ICON, str(upgrade.name), Format.money(int(upgrade.price)), caption, "TAP TO BUILD" if affordable else "NOT ENOUGH CASH", Palette.TEXT_CREAM if affordable else Palette.TEXT_MUTED)
	row.item_selected.connect(func(_item: ItemDef) -> void: _talk_about_upgrade())


func _ask_amount(item: ItemDef, to_stash: bool) -> void:
	var run := GameState.run
	var most := Inventory.max_to_stash(run, item) if to_stash else Inventory.max_from_stash(run, item)
	if most <= 0:
		says("No room for any more %s." % item.display_name if to_stash else "My bag is full.")
		return
	var amounts: Array[int] = []
	for amount in [most, ceili(most / 2.0), 1]:
		if not amounts.has(amount):
			amounts.append(amount)
	var verb := "Stash" if to_stash else "Take"
	var choices: Array[DialogueChoice] = []
	for amount in amounts:
		choices.append(DialogueChoice.new(StringName(str(amount)), "%s %d" % [verb, amount]))
	choices.append(DialogueChoice.new(LEAVE, "Cancel", true, true))
	var line := "How many %s do I %s?" % [item.display_name, "put away" if to_stash else "take with me"]
	GameOverlay.talk(_player, line, choices, _on_amount_chosen.bind(item, to_stash))


func _on_amount_chosen(choice: StringName, item: ItemDef, to_stash: bool) -> void:
	GameOverlay.end_talk()
	if choice == LEAVE:
		return
	var amount := int(String(choice))
	var moved := GameState.move_to_stash(item, amount) if to_stash else GameState.take_from_stash(item, amount)
	if moved:
		AudioService.play_sfx(Sfx.STASH_MOVE)


func _talk_about_upgrade() -> void:
	var run := GameState.run
	var upgrade := Safehouse.next_upgrade(run)
	var line := "A %s would hold %d slots. %s for the parts and the guy who fits it." % [str(upgrade.name).to_lower(), int(upgrade.capacity), Format.money(int(upgrade.price))]
	var choices: Array[DialogueChoice] = [
		DialogueChoice.new(UPGRADE, "Build it for %s" % Format.money(int(upgrade.price)), Safehouse.can_upgrade(run)),
		DialogueChoice.new(LEAVE, "Not now", true, true),
	]
	GameOverlay.talk(_player, line, choices, _on_upgrade_choice)


func _on_upgrade_choice(choice: StringName) -> void:
	if choice != UPGRADE:
		GameOverlay.end_talk()
		return
	var reply := "I can't afford it yet."
	if GameState.buy_stash_upgrade():
		AudioService.play_sfx(Sfx.STASH_UPGRADE)
		var run := GameState.run
		reply = "Done. The %s holds %d slots now." % [Safehouse.stash_name(run).to_lower(), Safehouse.stash_capacity(run)]
	GameOverlay.say(reply, _leave_choice(), _end_talk, false)


func _talk_about_lying_low() -> void:
	var line := "I could stay in, keep the lights off and let the street forget me for a while."
	var choices: Array[DialogueChoice] = [
		DialogueChoice.new(LIE_LOW, "Lie low until next phase"),
		DialogueChoice.new(LEAVE, "Not now", true, true),
	]
	var hint := "Time moves on one phase. Heat drops by %d on top of the usual cooling." % Safehouse.LIE_LOW_HEAT
	GameOverlay.talk(_player, line, choices, _on_lie_low_choice, hint)


func _on_lie_low_choice(choice: StringName) -> void:
	GameOverlay.end_talk()
	if choice == LIE_LOW and GameState.lie_low():
		AudioService.play_sfx(Sfx.LIE_LOW)
