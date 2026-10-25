class_name TargetCard
extends Control

## A rival corner sized up before a hit: the player's force against the latest scouting report, the reading that
## comes from it, and the moves. Scouting refreshes the card in place. Attacking hands over to the crew picker.

const OPEN_SECONDS := 0.18
const CLOSE_SECONDS := 0.12
const READING_COLORS := {
	"easy": Palette.RISK_LOW,
	"good odds": Palette.RISK_LOW,
	"even": Palette.PEACH_BRIGHT,
	"risky": Palette.RISK_HIGH,
	"suicide": Palette.RISK_HIGH,
}

@onready var _dim: ColorRect = %Dim
@onready var _card: PanelContainer = %Card
@onready var _title_label: Label = %TitleLabel
@onready var _holder_label: Label = %HolderLabel
@onready var _stronghold_tag: Label = %StrongholdTag
@onready var _mine_caption: Label = %MineCaption
@onready var _their_caption: Label = %TheirCaption
@onready var _men_label: Label = %MenLabel
@onready var _kit_label: Label = %KitLabel
@onready var _enemy_label: Label = %EnemyLabel
@onready var _gear_label: Label = %GearLabel
@onready var _strength_bar: StrengthBar = %StrengthBar
@onready var _reading_label: Label = %ReadingLabel
@onready var _report_label: Label = %ReportLabel
@onready var _people: HFlowContainer = %People
@onready var _leave_button: Button = %LeaveButton
@onready var _scout_button: Button = %ScoutButton
@onready var _attack_button: Button = %AttackButton

var _corner: CornerDef
var _tween: Tween


func _ready() -> void:
	hide()
	_stronghold_tag.add_theme_color_override("font_color", Palette.PEACH_TITLE)
	_mine_caption.add_theme_color_override("font_color", TurfBar.PLAYER_COLOR)
	_leave_button.pressed.connect(cancel)
	_scout_button.pressed.connect(_scout)
	_attack_button.pressed.connect(_attack)
	_card.resized.connect(func() -> void: _card.pivot_offset = _card.size / 2.0)


## people is everyone working the corner this phase, from Corners.people_at.
func open(corner: CornerDef, people: Array[SpeakerDef]) -> void:
	_corner = corner
	_show_people(people)
	_refresh()
	_dim.modulate.a = 0.0
	_card.modulate.a = 0.0
	_card.scale = Vector2(0.94, 0.94)
	show()
	_animate(1.0, Vector2.ONE, OPEN_SECONDS)


func cancel() -> void:
	if visible:
		_close()


func _refresh() -> void:
	var run := GameState.run
	if Corners.holds(run, _corner.id):
		_refresh_garrison(run)
		return
	var gang := Corners.gang_of(_corner.id)
	var their_color := gang.color if gang != null else Palette.RISK_HIGH
	_title_label.text = _corner.display_name
	_holder_label.text = "%s, pays %s a day" % [gang.crew_name if gang != null else "A rival crew", Format.money(_corner.daily_cut())]
	_holder_label.add_theme_color_override("font_color", their_color)
	_mine_caption.text = "YOUR FORCE"
	_their_caption.text = "DEFENCE"
	_their_caption.add_theme_color_override("font_color", their_color)
	_stronghold_tag.visible = _corner.stronghold

	var deployment := Army.deployment(run)
	var sent := Army.deployed_count(deployment)
	_men_label.text = "%s men" % Format.count(sent)
	_kit_label.text = WarTalk.weapons_text(run, deployment) if sent > 0 else "Nobody ready to fight"

	var report := Scouting.report(run, _corner)
	var known := not report.is_empty()
	if known:
		_enemy_label.text = "%s to %s" % [Format.count(int(report.low)), Format.count(int(report.high))]
		_gear_label.text = "with %s" % str(Armory.GRADE_NAMES[int(report.gear)]).to_lower()
	else:
		_enemy_label.text = "?"
		_gear_label.text = "Not scouted"
	var bounds := Scouting.power_range(_corner, report) if known else Vector2.ZERO
	_strength_bar.show_strength(Army.power(run, deployment), bounds, known, their_color)

	var district_id := Corners.district_of(_corner.id)
	var can_invade := War.can_invade_district(run, district_id)
	var lock_reason := War.invasion_lock_reason(run, district_id)

	var reading := Scouting.reading(run, _corner, deployment)
	if not can_invade:
		_reading_label.text = "TERRITORY LOCKED"
		_reading_label.add_theme_color_override("font_color", Palette.TEXT_MUTED)
		_report_label.text = lock_reason
	else:
		_reading_label.text = reading.to_upper()
		_reading_label.add_theme_color_override("font_color", READING_COLORS.get(reading, Palette.TEXT_MUTED))
		_report_label.text = _report_note(run, report)

	var price := Scouting.cost(_corner)
	_scout_button.text = "Scout %s" % Format.money(price)
	_scout_button.disabled = run.cash < price or not War.is_target(run, _corner)
	_attack_button.text = "Attack"
	_attack_button.disabled = not War.can_attack(run, _corner)


