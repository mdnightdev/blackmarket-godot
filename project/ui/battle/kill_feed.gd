class_name KillFeed
extends VBoxContainer
## Bottom-left list of squads wiped out during a fight, newest at the bottom.

const MARKER_SIZE := Vector2(10.0, 10.0)
const FADE_SECONDS := 0.25


func _ready() -> void:
	add_theme_constant_override("separation", 6)


func add_entry(text_value: String, marker_color: Color) -> void:
	var entry := PanelContainer.new()
	entry.theme_type_variation = &"Card"
	entry.modulate.a = 0.0
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	entry.add_child(row)
	var marker := ColorRect.new()
	marker.color = marker_color
	marker.custom_minimum_size = MARKER_SIZE
	marker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(marker)
	var label := Label.new()
	label.theme_type_variation = &"CaptionLabel"
	label.text = text_value
	row.add_child(label)
	add_child(entry)
	create_tween().tween_property(entry, "modulate:a", 1.0, FADE_SECONDS)
