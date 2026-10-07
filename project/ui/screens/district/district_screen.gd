extends Control

const FAB_BUTTON := preload("res://ui/components/fab_button.tscn")
const PERSON_CHIP := preload("res://ui/components/person_chip.tscn")
const ROLE_COLORS := {
	CharacterDef.Role.LENDER: Palette.TEXT_CREAM,
	CharacterDef.Role.POLICE: Palette.RISK_HIGH,
	CharacterDef.Role.INFORMANT: Palette.PRICE,
	CharacterDef.Role.RIVAL: Palette.PEACH_BRIGHT,
	CharacterDef.Role.LIEUTENANT: Palette.TEXT_CREAM,
	CharacterDef.Role.HACKER: Palette.PRICE,
}
const VENUE_ICONS := {
	&"tran_bar": preload("res://assets/icons/hud/beer.svg"),
	&"la_paloma": preload("res://assets/icons/hud/wine.svg"),
	&"casino": preload("res://assets/icons/hud/dices.svg"),
	&"vip_casino": preload("res://assets/icons/hud/dices.svg"),
	&"docks": preload("res://assets/icons/hud/anchor.svg"),
	&"supply": preload("res://assets/icons/hud/wrench.svg"),
	&"safehouse": preload("res://assets/icons/hud/house.svg"),
	&"loan_shark": preload("res://assets/icons/hud/hand-coins.svg"),
}
const REST_SCALE := Vector2(1.08, 1.08)
const DRIFT_SCALE := Vector2(1.13, 1.13)
const DRIFT_SECONDS := 26.0
const TILT_PIXELS := 22.0
const TILT_SMOOTHING := 4.0
const TINT_SECONDS := 1.2
const PHASE_TINTS := {
	RunState.Phase.MORNING: Color(0.9, 0.93, 1.0),
	RunState.Phase.NOON: Color(1.0, 1.0, 1.0),
	RunState.Phase.EVENING: Color(1.0, 0.85, 0.86),
	RunState.Phase.NIGHT: Color(0.6, 0.64, 0.82),
}

@onready var _background: TextureRect = %Background
@onready var _effects: Node2D = %Effects
@onready var _margin: MarginContainer = %Margin
@onready var _title_block: Control = %TitleBlock
@onready var _name_label: Label = %NameLabel
@onready var _tagline_label: Label = %TaglineLabel
@onready var _news_line: NewsLine = %NewsLine
@onready var _around_block: Control = %AroundBlock
@onready var _people_list: HBoxContainer = %PeopleList
@onready var _venue_fabs: VBoxContainer = %VenueFabs
@onready var _map_fab: FabButton = %MapFab
@onready var _crate_button: Button = %CrateButton
@onready var _turf_bar: TurfBar = %TurfBar
@onready var _venue_sheet: VenueSheet = %VenueSheet
@onready var _day_card: DayCard = %DayCard
@onready var _logout_dialog: ConfirmDialog = %LogoutDialog

var _tilt_offset := 0.0
var _tint_tween: Tween


func _ready() -> void:
	var district: DistrictDef = GameState.current_district() if GameState.run != null else null
	if district == null:
		SceneRouter.go_to.call_deferred(SceneRouter.TITLE_SCREEN)
		return

	SafeArea.apply_top_margin(_margin, 40)
	_background.texture = district.background
	_background.self_modulate = PHASE_TINTS[GameState.run.phase]
	if district.ambient_effect != null:
		_effects.add_child(district.ambient_effect.instantiate())
	_name_label.text = district.display_name
	_tagline_label.text = district.tagline
	_news_line.show_for(district.id)
	_build_people_strip()
	_build_venue_fabs(district)
	_refresh_crate_button()
	_refresh_turf_bar()

	_crate_button.pressed.connect(_deliver_crate)
	_map_fab.pressed.connect(SceneRouter.go_to.bind(SceneRouter.MAP_SCREEN))
	_logout_dialog.confirmed.connect(_log_out)
	_turf_bar.pressed.connect(StreetTalk.talk_about_turf)
	GameState.run_changed.connect(_on_run_changed)
	GameState.day_started.connect(_on_day_started)
	resized.connect(_center_background_pivot)
	_center_background_pivot()

	GameState.clock_active = true
	_start_background_drift()
	_play_entrance()
	if GameState.has_unseen_new_day:
		_show_day_card()


