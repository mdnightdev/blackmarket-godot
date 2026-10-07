extends CanvasLayer

signal transition_started

const TITLE_SCREEN := "res://ui/screens/title/title_screen.tscn"
const SETTINGS_SCREEN := "res://ui/screens/settings/settings_screen.tscn"
const CHARACTER_SELECT := "res://ui/screens/character_select/character_select_screen.tscn"
const DISTRICT_SCREEN := "res://ui/screens/district/district_screen.tscn"
const MAP_SCREEN := "res://ui/screens/map/map_screen.tscn"
const MARKET_SCREEN := "res://ui/screens/market/market_screen.tscn"
const BAR_SCREEN := "res://ui/screens/bar/bar_screen.tscn"
const CASINO_SCREEN := "res://ui/screens/casino/casino_screen.tscn"
const DOCKS_SCREEN := "res://ui/screens/docks/docks_screen.tscn"
const END_SCREEN := "res://ui/screens/end/end_screen.tscn"

const SHUTTER_SHADER: Shader = preload("res://ui/shaders/shutter.gdshader")
const CLOSE_SECONDS := 0.24
const OPEN_SECONDS := 0.3
const RAIL_HEIGHT := 18.0
const SHUTTER_DB := -10.0

## Blocks taps for the whole transition, including while the shutter is still off screen.
var _input_blocker: Control
var _shutter: ColorRect
var _is_transitioning := false
## A run can end mid-transition (for example while travelling), so that one route waits its turn.
var _queued_scene := ""


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	_input_blocker = Control.new()
	_input_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_input_blocker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_input_blocker)

	_shutter = ColorRect.new()
	var shutter_material := ShaderMaterial.new()
	shutter_material.shader = SHUTTER_SHADER
	_shutter.material = shutter_material
	_shutter.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shutter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shutter.visible = false
	add_child(_shutter)

	var rail := ColorRect.new()
	rail.color = Palette.INK
	rail.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	rail.offset_top = -RAIL_HEIGHT
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shutter.add_child(rail)

	GameState.run_ended.connect(func(_outcome: RunState.Outcome) -> void: go_to(END_SCREEN, true))


func is_transitioning() -> bool:
	return _is_transitioning


func go_to(scene_path: String, queue_if_busy := false) -> void:
	if _is_transitioning:
		if queue_if_busy:
			_queued_scene = scene_path
		return
	_is_transitioning = true
	_input_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	transition_started.emit()

	var open_y := -_shutter.size.y
	_shutter.position.y = open_y
	_shutter.visible = true
	await _slide_shutter(0.0, CLOSE_SECONDS, Tween.EASE_IN).finished
	AudioService.play_sfx(Sfx.SHUTTER, 0.08, SHUTTER_DB)

	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("Scene change to %s failed: %s" % [scene_path, error_string(error)])
	await get_tree().process_frame
	await _slide_shutter(open_y, OPEN_SECONDS, Tween.EASE_IN_OUT).finished

	_shutter.visible = false
	_input_blocker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_transitioning = false
	if not _queued_scene.is_empty():
		var next_scene := _queued_scene
		_queued_scene = ""
		go_to(next_scene)


func _slide_shutter(target_y: float, duration: float, ease_type: Tween.EaseType) -> Tween:
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(ease_type)
	tween.tween_property(_shutter, "position:y", target_y, duration)
	return tween


## Android back button: the current screen gets first refusal through handle_back(),
## otherwise the app closes.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST or _is_transitioning:
		return
	if GameOverlay.handle_back():
		return
	var screen := get_tree().current_scene
	if screen != null and screen.has_method("handle_back") and screen.handle_back():
		return
	get_tree().quit()
