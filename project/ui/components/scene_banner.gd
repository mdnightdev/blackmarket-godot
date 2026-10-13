class_name SceneBanner
extends Control

## The painting at the top of a building's page, with the one number that matters there written over its foot.

const HEIGHT := 300.0
const SHADE_TOP := 0.35

var _art: TextureRect
var _value_label: Label
var _caption_label: Label


func _init() -> void:
	custom_minimum_size.y = HEIGHT
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art = TextureRect.new()
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_art)
	add_child(_shade())
	var info := VBoxContainer.new()
	info.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	info.grow_vertical = Control.GROW_DIRECTION_BEGIN
	info.offset_left = 18
	info.offset_right = -18
	info.offset_bottom = -14
	info.add_theme_constant_override("separation", 0)
	add_child(info)
	_value_label = Label.new()
	_value_label.theme_type_variation = &"HeaderLabel"
	_value_label.add_theme_color_override("font_color", Palette.TEXT_CREAM)
	info.add_child(_value_label)
	_caption_label = Label.new()
	_caption_label.theme_type_variation = &"HudCaptionLabel"
	_caption_label.add_theme_font_size_override("font_size", 15)
	info.add_child(_caption_label)


func show_scene(art: Texture2D, value: String, caption: String, value_color := Palette.TEXT_CREAM) -> void:
	_art.texture = art
	_value_label.text = value
	_value_label.add_theme_color_override("font_color", value_color)
	_caption_label.text = caption
	_caption_label.visible = not caption.is_empty()


func _shade() -> TextureRect:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, SHADE_TOP, 1.0])
	gradient.colors = PackedColorArray([Color(Palette.INK, 0.0), Color(Palette.INK, 0.2), Color(Palette.INK, 0.92)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 8
	texture.height = 128
	texture.fill_to = Vector2(0, 1)
	var shade := TextureRect.new()
	shade.texture = texture
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return shade
