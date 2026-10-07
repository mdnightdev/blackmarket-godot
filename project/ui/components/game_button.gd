class_name GameButton
extends Button

const PRESSED_SCALE := Vector2(0.96, 0.96)
const HAPTIC_MS := 12

@export var click_sound: AudioStream = Sfx.CLICK

var _scale_tween: Tween


func _ready() -> void:
	button_down.connect(_animate_scale.bind(PRESSED_SCALE, 0.06))
	button_up.connect(_animate_scale.bind(Vector2.ONE, 0.16))
	pressed.connect(_on_pressed)
	resized.connect(_center_pivot)
	_center_pivot()


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
