class_name RaidScene
extends Control
## A raid that has already been decided, played out with no control: the door goes in, flashlights sweep the room,
## the officer in charge steps in and the result lands. Tap to skip once the door is in.

signal finished

const BACKDROP: Texture2D = preload("res://assets/scenes/raid.jpg")
const LIGHTS_INTENSITY := 0.9
const ZOOM := 1.12
const DOOR_AT := 0.5
const OFFICER_AT := 1.4
const RESULT_AT := 3.4
const END_AT := 5.4
const SKIPPABLE_AFTER := 1.0
const FLASH_SECONDS := 0.35
const BEAM_SIZE := Vector2(520, 520)
const BEAM_SWEEP_SECONDS := 1.3
const PORTRAIT_SIZE := Vector2(300, 400)
const MARGIN := 40.0

var _backdrop := TextureRect.new()
var _lights := PoliceLights.new()
var _flash := ColorRect.new()
var _beams: Array[TextureRect] = []
var _portrait := TextureRect.new()
var _title := Label.new()
var _officer_name := Label.new()
var _result := Label.new()
var _elapsed := 0.0
var _done := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.texture = BACKDROP
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)
	var shade := ColorRect.new()
	shade.color = Color(Palette.INK, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	for index in 2:
		var beam := _make_beam()
		_beams.append(beam)
		add_child(beam)
	add_child(_lights)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.size = PORTRAIT_SIZE
	_portrait.modulate.a = 0.0
	add_child(_portrait)
	_title.theme_type_variation = &"TitleLabel"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.modulate.a = 0.0
	add_child(_title)
	_officer_name.theme_type_variation = &"MutedLabel"
	_officer_name.modulate.a = 0.0
	add_child(_officer_name)
	_result.theme_type_variation = &"TitleLabel"
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result.modulate.a = 0.0
	add_child(_result)
	_flash.color = Palette.TEXT_CREAM
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.modulate.a = 0.0
	add_child(_flash)


func play(officer: SpeakerDef, result_line: String) -> void:
	var area := get_viewport_rect().size
	_backdrop.pivot_offset = area / 2.0
	_title.text = "RAID"
	_title.size = Vector2(area.x, 0)
	_title.position = Vector2(0, area.y * 0.12)
	_portrait.texture = officer.talk_portrait if officer.talk_portrait != null else officer.portrait
	_portrait.position = Vector2(area.x, area.y - PORTRAIT_SIZE.y - MARGIN * 4.0)
	_officer_name.text = officer.display_name.to_upper()
	_officer_name.position = Vector2(area.x - PORTRAIT_SIZE.x - MARGIN, area.y - MARGIN * 3.5)
	_result.text = result_line
	_result.size = Vector2(area.x - MARGIN * 2.0, 0)
	_result.position = Vector2(MARGIN, area.y * 0.42)
	_lights.switch_on(LIGHTS_INTENSITY)
	AudioService.start_siren()

	var tween := create_tween().set_parallel()
	tween.tween_property(_backdrop, "scale", Vector2.ONE * ZOOM, END_AT)
	tween.tween_callback(_kick_door).set_delay(DOOR_AT)
	tween.tween_property(_title, "modulate:a", 1.0, 0.2).set_delay(DOOR_AT)
	for index in _beams.size():
		_sweep(_beams[index], area, index)
	var portrait_x := area.x - PORTRAIT_SIZE.x - MARGIN
	tween.tween_property(_portrait, "position:x", portrait_x, 0.5).set_delay(OFFICER_AT).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_portrait, "modulate:a", 1.0, 0.4).set_delay(OFFICER_AT)
	tween.tween_property(_officer_name, "modulate:a", 1.0, 0.4).set_delay(OFFICER_AT + 0.3)
	tween.tween_property(_title, "modulate:a", 0.0, 0.3).set_delay(RESULT_AT - 0.3)
	tween.tween_property(_result, "modulate:a", 1.0, 0.4).set_delay(RESULT_AT)
	tween.tween_callback(_finish).set_delay(END_AT)


func _process(delta: float) -> void:
	_elapsed += delta


func _gui_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventScreenTouch or event is InputEventMouseButton) and event.is_pressed()
	if pressed and _elapsed >= SKIPPABLE_AFTER:
		accept_event()
		_finish()


func _kick_door() -> void:
	AudioService.play_sfx(Sfx.RAID_HIT)
	if Settings.vibration:
		Input.vibrate_handheld(300)
	_flash.modulate.a = 0.8
	create_tween().tween_property(_flash, "modulate:a", 0.0, FLASH_SECONDS)


func _sweep(beam: TextureRect, area: Vector2, index: int) -> void:
	var low := Vector2(-BEAM_SIZE.x * 0.3, area.y * (0.25 + 0.2 * index))
	var high := Vector2(area.x - BEAM_SIZE.x * 0.7, area.y * (0.45 - 0.15 * index))
	var from := low if index == 0 else high
	var to := high if index == 0 else low
	beam.position = from
	var tween := create_tween().set_loops()
	tween.tween_property(beam, "position", to, BEAM_SWEEP_SECONDS).set_trans(Tween.TRANS_SINE)
	tween.tween_property(beam, "position", from, BEAM_SWEEP_SECONDS).set_trans(Tween.TRANS_SINE)
	beam.modulate.a = 0.0
	create_tween().tween_property(beam, "modulate:a", 1.0, 0.4).set_delay(DOOR_AT + 0.2)


func _make_beam() -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.95, 0.8, 0.35))
	gradient.set_color(1, Color(1.0, 0.95, 0.8, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 256
	texture.height = 256
	var beam := TextureRect.new()
	beam.texture = texture
	beam.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	beam.size = BEAM_SIZE
	beam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	beam.material = additive
	return beam


func _finish() -> void:
	if _done:
		return
	_done = true
	_lights.switch_off()
	AudioService.stop_siren()
	finished.emit()
