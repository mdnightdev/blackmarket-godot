class_name BagTile
extends GameButton

signal tile_selected(tile: BagTile)

var artwork: Texture2D
var title := ""
var meta := ""
var description := ""

@onready var _icon: TextureRect = %Icon
@onready var _count_label: Label = %CountLabel
@onready var _frame: Panel = %Frame


func _ready() -> void:
	super()
	pressed.connect(func() -> void: tile_selected.emit(self))
	set_selected(false)


func show_entry(entry_icon: Texture2D, count_text: String, entry_title: String, entry_meta: String, entry_description: String) -> void:
	artwork = entry_icon
	_icon.texture = entry_icon
	_count_label.text = count_text
	_count_label.visible = not count_text.is_empty()
	title = entry_title
	meta = entry_meta
	description = entry_description


func set_selected(selected: bool) -> void:
	var style: StyleBoxFlat = _frame.get_theme_stylebox("panel").duplicate()
	style.border_color = Palette.TEXT_CREAM if selected else Palette.LINE_MUTED
	style.set_border_width_all(3 if selected else 1)
	_frame.add_theme_stylebox_override("panel", style)

