class_name SafehouseSection
extends VBoxContainer

## The Safehouse part of the Turf page: cash box, stash, upgrades and lying low.
## Everything works only while the player stands in a district they hold.

const ITEM_ROW := preload("res://ui/components/item_row.tscn")
const HOME_ICON: Texture2D = preload("res://assets/icons/hud/house.svg")
const CASH_ICON: Texture2D = preload("res://assets/icons/hud/landmark.svg")
const UPGRADE: StringName = &"upgrade"
const LIE_LOW: StringName = &"lie_low"
const LEAVE: StringName = &"leave"
const DEPOSIT_PREFIX := "deposit:"
const WITHDRAW_PREFIX := "withdraw:"
const LOCKED := "LOCKED"


func _ready() -> void:
	add_theme_constant_override("separation", 0)
	_build(GameState.run)


func _build(run: RunState) -> void:
	var open := Safehouse.is_open(run)
	_add_heading("SAFEHOUSE")
	if not open:
		_add_note("Locked here. Your safehouse opens in any district you hold.")
	_add_cash_box(run, open)
	_add_stash(run, open)
	_add_upgrade(run, open)
	_add_row(Safehouse.LIE_LOW_ICON, "Lie low", "1 phase", "Skip a phase, lose %d extra heat" % Safehouse.LIE_LOW_HEAT,
		"TAP TO REST" if open else LOCKED, _talk_about_lying_low if open else Callable())


func _add_cash_box(run: RunState, open: bool) -> void:
	var can_move := open and (run.cash > 0 or run.stashed_cash > 0)
	var detail := "TAP TO MOVE CASH" if can_move else ("NO CASH" if open else LOCKED)
	_add_row(CASH_ICON, "Cash box", Format.money(run.stashed_cash), "Nobody can take cash kept here",
		detail, _talk_about_cash if can_move else Callable())


func _add_stash(run: RunState, open: bool) -> void:
	var capacity := Safehouse.stash_capacity(run)
	if capacity <= 0:
		_add_row(HOME_ICON, "No stash", "", "Room for a crew of %d. Build a lockbox to keep goods safe from raids." % Crew.cap(run))
		return
	_add_row(HOME_ICON, Safehouse.stash_name(run), "%d / %d slots" % [Inventory.stash_used(run), capacity], "Room for a crew of %d. Goods here are safe from raids." % Crew.cap(run))
	for item_id: StringName in run.stash:
		var item := Content.item(item_id)
		if item == null:
			continue
		var can_take := open and Inventory.max_from_stash(run, item) > 0
		var detail := "TAP TO TAKE" if can_take else ("BAG FULL" if open else LOCKED)
		_add_item_row(item, "x%d" % Inventory.stashed(run, item_id), "Stored", detail, can_take, _ask_amount.bind(item, false))
	if not open:
		return
	for item_id: StringName in run.inventory:
		var item := Content.item(item_id)
		if item == null:
			continue
		var can_stash := Inventory.max_to_stash(run, item) > 0
		_add_item_row(item, "x%d" % Inventory.count(run, item_id), "In your bag", "TAP TO STASH" if can_stash else "STASH FULL", can_stash, _ask_amount.bind(item, true))


func _add_upgrade(run: RunState, open: bool) -> void:
	var upgrade := Safehouse.next_upgrade(run)
	if upgrade.is_empty():
		return
	var affordable := Safehouse.can_upgrade(run)
	var detail := LOCKED
	if open:
		detail = "TAP TO BUILD" if affordable else "NOT ENOUGH CASH"
	_add_row(Safehouse.UPGRADE_ICON, str(upgrade.name), Format.money(int(upgrade.price)), "Room for %d slots and one more crew" % int(upgrade.capacity),
		detail, _talk_about_upgrade if affordable else Callable())


func _talk_about_cash() -> void:
	var run := GameState.run
	var choices: Array[DialogueChoice] = []
	for amount in _amount_steps(run.cash):
		choices.append(DialogueChoice.new(StringName(DEPOSIT_PREFIX + str(amount)), "Put away %s" % Format.money(amount)))
	for amount in _amount_steps(run.stashed_cash):
		choices.append(DialogueChoice.new(StringName(WITHDRAW_PREFIX + str(amount)), "Take out %s" % Format.money(amount)))
	choices.append(DialogueChoice.new(LEAVE, "Cancel", true, true))
	var line := "%s on me, %s in the cash box." % [Format.money(run.cash), Format.money(run.stashed_cash)]
	GameOverlay.talk(_player(), line, choices, _on_cash_choice, "Muggers, raids, Vex and the Shark's men only take what you carry.")