func _exit_tree() -> void:
	GameState.clock_active = false


func _process(delta: float) -> void:
	var target := clampf(-Input.get_accelerometer().x / 9.8, -1.0, 1.0) * TILT_PIXELS
	_tilt_offset = lerpf(_tilt_offset, target, minf(1.0, delta * TILT_SMOOTHING))
	_background.position.x = _tilt_offset


func can_present_encounter() -> bool:
	return not _day_card.visible and not _logout_dialog.visible


func handle_back() -> bool:
	if _day_card.visible:
		return true
	if _venue_sheet.visible:
		_venue_sheet.close()
	elif _logout_dialog.visible:
		_logout_dialog.close()
	else:
		_logout_dialog.open("Log out?", "Your run is saved. Continue from the title screen.", "Yes")
	return true


func _build_people_strip() -> void:
	for child in _people_list.get_children():
		_people_list.remove_child(child)
		child.queue_free()

	var run := GameState.run
	var stamp := Calendar.stamp(run)
	for dealer in Roster.dealers_at(run, run.district_id, stamp):
		var role := "DEALER" if dealer.is_resident() else "VISITING"
		var chip := _add_person_chip(dealer.portrait, dealer.display_name, role, Palette.RISK_LOW)
		chip.pressed.connect(_trade_with.bind(dealer))
	for character in Roster.characters_at(run, run.district_id, stamp):
		var color: Color = ROLE_COLORS.get(character.role, Palette.TEXT_MUTED)
		var chip := _add_person_chip(character.portrait, character.display_name, character.role_name().to_upper(), color)
		chip.pressed.connect(StreetTalk.talk_to.bind(character))
	_around_block.visible = _people_list.get_child_count() > 0


func _add_person_chip(portrait: Texture2D, display_name: String, role: String, role_color: Color) -> PersonChip:
	var chip: PersonChip = PERSON_CHIP.instantiate()
	_people_list.add_child(chip)
	chip.display(portrait, display_name, role, role_color)
	return chip


func _trade_with(dealer: DealerDef) -> void:
	GameState.trading_with = dealer.id
	SceneRouter.go_to(SceneRouter.MARKET_SCREEN)


## The market is left out because the nav bar already opens it.
func _build_venue_fabs(district: DistrictDef) -> void:
	for venue_id in district.venues:
		if venue_id == &"market":
			continue
		var venue := Content.venue(venue_id)
		if venue == null:
			push_error("District %s lists unknown venue %s" % [district.id, venue_id])
			continue
		var fab: FabButton = FAB_BUTTON.instantiate()
		fab.icon_texture = VENUE_ICONS.get(venue_id)
		fab.caption = venue.display_name
		fab.pressed.connect(_on_venue_selected.bind(venue))
		_venue_fabs.add_child(fab)


func _on_venue_selected(venue: VenueDef) -> void:
	if not venue.available:
		_venue_sheet.show_venue(venue)
		return
	match venue.id:
		Loan.VENUE:
			StreetTalk.talk_to(Content.character(Loan.LENDER))
		Safehouse.VENUE:
			SceneRouter.go_to(SceneRouter.SAFEHOUSE_SCREEN)
		_:
			var host := Content.character(venue.host)
			if venue is CasinoDef and host != null:
				_enter_casino(venue, host)
			elif host != null and host.role == CharacterDef.Role.BARTENDER:
				GameState.visiting_venue = venue.id
				SceneRouter.go_to(SceneRouter.BAR_SCREEN)
			elif host != null and host.role == CharacterDef.Role.SMUGGLER:
				GameState.visiting_venue = venue.id
				SceneRouter.go_to(SceneRouter.DOCKS_SCREEN)
			elif host != null and host.role == CharacterDef.Role.FIXER:
				GameState.visiting_venue = venue.id
				SceneRouter.go_to(SceneRouter.FIXER_SCREEN)
			else:
				_venue_sheet.show_venue(venue)


