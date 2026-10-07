class_name DayCard
extends Control

const FADE_IN_SECONDS := 0.35
const HOLD_SECONDS := 1.1
const FADE_OUT_SECONDS := 0.45

@onready var _number_label: Label = %NumberLabel
@onready var _remaining_label: Label = %RemainingLabel

var _tween: Tween


func _ready() -> void:
	hide()
	gui_input.connect(_on_gui_input)


func play(day: int, campaign_days: int, endless := false) -> void:
	_number_label.text = str(day)
	_remaining_label.text = "Endless" if endless else _remaining_text(campaign_days - day)
	modulate.a = 0.0
	show()
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_tween.tween_property(self, "modulate:a", 1.0, FADE_IN_SECONDS)
	_tween.tween_interval(HOLD_SECONDS)
	_tween.tween_callback(_fade_out)


func _fade_out() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_SECONDS)
	_tween.tween_callback(hide)


func _remaining_text(days_left: int) -> String:
	if days_left <= 0:
		return "Final day"
	if days_left == 1:
		return "1 day left"
	return "%d days left" % days_left


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_fade_out()
