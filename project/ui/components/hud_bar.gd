class_name HudBar
extends PanelContainer

const CASH_COUNT_SECONDS := 0.45
const HEAT_MEDIUM := Heat.NOTICED
const HEAT_HIGH := Heat.WATCHED
const PHASE_LETTERS: Array[String] = ["M", "N", "E", "S"]

@onready var _city_label: Label = %CityLabel
@onready var _cash_value: Label = %CashValue
@onready var _clean_box: Control = %Clean
@onready var _clean_value: Label = %CleanValue
@onready var _clean_divider: Control = %CleanDivider
@onready var _debt_box: Control = %Debt
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
	_apply_safe_area()
	_sync()


func _apply_safe_area() -> void:
	var inset := int(SafeArea.top_inset(get_viewport()))
	if inset > 0:
		var style := get_theme_stylebox("panel")
		if style is StyleBoxFlat:
			var copy: StyleBoxFlat = style.duplicate()
			copy.content_margin_top = maxi(6.0, inset + 4.0)
			add_theme_stylebox_override("panel", copy)
			custom_minimum_size.y = 56 + inset


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_sync()


func _sync() -> void:
	if GameState.run != null:
		_shown_cash = GameState.run.cash
	refresh()


func _process(delta: float) -> void:
	if GameState.run != null:
		Heat.tick_frenzy(GameState.run, delta)
	_update_clock()


func refresh() -> void:
	var run := GameState.run
	if run == null:
		return
	var district := Content.district(run.district_id)
	if district != null and _city_label != null:
		_city_label.text = district.display_name.to_upper()
	_day_text = "%d %s" % [run.day, PHASE_LETTERS[run.phase]]
	if run.clean > 0 or run.career:
		_clean_box.show()
		_clean_divider.show()
		_clean_value.text = Format.money_short(run.clean)
	else:
		_clean_box.hide()
		_clean_divider.hide()
	if run.debt > 0:
		_debt_value.text = "-%s" % Format.money_short(run.debt)
		_debt_value.add_theme_color_override("font_color", Palette.RISK_HIGH)
	else:
		_debt_value.text = StreetCred.rank_name(StreetCred.rank(run))
		_debt_value.add_theme_color_override("font_color", Palette.TEXT_CREAM)
	var heat_color := _heat_color(run.heat, run.heat_timer > 0.0)
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
		if GameState.run != null and GameState.run.debt > 0:
			GameOverlay.open_loan()
		else:
			GameOverlay.open_profile()


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
		return Palette.PEACH_BRIGHT
	return Palette.RISK_LOW
