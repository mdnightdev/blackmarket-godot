class_name DayCard
extends Control

const FADE_IN_SECONDS := 0.35
const HOLD_SECONDS := 1.1
const FADE_OUT_SECONDS := 0.45

@onready var _number_label: Label = %NumberLabel
@onready var _remaining_label: Label = %RemainingLabel
@onready var _income_label: Label = %IncomeLabel

var _tween: Tween


func _ready() -> void:
	hide()
	gui_input.connect(_on_gui_input)


## turf_cut is the money the player's corners paid this morning. 0 hides the line.
func play(run: RunState, turf_cut := 0) -> void:
	_number_label.text = str(run.day)
	_remaining_label.text = StreetCred.rank_name(StreetCred.rank(run)) if run.career else _payment_text(run)
	_income_label.text = "Rent and protection: %s" % Format.money(turf_cut)
	_income_label.visible = turf_cut > 0
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


func _payment_text(run: RunState) -> String:
	var lender := Loan.lender_label(run)
	if Loan.amount_due(run) <= 0:
		return "%s paid this week" % lender
	var days_left := run.next_due_day - 1 - run.day
	if days_left <= 0:
		return "%s payment due today" % lender
	if days_left == 1:
		return "%s payment due tomorrow" % lender
	return "%s payment in %d days" % [lender, days_left]


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_fade_out()
