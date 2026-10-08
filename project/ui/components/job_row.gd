class_name JobRow
extends PanelContainer

signal pressed

@onready var _icon: TextureRect = %Icon
@onready var _title_label: Label = %TitleLabel
@onready var _caption_label: Label = %CaptionLabel
@onready var _pay_label: Label = %PayLabel
@onready var _hint_label: Label = %HintLabel
@onready var _tap_area: Button = %TapArea


func _ready() -> void:
	_tap_area.pressed.connect(pressed.emit)


func show_job(icon: Texture2D, title: String, pay: String, caption: String, hint: String, hint_color := Color.TRANSPARENT) -> void:
	_icon.texture = icon
	_title_label.text = title
	_caption_label.text = caption
	_pay_label.text = pay
	set_hint(hint, hint_color)


func set_hint(hint: String, hint_color := Color.TRANSPARENT) -> void:
	_hint_label.text = hint
	_hint_label.visible = not hint.is_empty()
	if hint_color.a > 0.0:
		_hint_label.add_theme_color_override("font_color", hint_color)


func set_pay_color(color: Color) -> void:
	_pay_label.add_theme_color_override("font_color", color)


func set_tappable(tappable: bool) -> void:
	_tap_area.visible = tappable
