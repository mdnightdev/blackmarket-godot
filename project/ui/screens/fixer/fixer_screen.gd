extends VenueScreen

const CLEAN_UP: StringName = &"clean_up"
const SOLD_LINES: Array[String] = [
	"It's yours. Look after it.",
	"Good choice. No receipts.",
	"Pleasure. Tell nobody where you got it.",
]

@onready var _trade_sheet: TradeSheet = %TradeSheet

var _host: CharacterDef


func _ready() -> void:
	var district: DistrictDef = GameState.current_district() if GameState.run != null else null
	var venue := Content.venue(GameState.visiting_venue)
	_host = Content.character(venue.host) if venue != null else null
	if district == null or _host == null or not district.venues.has(venue.id):
		SceneRouter.go_to.call_deferred(SceneRouter.TITLE_SCREEN if district == null else SceneRouter.DISTRICT_SCREEN)
		return
	_trade_sheet.completed.connect(_on_gear_bought)
	setup(venue.background if venue.background != null else district.background, venue.display_name, _host, _host.line)


func can_present_encounter() -> bool:
	return super() and not _trade_sheet.visible


func handle_back() -> bool:
	if _trade_sheet.visible:
		_trade_sheet.close()
		return true
	return super()


func _refresh() -> void:
	super()
	_add_label("CLEAN-UP", &"SectionLabel")
	_add_clean_up_row()
	_add_label("GEAR", &"SectionLabel")
	var run := GameState.run
	for item in Content.items(ItemDef.Kind.EQUIPMENT):
		var row := _add_row()
		if Gear.owns(run, item.id):
			row.display(item, "Owned", Gear.describe(item))
		else:
			var affordable := run.cash >= item.base_price
			row.display(item, Format.money(item.base_price), Gear.describe(item), "TAP TO BUY" if affordable else "NOT ENOUGH CASH", Palette.TEXT_CREAM if affordable else Palette.TEXT_MUTED)
		row.item_selected.connect(func(selected: ItemDef) -> void: _trade_sheet.show_trade(TradeSheet.Mode.GEAR, selected, null))


func _add_clean_up_row() -> void:
	var run := GameState.run
	var detail := "TAP TO TALK"
	if run.heat <= 0:
		detail = "NO HEAT ON YOU"
	elif Fixer.cleaned_up(run):
		detail = "DONE THIS PHASE"
	elif run.cash < Fixer.clean_up_cost(run):
		detail = "NOT ENOUGH CASH"
	var caption := "Drops your heat by up to %d. Once per phase." % Fixer.CLEAN_UP_HEAT
	var row := _add_row()
	row.show_entry(Fixer.CLEAN_UP_ICON, "Make the heat go away", Format.money(Fixer.clean_up_cost(run)), caption, detail, Palette.TEXT_CREAM if Fixer.can_clean_up(run) else Palette.TEXT_MUTED)
	row.item_selected.connect(func(_item: ItemDef) -> void: _talk_about_clean_up())


func _talk_about_clean_up() -> void:
	var run := GameState.run
	if run.heat <= 0:
		says("Nobody is looking for you. Keep your money.")
		return
	if Fixer.cleaned_up(run):
		says("I already made calls for you this phase. Give it time.")
		return
	var cost := Fixer.clean_up_cost(run)
	var line := "Your heat is at %d. %s and %d of it goes away. Files get lost, witnesses get forgetful." % [run.heat, Format.money(cost), Fixer.heat_removed(run)]
	var choices: Array[DialogueChoice] = [
		DialogueChoice.new(CLEAN_UP, "Pay %s" % Format.money(cost), Fixer.can_clean_up(run)),
		DialogueChoice.new(LEAVE, "Not now", true, true),
	]
	GameOverlay.talk(_host, line, choices, _on_clean_up_choice, "Heat brings police stops, and a raid when it maxes out.")


func _on_clean_up_choice(choice: StringName) -> void:
	if choice != CLEAN_UP:
		GameOverlay.end_talk()
		return
	var removed := GameState.clean_up_heat()
	if removed > 0:
		AudioService.play_sfx(Sfx.CLEAN_UP)
		GameOverlay.say("Done. %d heat gone. Try not to get famous again." % removed, _leave_choice(), _end_talk)
	else:
		GameOverlay.say("Come back when you have the cash.", _leave_choice(), _end_talk)


func _on_gear_bought(_message: String, _cash_delta: int, _haggled: bool) -> void:
	AudioService.play_sfx(Sfx.GEAR_BUY)
	says(SOLD_LINES.pick_random())
