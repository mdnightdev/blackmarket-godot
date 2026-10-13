class_name GameButton
extends Button

const PRESSED_SCALE := Vector2(0.96, 0.96)
const HAPTIC_MS := 12
## Inside a scroll list, a press that moves this far is a drag: the list scrolls and the button does not fire.
const DRAG_CANCEL_DISTANCE := 14.0

@export var click_sound: AudioStream = Sfx.CLICK

var _scale_tween: Tween
var _press_position := Vector2.ZERO
var _press_cancelled := false


func _ready() -> void:
	button_down.connect(_animate_scale.bind(PRESSED_SCALE, 0.06))
	button_up.connect(_animate_scale.bind(Vector2.ONE, 0.16))
	pressed.connect(_on_pressed)
	resized.connect(_center_pivot)
	_center_pivot()
	if _in_scroll_list():
		mouse_filter = MOUSE_FILTER_PASS


func _gui_input(event: InputEvent) -> void:
	if mouse_filter != MOUSE_FILTER_PASS:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_press_position = event.global_position
		_press_cancelled = false
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT and not _press_cancelled:
		if event.global_position.distance_to(_press_position) > DRAG_CANCEL_DISTANCE:
			_cancel_press()


## Disabling a button drops its press, so the release that ends the drag does nothing.
func _cancel_press() -> void:
	_press_cancelled = true
	if disabled:
		return
	disabled = true
	disabled = false
	_animate_scale(Vector2.ONE, 0.16)


func _in_scroll_list() -> bool:
	var node := get_parent()
	while node != null:
		if node is ScrollContainer:
			return true
		node = node.get_parent()
	return false


func _center_pivot() -> void:
	pivot_offset = size / 2.0


func _animate_scale(target: Vector2, duration: float) -> void:
	if _scale_tween:
		_scale_tween.kill()
	_scale_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(self, "scale", target, duration)


func _on_pressed() -> void:
	if Settings.vibration:
		Input.vibrate_handheld(HAPTIC_MS)
	AudioService.play_sfx(click_sound, 0.05)
