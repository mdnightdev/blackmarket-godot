class_name HudBar
extends PanelContainer

const CASH_COUNT_SECONDS := 0.45
const HEAT_MEDIUM := 30
const HEAT_HIGH := 70
const PHASE_LETTERS: Array[String] = ["M", "N", "E", "S"]

@onready var _cash_value: Label = %CashValue
@onready var _debt_box: Control = %Debt
@onready var _debt_caption: Label = %DebtCaption
@onready var _debt_value: Label = %DebtValue
@onready var _heat_icon: TextureRect = %HeatIcon
@onready var _heat_bar: ProgressBar = %HeatBar
@onready var _day_label: Label = %DayLabel

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
	if run.debt > 0:
		_debt_caption.text = "Debt"
		_debt_value.text = Format.money_short(run.debt)
	else:
		_debt_caption.text = "Cred"
		_debt_value.text = StreetCred.rank_name(StreetCred.rank(run))
	var heat_color := _heat_color(run.heat)
	_heat_bar.value = run.heat
	_heat_fill.bg_color = heat_color
	_heat_icon.modulate = heat_color
	_count_cash_to(run.cash)
	_update_clock()


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


func _heat_color(heat: int) -> Color:
	if heat >= HEAT_HIGH:
		return Palette.RISK_HIGH
	if heat >= HEAT_MEDIUM:
		return Palette.PEACH_BRIGHT
	return Palette.RISK_LOW
