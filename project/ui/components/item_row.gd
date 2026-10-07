class_name ItemRow
extends GameButton

signal item_selected(item: ItemDef)

## Rows sit inside scroll lists, so a press that turned into a drag must not count as a tap.
const DRAG_CANCEL_DISTANCE := 14.0

var item: ItemDef

var _press_position := Vector2.ZERO
var _dragged := false

@onready var _icon: TextureRect = %Icon
@onready var _name_label: Label = %NameLabel
@onready var _caption_label: Label = %CaptionLabel
@onready var _price_label: Label = %PriceLabel
@onready var _detail_label: Label = %DetailLabel


func _ready() -> void:
	super()
	pressed.connect(_on_row_pressed)


func display(entry: ItemDef, price_text: String, caption: String, detail: String = "", detail_color: Color = Palette.TEXT_MUTED) -> void:
	item = entry
	show_entry(entry.icon, entry.display_name, price_text, caption, detail, detail_color)


## For rows that are not catalog items, such as smuggling crates. item_selected then sends null.
func show_entry(icon: Texture2D, title: String, price_text: String, caption: String, detail: String = "", detail_color: Color = Palette.TEXT_MUTED) -> void:
	_icon.texture = icon
	_name_label.text = title
	_caption_label.text = caption
	_price_label.text = price_text
	_detail_label.text = detail
	_detail_label.visible = not detail.is_empty()
	_detail_label.add_theme_color_override("font_color", detail_color)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_press_position = event.global_position
		_dragged = false
	elif event is InputEventMouseMotion and not _dragged:
		_dragged = event.global_position.distance_to(_press_position) > DRAG_CANCEL_DISTANCE


func _on_row_pressed() -> void:
	if not _dragged:
		item_selected.emit(item)
