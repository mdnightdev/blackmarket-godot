@tool
extends Control
class_name Badge

@export var title: String = "SECTION":
	set(v):
		title = v
		queue_redraw()

@export var accent_color: Color = Color("D4AF37"):
	set(v):
		accent_color = v
		queue_redraw()

@export var bg_color: Color = Color("080A0F"):
	set(v):
		bg_color = v
		queue_redraw()

@export var font_size: int = 12:
	set(v):
		font_size = v
		queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	var chamfer := 8.0
	
	var points := PackedVector2Array([
		Vector2(chamfer, 0),
		Vector2(w - chamfer, 0),
		Vector2(w, h * 0.5),
		Vector2(w - chamfer, h),
		Vector2(chamfer, h),
		Vector2(0, h * 0.5)
	])
	
	draw_colored_polygon(points, bg_color)
	draw_polyline(points, accent_color, 1.5, true)
	
	var font := get_theme_default_font()
	if font:
		var text_str := "< %s >" % title.to_upper()
		var text_size := font.get_string_size(text_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos := Vector2((w - text_size.x) * 0.5, (h + text_size.y * 0.7) * 0.5)
		draw_string(font, text_pos, text_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color("F0E6D2"))