func _refresh_garrison(run: RunState) -> void:
	var gang := Corners.gang_of(_corner.id)
	var their_color := gang.color if gang != null else Palette.RISK_HIGH
	_title_label.text = _corner.display_name
	_holder_label.text = "Held by your crew, pays %s a day" % Format.money(_corner.daily_cut())
	_holder_label.add_theme_color_override("font_color", TurfBar.PLAYER_COLOR)
	_mine_caption.text = "GARRISON"
	_their_caption.text = "RIVAL THREAT"
	_their_caption.add_theme_color_override("font_color", their_color)
	_stronghold_tag.visible = _corner.stronghold

	var posted := Corners.garrison(run, _corner.id)
	_men_label.text = "%s posted" % Format.count(posted) if posted > 0 else "No garrison posted"
	var mult_text := "2.5x stronghold cover" if _corner.stronghold else "1.5x street cover"
	_kit_label.text = "%s (%s in reserve)" % [mult_text, Format.count(Army.reserve(run))]

	var from := RivalStrike.source(run, gang, _corner) if gang != null else null
	var raiders := RivalStrike.raiders(run, from) if from != null else 0
	var threat_power := raiders * Rivals.power_per_man(run, gang) if gang != null else 0.0
	if raiders > 0 and gang != null:
		_enemy_label.text = "~%s raiders" % Format.count(raiders)
		_gear_label.text = "with %s" % str(Armory.GRADE_NAMES[Rivals.gear(run, gang)]).to_lower()
	else:
		_enemy_label.text = "Quiet"
		_gear_label.text = "No nearby crew"
	var def_power := Corners.garrison_power(run, _corner)
	var bounds := Vector2(threat_power * 0.85, threat_power * 1.25)
	_strength_bar.show_strength(def_power, bounds, raiders > 0, their_color)

	var locked_down := def_power >= threat_power * 1.25 and def_power > 0.0 or (raiders <= 0 and posted > 0)
	_reading_label.text = "LOCKED DOWN" if locked_down else ("GARRISONED" if posted > 0 else "UNPROTECTED")
	_reading_label.add_theme_color_override("font_color", Palette.RISK_LOW if locked_down else (Palette.PEACH_BRIGHT if posted > 0 else Palette.RISK_HIGH))
	_report_label.text = "Posted men hold this corner with %s and cannot join attacks." % mult_text

	_scout_button.text = "Recall Crew"
	_scout_button.disabled = posted <= 0
	_attack_button.text = "Post Crew"
	_attack_button.disabled = Army.reserve(run) <= 0


func _report_note(run: RunState, report: Dictionary) -> String:
	if report.is_empty():
		var old: Dictionary = run.scouted.get(String(_corner.id), {})
		if not old.is_empty():
			return "The report from day %d is stale. Scout again before you trust it." % int(old.day)
		return "Send a scout for a count. It takes the rest of the phase."
	var age := run.day - int(report.day)
	var note := "Scouted today." if age == 0 else "Scouted %d day%s ago." % [age, "" if age == 1 else "s"]
	if bool(report.seen):
		note += " They spotted the scout and brought more men."
	if RivalMoves.is_baited(run, _corner.id):
		note += " Watch out: extra gunmen are hiding in the back alleys."
	return note


func _show_people(people: Array[SpeakerDef]) -> void:
	Utils.clear_container(_people)
	for person in people:
		var button := GameButton.new()
		button.theme_type_variation = &"SmallButton"
		button.text = "Talk to %s" % person.display_name
		button.custom_minimum_size.y = 44
		button.pressed.connect(_talk_to.bind(person))
		_people.add_child(button)
	_people.visible = not people.is_empty()


func _scout() -> void:
	var run := GameState.run
	if Corners.holds(run, _corner.id):
		Corners.post_garrison(run, _corner.id, 0)
		GameState.save_run()
		GameState.run_changed.emit()
		AudioService.play_sfx(Sfx.CLICK)
		_refresh()
		return
	if GameState.scout_corner(_corner.id) != Scouting.Result.OK:
		_refresh()
		return
	AudioService.play_sfx(Sfx.SHUTTER)
	if War.is_target(GameState.run, _corner):
		_refresh()
	else:
		_close()


func _attack() -> void:
	var corner := _corner
	var run := GameState.run
	if Corners.holds(run, corner.id):
		_close()
		var msg := "Pick how many reserve men to station on %s. Posted men get %s." % [corner.display_name, "2.5x stronghold defense" if corner.stronghold else "1.5x cover defense"]
		GameOverlay.pick_crew(corner.display_name, msg, "Post %d", "Cancel", func(picked_deploy: Dictionary) -> void:
			var add_count := Army.deployed_count(picked_deploy)
			Corners.post_garrison(run, corner.id, Corners.garrison(run, corner.id) + add_count)
			GameState.save_run()
			GameState.run_changed.emit(), Callable())
		return
	_close()
	WarTalk.plan(corner)


func _talk_to(person: SpeakerDef) -> void:
	_close()
	if person is DealerDef:
		DealerTalk.talk_to(person)
	elif person is CharacterDef:
		StreetTalk.talk_to(person)


func _close() -> void:
	_animate(0.0, Vector2(0.96, 0.96), CLOSE_SECONDS).chain().tween_callback(hide)


func _animate(alpha: float, card_scale: Vector2, duration: float) -> Tween:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_dim, "modulate:a", alpha, duration)
	_tween.tween_property(_card, "modulate:a", alpha, duration)
	_tween.tween_property(_card, "scale", card_scale, duration)
	return _tween