func _refresh_turf_bar() -> void:
	var run := GameState.run
	_turf_bar.visible = Turf.is_contested(run.district_id)
	if _turf_bar.visible:
		_turf_bar.show_district(run, run.district_id)


func _refresh_crate_button() -> void:
	var run := GameState.run
	_crate_button.visible = Smuggling.can_deliver(run)
	if _crate_button.visible:
		_crate_button.text = "Deliver Voronin's crate for %s" % Format.money(int(run.crate.pay))


func _deliver_crate() -> void:
	var pay := GameState.deliver_crate()
	if pay <= 0:
		return
	AudioService.play_sfx(Sfx.CRATE_DROP)
	AudioService.play_sfx(Sfx.COINS_IN)
	var choices: Array[DialogueChoice] = [DialogueChoice.new(&"continue", "Continue", true, true)]
	var line := "Voronin's contact checks the seals, loads the crate into a van and counts out %s." % Format.money(pay)
	GameOverlay.talk(Content.player(GameState.run.player_id), line, choices, func(_choice: StringName) -> void: GameOverlay.end_talk())


func _enter_casino(casino: CasinoDef, host: CharacterDef) -> void:
	var run := GameState.run
	var choices: Array[DialogueChoice] = [DialogueChoice.new(&"leave", "Leave", true, true)]
	var close := func(_choice: StringName) -> void: GameOverlay.end_talk()
	if Families.refuses(run, host):
		var family := Families.family_of(host)
		GameOverlay.talk(host, "The %s owns these tables, and the family wants nothing from you. Walk away." % family.english_name, choices, close, family.full_name())
		return
	if Casino.can_enter(run, casino):
		GameState.visiting_venue = casino.id
		SceneRouter.go_to(SceneRouter.CASINO_SCREEN)
		return
	var line := "These tables are for players with real money. Come back with %s in your pocket." % Format.money(casino.entry_cash)
	GameOverlay.talk(host, line, choices, close, "You are carrying %s." % Format.money(run.cash))


func _on_run_changed() -> void:
	if _tint_tween:
		_tint_tween.kill()
	_tint_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_tint_tween.tween_property(_background, "self_modulate", PHASE_TINTS[GameState.run.phase], TINT_SECONDS)
	_news_line.show_for(GameState.run.district_id)
	_build_people_strip()
	_refresh_crate_button()
	_refresh_turf_bar()


func _on_day_started(_day: int) -> void:
	_show_day_card()


func _show_day_card() -> void:
	GameState.has_unseen_new_day = false
	var run := GameState.run
	var turf_cut := Turf.daily_cut(run) if run.day > 1 else 0
	_day_card.play(run.day, run.campaign_days, run.endless, turf_cut)


func _center_background_pivot() -> void:
	_background.pivot_offset = _background.size / 2.0


func _start_background_drift() -> void:
	_background.scale = REST_SCALE
	var tween := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_background, "scale", DRIFT_SCALE, DRIFT_SECONDS)
	tween.tween_property(_background, "scale", REST_SCALE, DRIFT_SECONDS)


func _log_out() -> void:
	GameState.save_run()
	SceneRouter.go_to(SceneRouter.TITLE_SCREEN)


func _play_entrance() -> void:
	var fabs: Array[Node] = _venue_fabs.get_children()
	fabs.append(_map_fab)
	_title_block.modulate.a = 0.0
	for fab: Control in fabs:
		fab.modulate.a = 0.0
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_title_block, "modulate:a", 1.0, 0.6).set_delay(0.15)
	for index in fabs.size():
		tween.tween_property(fabs[index], "modulate:a", 1.0, 0.35).set_delay(0.35 + index * 0.08)
