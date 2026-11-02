class_name HudBar
extends PanelContainer

const CASH_COUNT_SECONDS := 0.45
const HEAT_MEDIUM := Heat.NOTICED
const HEAT_HIGH := Heat.WATCHED
const PHASE_LETTERS: Array[String] = ["M", "N", "E", "S"]

@onready var _cash_value: Label = %CashValue
@onready var _clean_box: Control = %Clean
@onready var _clean_value: Label = %CleanValue
@onready var _clean_divider: Control = %CleanDivider
@onready var _debt_box: Control = %Debt
@onready var _debt_divider: Control = %DebtDivider
@onready var _debt_value: Label = %DebtValue
@onready var _heat_icon: TextureRect = %HeatIcon
@onready var _heat_bar: ProgressBar = %HeatBar
@onready var _day_label: Label = %DayLabel
@onready var _district_label: Label = %DistrictLabel

var _shown_cash := 0
var _cash_tween: Tween
var _heat_fill: StyleBoxFlat
var _day_text := ""


func _ready() -> void:
	_heat_fill = _heat_bar.get_theme_stylebox("fill").duplicate()
	_heat_bar.add_theme_stylebox_override("fill", _heat_fill)
	_heat_bar.max_value = Heat.MAX
	GameState.run_changed.connect(refresh)
	_debt_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_debt_box.gui_input.connect(_on_debt_input)
	visibility_changed.connect(_on_visibility_changed)
	_sync()


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_sync()


func _sync() -> void:
	if GameState.run != null:
		_shown_cash = GameState.run.cash
	refresh()


func _process(_delta: float) -> void:
	_update_clock()


func refresh() -> void:
	var run := GameState.run
	if run == null:
		return
	_day_text = "%d %s" % [run.day, PHASE_LETTERS[run.phase]]
	if run.clean > 0:
		_clean_box.show()
		_clean_divider.show()
		_clean_value.text = Format.money_short(run.clean)
	else:
		_clean_box.hide()
		_clean_divider.hide()

	if run.debt > 0:
		_debt_box.show()
		_debt_divider.show()
		_debt_value.text = Format.money_short(run.debt)
		_debt_value.add_theme_color_override("font_color", Palette.RISK_HIGH)
	else:
		_debt_box.hide()
		_debt_divider.hide()

	var heat_color := _heat_color(run.heat, run.heat_timer > 0.0)
	_heat_bar.value = run.heat
	_heat_fill.bg_color = heat_color
	_heat_icon.modulate = heat_color
	_count_cash_to(run.cash)
	_update_clock()

	var district := GameState.current_district()
	if district != null:
		_district_label.text = district.display_name



func _update_clock() -> void:
	if GameState.run == null:
		return
	var text := "%s %s" % [_day_text, Format.clock(GameState.run.phase_seconds_left)]
	if _day_label.text != text:
		_day_label.text = text


func _on_debt_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		GameOverlay.open_loan()


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
	_cash_value.text = Format.money_short(value)


func _heat_color(heat: int, frenzy := false) -> Color:
	if frenzy or heat >= HEAT_HIGH:
		return Palette.RISK_HIGH
	if heat >= HEAT_MEDIUM:
		return Palette.FIRE
	if heat > 0:
		return Palette.FIRE
	return Palette.TEXT_MUTED
