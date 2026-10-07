class_name SlotReel
extends Control

signal stopped

const TICK_SECONDS := 0.06
const ICON_INSET := 18.0
const STOP_BOUNCE_SECONDS := 0.18

## Textures for each reel symbol, in Casino.SLOT_SYMBOLS order.
var symbols: Array[Texture2D] = []
var symbol := 0:
	set(new_value):
		symbol = new_value
		queue_redraw()

var _frame_style := StyleBoxFlat.new()
var _spin_left := 0.0
var _tick_left := 0.0
var _offset := 0.0
var _final_symbol := 0


func _init() -> void:
	custom_minimum_size = Vector2(176, 176)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_frame_style.bg_color = Palette.INK
	_frame_style.border_color = Palette.LINE_MUTED
	_frame_style.set_border_width_all(2)
	_frame_style.set_corner_radius_all(12)


func is_spinning() -> bool:
	return _spin_left > 0.0


func spin(final_symbol: int, seconds: float) -> void:
	_final_symbol = final_symbol
	_spin_left = seconds
	_tick_left = 0.0


func _process(delta: float) -> void:
	if not is_spinning():
		return
	_spin_left -= delta
	_tick_left -= delta
	_offset = fmod(_offset + delta * 1400.0, size.y)
	if _tick_left <= 0.0:
		_tick_left = TICK_SECONDS
		symbol = randi() % maxi(1, symbols.size())
	if _spin_left <= 0.0:
		_land()
	queue_redraw()


func _land() -> void:
	_spin_left = 0.0
	_offset = 0.0
	symbol = _final_symbol
	pivot_offset = size / 2.0
	scale = Vector2(1.06, 1.06)
	create_tween().tween_property(self, "scale", Vector2.ONE, STOP_BOUNCE_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	stopped.emit()


func _draw() -> void:
	var frame := Rect2(Vector2.ZERO, size)
	draw_style_box(_frame_style, frame)
	if symbols.is_empty():
		return
	var icon_rect := frame.grow(-ICON_INSET)
	if is_spinning():
		icon_rect.position.y += _offset - size.y / 2.0
		draw_texture_rect(symbols[symbol], icon_rect, false, Color(1, 1, 1, 0.75))
		return
	draw_texture_rect(symbols[symbol], icon_rect, false)
