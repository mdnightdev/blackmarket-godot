class_name ConfirmDialog
extends Control

signal confirmed
signal cancelled

const OPEN_SECONDS := 0.18
const CLOSE_SECONDS := 0.12

@onready var _dim: ColorRect = %Dim
@onready var _card: PanelContainer = %Card
@onready var _title_label: Label = %TitleLabel
@onready var _message_label: Label = %MessageLabel
@onready var _cancel_button: Button = %CancelButton
@onready var _confirm_button: Button = %ConfirmButton

var _tween: Tween


func _ready() -> void:
	hide()
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_card.resized.connect(func() -> void: _card.pivot_offset = _card.size / 2.0)


func open(title: String, message: String, confirm_text: String = "Confirm", destructive: bool = false) -> void:
	_title_label.text = title
	_message_label.text = message
	_confirm_button.text = confirm_text
	_confirm_button.theme_type_variation = &"DangerButton" if destructive else &"PrimaryButton"

	_dim.modulate.a = 0.0
	_card.modulate.a = 0.0
	_card.scale = Vector2(0.94, 0.94)
	show()
	_animate(1.0, Vector2.ONE, OPEN_SECONDS)


func close() -> void:
	if not visible:
		return
	_animate(0.0, Vector2(0.96, 0.96), CLOSE_SECONDS).chain().tween_callback(hide)


func _animate(alpha: float, card_scale: Vector2, duration: float) -> Tween:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_dim, "modulate:a", alpha, duration)
	_tween.tween_property(_card, "modulate:a", alpha, duration)
	_tween.tween_property(_card, "scale", card_scale, duration)
	return _tween


func _on_cancel_pressed() -> void:
	close()
	cancelled.emit()


func _on_confirm_pressed() -> void:
	close()
	confirmed.emit()
