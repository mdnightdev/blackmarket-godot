class_name AmbushAlert
extends Control
## The warning before Vex's crew hits a corner: red light at the edges, the siren and a countdown over the Old Market
## street. The player hands the defence to 午夜兔子 or mobilises the crew themselves. When time runs out, Rabbit takes it.

signal decided(choice: StringName)

const STREET: Texture2D = preload("res://assets/backgrounds/districts/old_market.jpg")
const STREET_DIM := Color(0.35, 0.33, 0.36)
const SHADE_ALPHA := 0.45
const EDGE_GLOW := 0.45
const TALK_SECONDS := 1.6
const PORTRAIT_HEIGHT := 520
const MARGIN_SIDE := 16
const MARGIN_END := 40
const CHOICE_WIDTH := 380
const CHOICE_HEIGHT := DialoguePanel.CHOICE_HEIGHT
const CHOICE_FONT_SIZE := DialoguePanel.CHOICE_FONT_SIZE
const LINE_FONT_SIZE := 21

var _seconds_left := VexAmbush.COUNTDOWN_SECONDS
var _countdown := Label.new()
var _bar := ProgressBar.new()
var _portrait := TalkingPortrait.new()
var _done := false


func show_ambush(encounter: Dictionary) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_add_street()
	var column := _add_column()
	var rabbit := Content.speaker(VexAmbush.RABBIT)
	_portrait.soft_edges = true
	_portrait.custom_minimum_size.y = PORTRAIT_HEIGHT
	_portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_portrait)
	_portrait.show_speaker(rabbit)
	column.add_child(_choices(rabbit))
	column.add_child(_card(rabbit, str(encounter.get("body", ""))))
	_show_time()
	_portrait.set_talking(true)
	get_tree().create_timer(TALK_SECONDS).timeout.connect(func() -> void: _portrait.set_talking(false))
	AudioService.start_siren()
	AudioService.play_sfx(Sfx.TURF_CLASH)
	if Settings.vibration:
		Input.vibrate_handheld(500)


func _process(delta: float) -> void:
	if _done:
		return
	_seconds_left = maxf(0.0, _seconds_left - delta)
	_show_time()
	if _seconds_left <= 0.0:
		_decide(VexAmbush.DELEGATE)


func _add_street() -> void:
	var street := TextureRect.new()
	street.texture = STREET
	street.modulate = STREET_DIM
	street.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	street.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	street.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(street)
	street.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(Palette.INK, SHADE_ALPHA)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var lights := PoliceLights.new()
	add_child(lights)
	lights.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lights.tint(Palette.RISK_HIGH)
	lights.switch_on(EDGE_GLOW)


func _add_column() -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", MARGIN_SIDE)
	margin.add_theme_constant_override("margin_right", MARGIN_SIDE)
	margin.add_theme_constant_override("margin_top", MARGIN_END)
	margin.add_theme_constant_override("margin_bottom", MARGIN_END)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_END
	column.add_theme_constant_override("separation", 12)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	return column


func _choices(rabbit: SpeakerDef) -> Control:
	var list := VBoxContainer.new()
	list.custom_minimum_size.x = CHOICE_WIDTH
	list.size_flags_horizontal = Control.SIZE_SHRINK_END
	list.add_theme_constant_override("separation", 6)
	var ready := Army.active(GameState.run) > 0
	_add_choice(list, VexAmbush.DELEGATE, "Leave it to %s" % rabbit.display_name, &"PrimaryButton", "A veteran's odds. He sends everyone.", true)
	var mobilise := "Mobilise the crew" if ready else "No men ready"
	var caption := "You pick who goes." if ready else "Everyone is wounded or gone."
	_add_choice(list, VexAmbush.MOBILISE, mobilise, &"SecondaryButton", caption, ready)
	return list


func _add_choice(list: VBoxContainer, choice: StringName, text: String, variation: StringName, caption: String, enabled: bool) -> void:
	var button := GameButton.new()
	button.text = text
	button.custom_minimum_size.y = CHOICE_HEIGHT
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", CHOICE_FONT_SIZE)
	button.theme_type_variation = variation
	button.disabled = not enabled
	button.pressed.connect(_decide.bind(choice))
	list.add_child(button)
	var note := Label.new()
	note.text = caption
	note.theme_type_variation = &"MutedLabel"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(note)


func _card(rabbit: SpeakerDef, body: String) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = &"Card"
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	card.add_child(content)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	var name_label := Label.new()
	name_label.text = rabbit.display_name
	name_label.theme_type_variation = &"HeaderLabel"
	name_row.add_child(name_label)
	var tag := Label.new()
	tag.text = "AMBUSH"
	tag.theme_type_variation = &"PillLabel"
	tag.add_theme_color_override("font_color", Palette.RISK_HIGH)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(tag)
	content.add_child(name_row)
	var line := Label.new()
	line.text = body
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_theme_font_size_override("font_size", LINE_FONT_SIZE)
	content.add_child(line)
	var timer_row := HBoxContainer.new()
	timer_row.add_theme_constant_override("separation", 12)
	_bar.theme_type_variation = &"ThinBar"
	_bar.max_value = VexAmbush.COUNTDOWN_SECONDS
	_bar.show_percentage = false
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	timer_row.add_child(_bar)
	_countdown.theme_type_variation = &"HudValueLabel"
	_countdown.add_theme_color_override("font_color", Palette.RISK_HIGH)
	timer_row.add_child(_countdown)
	content.add_child(timer_row)
	return card


func _show_time() -> void:
	_countdown.text = "0:%02d" % ceili(_seconds_left)
	_bar.value = _seconds_left


func _decide(choice: StringName) -> void:
	if _done:
		return
	_done = true
	AudioService.stop_siren()
	decided.emit(choice)
