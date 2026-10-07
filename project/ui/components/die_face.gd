class_name DieFace
extends Control

const CORNER_RADIUS := 14
const PIP_RADIUS_RATIO := 0.09
## Pip positions on a 3 by 3 grid, from -1 to 1 on each axis.
const PIPS := {
	1: [Vector2(0, 0)],
	2: [Vector2(-1, -1), Vector2(1, 1)],
	3: [Vector2(-1, -1), Vector2(0, 0), Vector2(1, 1)],
	4: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)],
	5: [Vector2(-1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(1, 1)],
	6: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)],
}

var value := 1:
	set(new_value):
		value = clampi(new_value, 1, 6)
		queue_redraw()

var _face_style := StyleBoxFlat.new()


func _init() -> void:
	custom_minimum_size = Vector2(136, 136)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face_style.bg_color = Palette.TEXT_CREAM
	_face_style.set_corner_radius_all(CORNER_RADIUS)


func _draw() -> void:
	var side := minf(size.x, size.y)
	var square := Rect2((size - Vector2(side, side)) / 2.0, Vector2(side, side))
	draw_style_box(_face_style, square)
	var center := square.get_center()
	var spread := side * 0.27
	for pip: Vector2 in PIPS[value]:
		draw_circle(center + pip * spread, side * PIP_RADIUS_RATIO, Palette.INK)
