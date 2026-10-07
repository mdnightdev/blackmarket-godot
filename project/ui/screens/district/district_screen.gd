extends Control

const VENUE_CARD := preload("res://ui/components/venue_card.tscn")
const PERSON_CHIP := preload("res://ui/components/person_chip.tscn")
const ROLE_COLORS := {
	CharacterDef.Role.LENDER: Palette.PEACH_TITLE,
	CharacterDef.Role.POLICE: Palette.RISK_HIGH,
	CharacterDef.Role.INFORMANT: Palette.PRICE,
	CharacterDef.Role.RIVAL: Palette.PEACH_BRIGHT,
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
@onready var _venue_list: VBoxContainer = %VenueList
@onready var _menu_button: Button = %MenuButton
@onready var _map_button: Button = %MapButton
@onready var _bag_button: Button = %BagButton
@onready var _venue_sheet: VenueSheet = %VenueSheet
@onready var _inventory_sheet: InventorySheet = %InventorySheet
@onready var _day_card: DayCard = %DayCard

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
	_build_venue_cards(district)

	_map_button.pressed.connect(SceneRouter.go_to.bind(SceneRouter.MAP_SCREEN))
	_menu_button.pressed.connect(_return_to_title)
	_bag_button.pressed.connect(_inventory_sheet.open_inventory)
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
	return not _day_card.visible


func handle_back() -> bool:
	if _day_card.visible:
		return true
	if _venue_sheet.visible:
		_venue_sheet.close()
		return true
	if _inventory_sheet.visible:
		_inventory_sheet.close()
		return true
	_return_to_title()
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


func _build_venue_cards(district: DistrictDef) -> void:
	for venue_id in district.venues:
		var venue := Content.venue(venue_id)
		if venue == null:
			push_error("District %s lists unknown venue %s" % [district.id, venue_id])
			continue
		var card: VenueCard = VENUE_CARD.instantiate()
		card.venue = venue
		card.venue_selected.connect(_on_venue_selected)
		_venue_list.add_child(card)


func _on_venue_selected(venue: VenueDef) -> void:
	if not venue.available:
		_venue_sheet.show_venue(venue)
		return
	match venue.id:
		&"market":
			SceneRouter.go_to(SceneRouter.MARKET_SCREEN)
		Loan.VENUE:
			StreetTalk.talk_to(Content.character(Loan.LENDER))
		_:
			_venue_sheet.show_venue(venue)


func _on_run_changed() -> void:
	if _tint_tween:
		_tint_tween.kill()
	_tint_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_tint_tween.tween_property(_background, "self_modulate", PHASE_TINTS[GameState.run.phase], TINT_SECONDS)
	_news_line.show_for(GameState.run.district_id)
	_build_people_strip()


func _on_day_started(_day: int) -> void:
	_show_day_card()


func _show_day_card() -> void:
	GameState.has_unseen_new_day = false
	_day_card.play(GameState.run.day, GameState.run.campaign_days, GameState.run.endless)


func _return_to_title() -> void:
	GameState.save_run()
	SceneRouter.go_to(SceneRouter.TITLE_SCREEN)


func _center_background_pivot() -> void:
	_background.pivot_offset = _background.size / 2.0


func _start_background_drift() -> void:
	_background.scale = REST_SCALE
	var tween := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_background, "scale", DRIFT_SCALE, DRIFT_SECONDS)
	tween.tween_property(_background, "scale", REST_SCALE, DRIFT_SECONDS)


func _play_entrance() -> void:
	var cards := _venue_list.get_children()
	_title_block.modulate.a = 0.0
	for card: Control in cards:
		card.modulate.a = 0.0
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_title_block, "modulate:a", 1.0, 0.6).set_delay(0.15)
	for index in cards.size():
		tween.tween_property(cards[index], "modulate:a", 1.0, 0.35).set_delay(0.35 + index * 0.08)
