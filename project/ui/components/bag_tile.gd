class_name BagTile
extends GameButton

signal tile_selected(tile: BagTile)

## Tiles sit inside a scrolling grid, so a press that turned into a drag must not count as a tap.
const DRAG_CANCEL_DISTANCE := 14.0

var artwork: Texture2D
var title := ""
var meta := ""
var description := ""

var _press_position := Vector2.ZERO
var _dragged := false

@onready var _icon: TextureRect = %Icon
@onready var _count_label: Label = %CountLabel
@onready var _frame: Panel = %Frame


func _ready() -> void:
	super()
	pressed.connect(_on_tile_pressed)
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


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_press_position = event.global_position
		_dragged = false
	elif event is InputEventMouseMotion and not _dragged:
		_dragged = event.global_position.distance_to(_press_position) > DRAG_CANCEL_DISTANCE


func _on_tile_pressed() -> void:
	if not _dragged:
		tile_selected.emit(self)
