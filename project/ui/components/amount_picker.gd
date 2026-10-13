class_name AmountPicker
extends Control

## A card that asks how many: men to train, weapons to buy or sell. Subclasses set the limit, describe the pick and
## carry it out.

const OPEN_SECONDS := 0.18
const CLOSE_SECONDS := 0.12
const STEP := 100

@onready var _dim: ColorRect = %Dim
@onready var _card: PanelContainer = %Card
@onready var _title_label: Label = %TitleLabel
@onready var _message_label: Label = %MessageLabel
@onready var _amount_label: Label = %AmountLabel
@onready var _slider: HSlider = %AmountSlider
@onready var _minus_button: Button = %MinusButton
@onready var _plus_button: Button = %PlusButton
@onready var _max_button: Button = %MaxButton
@onready var _option_check: CheckButton = %OptionCheck
@onready var _summary_label: Label = %SummaryLabel
@onready var _cancel_button: Button = %CancelButton
@onready var _confirm_button: Button = %ConfirmButton

var _on_closed := Callable()
var _tween: Tween


func _ready() -> void:
	hide()
	_cancel_button.pressed.connect(cancel)
	_confirm_button.pressed.connect(_confirm)
	_slider.value_changed.connect(func(_value: float) -> void: _refresh())
	_minus_button.pressed.connect(func() -> void: _slider.value -= STEP)
	_plus_button.pressed.connect(func() -> void: _slider.value += STEP)
	_max_button.pressed.connect(func() -> void: _slider.value = _slider.max_value)
	_option_check.toggled.connect(func(_on: bool) -> void: _set_limit(int(_slider.value)))
	_card.resized.connect(func() -> void: _card.pivot_offset = _card.size / 2.0)


func cancel() -> void:
	if visible:
		_close(false)


## The most the player can pick right now.
func _most() -> int:
	return 0


## Fills the summary and the confirm button for the amount picked.
func _describe(_amount: int) -> void:
	pass


## Carries out the pick. Returns false when it could not happen.
func _submit(_amount: int) -> bool:
	return false


## on_closed gets true when the pick went through.
func _present(title: String, message: String, first_pick: int, on_closed := Callable()) -> void:
	_title_label.text = title
	_message_label.text = message
	_on_closed = on_closed
	_set_limit(first_pick)
	_dim.modulate.a = 0.0
	_card.modulate.a = 0.0
	_card.scale = Vector2(0.94, 0.94)
	show()
	_animate(1.0, Vector2.ONE, OPEN_SECONDS)


func _set_limit(wanted: int) -> void:
	var most := _most()
	_slider.max_value = most
	_slider.editable = most > 0
	_slider.set_value_no_signal(mini(wanted, most))
	_refresh()


func _refresh() -> void:
	var amount := int(_slider.value)
	_amount_label.text = Format.count(amount)
	_minus_button.disabled = amount <= 0
	_plus_button.disabled = amount >= int(_slider.max_value)
	_max_button.disabled = amount >= int(_slider.max_value)
	_confirm_button.disabled = amount <= 0
	_describe(amount)


func _confirm() -> void:
	if not _submit(int(_slider.value)):
		_set_limit(int(_slider.value))
		return
	_close(true)


func _close(done: bool) -> void:
	var on_closed := _on_closed
	_on_closed = Callable()
	_animate(0.0, Vector2(0.96, 0.96), CLOSE_SECONDS).chain().tween_callback(hide)
	if on_closed.is_valid():
		on_closed.call(done)


func _animate(alpha: float, card_scale: Vector2, duration: float) -> Tween:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_dim, "modulate:a", alpha, duration)
	_tween.tween_property(_card, "modulate:a", alpha, duration)
	_tween.tween_property(_card, "scale", card_scale, duration)
	return _tween
