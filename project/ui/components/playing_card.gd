class_name PlayingCard
extends Control

enum Suit { SPADES, HEARTS, DIAMONDS, CLUBS }

const RED_SUIT := Color("a23a48")
const RANK_NAMES := ["", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
const CORNER_RADIUS := 10
const RANK_FONT_SIZE := 30

var rank := 1:
	set(new_value):
		rank = clampi(new_value, 1, 13)
		queue_redraw()
var suit := Suit.SPADES:
	set(new_value):
		suit = new_value
		queue_redraw()
var face_down := false:
	set(new_value):
		face_down = new_value
		queue_redraw()

var _face_style := StyleBoxFlat.new()
var _back_style := StyleBoxFlat.new()


func _init() -> void:
	custom_minimum_size = Vector2(96, 136)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face_style.bg_color = Palette.TEXT_CREAM
	_face_style.set_corner_radius_all(CORNER_RADIUS)
	_back_style.bg_color = Palette.PANEL_LIFT
	_back_style.border_color = Palette.PEACH_BORDER
	_back_style.set_border_width_all(4)
	_back_style.set_corner_radius_all(CORNER_RADIUS)


func _draw() -> void:
	var card := Rect2(Vector2.ZERO, size)
	if face_down:
		draw_style_box(_back_style, card)
		draw_rect(card.grow(-14), Palette.PEACH_BORDER * Color(1, 1, 1, 0.35), false, 2.0)
		return
	draw_style_box(_face_style, card)
	var color := RED_SUIT if suit == Suit.HEARTS or suit == Suit.DIAMONDS else Palette.INK
	var font := get_theme_default_font()
	draw_string(font, Vector2(10, 8 + RANK_FONT_SIZE), RANK_NAMES[rank], HORIZONTAL_ALIGNMENT_LEFT, -1, RANK_FONT_SIZE, color)
	_draw_suit(Vector2(size.x / 2.0, size.y * 0.62), size.x * 0.22, color)


func _draw_suit(center: Vector2, radius: float, color: Color) -> void:
	match suit:
		Suit.DIAMONDS:
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(0, -radius), center + Vector2(radius * 0.72, 0),
				center + Vector2(0, radius), center + Vector2(-radius * 0.72, 0),
			]), color)
		Suit.HEARTS:
			draw_circle(center + Vector2(-radius * 0.45, -radius * 0.25), radius * 0.5, color)
			draw_circle(center + Vector2(radius * 0.45, -radius * 0.25), radius * 0.5, color)
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(-radius * 0.93, -radius * 0.05), center + Vector2(radius * 0.93, -radius * 0.05),
				center + Vector2(0, radius),
			]), color)
		Suit.SPADES:
			draw_circle(center + Vector2(-radius * 0.45, radius * 0.15), radius * 0.5, color)
			draw_circle(center + Vector2(radius * 0.45, radius * 0.15), radius * 0.5, color)
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(0, -radius), center + Vector2(radius * 0.93, radius * 0.25),
				center + Vector2(-radius * 0.93, radius * 0.25),
			]), color)
			_draw_stem(center, radius, color)
		Suit.CLUBS:
			draw_circle(center + Vector2(0, -radius * 0.45), radius * 0.42, color)
			draw_circle(center + Vector2(-radius * 0.45, radius * 0.1), radius * 0.42, color)
			draw_circle(center + Vector2(radius * 0.45, radius * 0.1), radius * 0.42, color)
			_draw_stem(center, radius, color)


func _draw_stem(center: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, radius * 0.3), center + Vector2(radius * 0.35, radius),
		center + Vector2(-radius * 0.35, radius),
	]), color)
