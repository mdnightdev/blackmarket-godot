class_name JobRow
extends PanelContainer

signal pressed

@onready var _icon_frame: PanelContainer = %IconFrame
@onready var _icon: TextureRect = %Icon
@onready var _title_label: Label = %TitleLabel
@onready var _caption_label: Label = %CaptionLabel
@onready var _pay_label: Label = %PayLabel
@onready var _hint_label: Label = %HintLabel
@onready var _tap_area: Button = %TapArea

var _pending_slot: StringName = &""
var _pending_icon_color := Color.WHITE


func _ready() -> void:
	_tap_area.pressed.connect(pressed.emit)
	if _pending_slot != &"":
		set_slot(_pending_slot)
	if _pending_icon_color != Color.WHITE:
		_icon.modulate = _pending_icon_color


func show_job(icon: Texture2D, title: String, pay: String, caption: String, hint: String, hint_color := Color.TRANSPARENT, slot_variation: StringName = &"SlotRare", icon_tint := Color.WHITE) -> void:
	_icon.texture = icon
	_title_label.text = title
	_caption_label.text = caption
	_pay_label.text = pay
	set_hint(hint, hint_color)
	_pending_icon_color = icon_tint
	if _icon != null:
		_icon.modulate = icon_tint
	if slot_variation != &"":
		set_slot(slot_variation)


func set_slot(variation: StringName) -> void:
	_pending_slot = variation
	var frame: PanelContainer = %IconFrame if has_node("%IconFrame") else _icon_frame
	if frame != null and variation != &"":
		frame.theme_type_variation = variation


func set_hint(hint: String, hint_color := Color.TRANSPARENT) -> void:
	_hint_label.text = hint
	_hint_label.visible = not hint.is_empty()
	if hint_color.a > 0.0:
		_hint_label.add_theme_color_override("font_color", hint_color)
	else:
		_hint_label.remove_theme_color_override("font_color")


func set_pay_color(color: Color) -> void:
	_pay_label.add_theme_color_override("font_color", color)


func set_tappable(tappable: bool) -> void:
	_tap_area.visible = tappable
