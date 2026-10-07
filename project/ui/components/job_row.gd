class_name JobRow
extends PanelContainer

@onready var _icon: TextureRect = %Icon
@onready var _title_label: Label = %TitleLabel
@onready var _caption_label: Label = %CaptionLabel
@onready var _pay_label: Label = %PayLabel
@onready var _hint_label: Label = %HintLabel


func show_job(icon: Texture2D, title: String, pay: String, caption: String, hint: String) -> void:
	_icon.texture = icon
	_title_label.text = title
	_caption_label.text = caption
	_pay_label.text = pay
	_hint_label.text = hint
	_hint_label.visible = not hint.is_empty()
