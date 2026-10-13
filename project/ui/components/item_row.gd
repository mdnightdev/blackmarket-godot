class_name ItemRow
extends GameButton

signal item_selected(item: ItemDef)

var item: ItemDef

@onready var _icon_frame: Control = %IconFrame
@onready var _icon: TextureRect = %Icon
@onready var _name_label: Label = %NameLabel
@onready var _caption_label: Label = %CaptionLabel
@onready var _price_label: Label = %PriceLabel
@onready var _detail_label: Label = %DetailLabel


func _ready() -> void:
	super()
	pressed.connect(func() -> void: item_selected.emit(item))


func display(entry: ItemDef, price_text: String, caption: String, detail: String = "", detail_color: Color = Palette.TEXT_MUTED) -> void:
	item = entry
	show_entry(entry.icon, entry.display_name, price_text, caption, detail, detail_color)


## For rows that are not catalog items, such as smuggling crates. item_selected then sends null. A null icon leaves
## the picture out.
func show_entry(icon: Texture2D, title: String, price_text: String, caption: String, detail: String = "", detail_color: Color = Palette.TEXT_MUTED) -> void:
	_icon.texture = icon
	_icon_frame.visible = icon != null
	_name_label.text = title
	_caption_label.text = caption
	_price_label.text = price_text
	_detail_label.text = detail
	_detail_label.visible = not detail.is_empty()
	_detail_label.add_theme_color_override("font_color", detail_color)

