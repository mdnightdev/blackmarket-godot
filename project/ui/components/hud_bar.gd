class_name HudBar
extends PanelContainer

const CASH_COUNT_SECONDS := 0.45
const HEAT_MEDIUM := 30
const HEAT_HIGH := 70

@onready var _day_label: Label = %DayLabel
@onready var _phase_label: Label = %PhaseLabel
@onready var _clock_label: Label = %ClockLabel
@onready var _next_phase_button: Button = %NextPhaseButton
@onready var _cash_value: Label = %CashValue
@onready var _debt_box: Control = %Debt
@onready var _debt_value: Label = %DebtValue
@onready var _heat_value: Label = %HeatValue
@onready var _bag_value: Label = %BagValue

var _shown_cash := 0
var _cash_tween: Tween


func _ready() -> void:
	GameState.run_changed.connect(refresh)
	Settings.changed.connect(_update_clock_visibility)
	_next_phase_button.pressed.connect(GameState.advance_phase)
	_debt_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_debt_box.gui_input.connect(_on_debt_input)
	if GameState.run != null:
		_shown_cash = GameState.run.cash
	refresh()
	_update_clock_visibility()


func _process(_delta: float) -> void:
	if not _clock_label.visible or GameState.run == null:
		return
	var seconds := ceili(GameState.run.phase_seconds_left)
	_clock_label.text = "%d:%02d" % [floori(seconds / 60.0), seconds % 60]


func refresh() -> void:
	var run := GameState.run
	if run == null:
		return
	_day_label.text = "DAY %d" % run.day if run.endless else "DAY %d / %d" % [run.day, run.campaign_days]
	_phase_label.text = RunState.phase_name(run.phase).to_upper()
	_debt_value.text = Format.money(run.debt)
	_heat_value.text = "%d%%" % run.heat
	_heat_value.add_theme_color_override("font_color", _heat_color(run.heat))
	var used := Inventory.used(run)
	var capacity := Inventory.capacity(run)
	_bag_value.text = "%d/%d" % [used, capacity]
	_bag_value.add_theme_color_override("font_color", Palette.PEACH_BRIGHT if used >= capacity else Palette.TEXT_CREAM)
	_count_cash_to(run.cash)


func _on_debt_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		GameOverlay.open_loan()


func _update_clock_visibility() -> void:
	_clock_label.visible = Settings.real_time_phases


func _count_cash_to(target: int) -> void:
	if _cash_tween:
		_cash_tween.kill()
	if target == _shown_cash:
		_show_cash(target)
		return
	_cash_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_cash_tween.tween_method(_show_cash, _shown_cash, target, CASH_COUNT_SECONDS)


func _show_cash(value: int) -> void:
	_shown_cash = value
	_cash_value.text = Format.money(value)


func _heat_color(heat: int) -> Color:
	if heat >= HEAT_HIGH:
		return Palette.RISK_HIGH
	if heat >= HEAT_MEDIUM:
		return Palette.PEACH_BRIGHT
	return Palette.RISK_LOW