func _on_cash_choice(choice: StringName) -> void:
	GameOverlay.end_talk()
	var id := String(choice)
	var moved := false
	if id.begins_with(DEPOSIT_PREFIX):
		moved = GameState.deposit_cash(int(id.trim_prefix(DEPOSIT_PREFIX)))
	elif id.begins_with(WITHDRAW_PREFIX):
		moved = GameState.withdraw_cash(int(id.trim_prefix(WITHDRAW_PREFIX)))
	if moved:
		AudioService.play_sfx(Sfx.STASH_MOVE)


func _ask_amount(item: ItemDef, to_stash: bool) -> void:
	var run := GameState.run
	var most := Inventory.max_to_stash(run, item) if to_stash else Inventory.max_from_stash(run, item)
	var verb := "Stash" if to_stash else "Take"
	var choices: Array[DialogueChoice] = []
	for amount in _amount_steps(most, true):
		choices.append(DialogueChoice.new(StringName(str(amount)), "%s %d" % [verb, amount]))
	choices.append(DialogueChoice.new(LEAVE, "Cancel", true, true))
	var line := "How many %s do I %s?" % [item.display_name, "put away" if to_stash else "take with me"]
	GameOverlay.talk(_player(), line, choices, _on_amount_chosen.bind(item, to_stash))


func _on_amount_chosen(choice: StringName, item: ItemDef, to_stash: bool) -> void:
	GameOverlay.end_talk()
	if choice == LEAVE:
		return
	var amount := int(String(choice))
	var moved := GameState.move_to_stash(item, amount) if to_stash else GameState.take_from_stash(item, amount)
	if moved:
		AudioService.play_sfx(Sfx.STASH_MOVE)


func _talk_about_upgrade() -> void:
	var upgrade := Safehouse.next_upgrade(GameState.run)
	var line := "A %s would hold %d slots. %s for the parts and the guy who fits it." % [str(upgrade.name).to_lower(), int(upgrade.capacity), Format.money(int(upgrade.price))]
	var choices: Array[DialogueChoice] = [
		DialogueChoice.new(UPGRADE, "Build it for %s" % Format.money(int(upgrade.price))),
		DialogueChoice.new(LEAVE, "Not now", true, true),
	]
	GameOverlay.talk(_player(), line, choices, _on_upgrade_choice)


func _on_upgrade_choice(choice: StringName) -> void:
	GameOverlay.end_talk()
	if choice == UPGRADE and GameState.buy_stash_upgrade():
		AudioService.play_sfx(Sfx.STASH_UPGRADE)


func _talk_about_lying_low() -> void:
	var line := "I could stay in, keep the lights off and let the street forget me for a while."
	var choices: Array[DialogueChoice] = [
		DialogueChoice.new(LIE_LOW, "Lie low until next phase"),
		DialogueChoice.new(LEAVE, "Not now", true, true),
	]
	var hint := "Time moves on one phase. Heat drops by %d on top of the usual cooling." % Safehouse.LIE_LOW_HEAT
	GameOverlay.talk(_player(), line, choices, _on_lie_low_choice, hint)


func _on_lie_low_choice(choice: StringName) -> void:
	GameOverlay.end_talk()
	if choice == LIE_LOW and GameState.lie_low():
		AudioService.play_sfx(Sfx.LIE_LOW)


func _player() -> PlayerDef:
	return Content.player(GameState.run.player_id)


## All, half and, for goods, one. Duplicates and zero are dropped.
func _amount_steps(most: int, include_one := false) -> Array[int]:
	var steps: Array[int] = []
	var candidates := [most, ceili(most / 2.0)]
	if include_one:
		candidates.append(1)
	for amount: int in candidates:
		if amount > 0 and not steps.has(amount):
			steps.append(amount)
	return steps


func _add_heading(text: String) -> void:
	var label := Label.new()
	label.theme_type_variation = &"ListHeading"
	label.text = text
	add_child(label)


func _add_note(text: String) -> void:
	var label := Label.new()
	label.theme_type_variation = &"MutedLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	add_child(label)


func _add_row(icon: Texture2D, title: String, value: String, caption: String, detail := "", action := Callable()) -> void:
	var row: ItemRow = ITEM_ROW.instantiate()
	add_child(row)
	row.show_entry(icon, title, value, caption, detail, Palette.TEXT_CREAM if action.is_valid() else Palette.TEXT_MUTED)
	_connect(row, action)


func _add_item_row(item: ItemDef, value: String, caption: String, detail: String, enabled: bool, action: Callable) -> void:
	var row: ItemRow = ITEM_ROW.instantiate()
	add_child(row)
	row.display(item, value, caption, detail, Palette.TEXT_CREAM if enabled else Palette.TEXT_MUTED)
	_connect(row, action if enabled else Callable())


func _connect(row: ItemRow, action: Callable) -> void:
	if action.is_valid():
		row.item_selected.connect(func(_item: ItemDef) -> void: action.call())
	else:
		row.disabled = true
