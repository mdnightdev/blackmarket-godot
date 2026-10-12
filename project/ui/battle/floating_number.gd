class_name FloatingNumber
extends Label
## A loss number that rises off the battlefield and fades.

const RISE := 46.0
const SECONDS := 0.9
const FONT_SIZE := 22


static func spawn(parent: Node, at: Vector2, text_value: String, color: Color) -> void:
	var number := FloatingNumber.new()
	number.text = text_value
	number.z_index = 10
	number.add_theme_font_size_override("font_size", FONT_SIZE)
	number.add_theme_color_override("font_color", color)
	number.add_theme_color_override("font_outline_color", Palette.INK)
	number.add_theme_constant_override("outline_size", 6)
	parent.add_child(number)
	number.position = at - number.get_minimum_size() / 2.0
	number._rise()


func _rise() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", position.y - RISE, SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, SECONDS * 0.5).set_delay(SECONDS * 0.5)
	tween.chain().tween_callback(queue_free)
