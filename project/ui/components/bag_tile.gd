class_name BagTile
extends GameButton

signal tile_selected(tile: BagTile)

var artwork: Texture2D
var title := ""
var meta := ""
var description := ""

@onready var _icon: TextureRect = %Icon
@onready var _count_label: Label = %CountLabel


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
	var base := get_theme_stylebox(&"normal")
	if not (base is StyleBoxFlat):
		return
	var style: StyleBoxFlat = base.duplicate()
	if selected:
		style.border_color = Palette.STEEL_BRIGHT
		style.set_border_width_all(2)
		style.bg_color = Palette.SURFACE_ACTIVE
	else:
		style.border_color = Color.TRANSPARENT
		style.set_border_width_all(0)
		style.bg_color = Palette.PANEL_LIFT
	add_theme_stylebox_override(&"normal", style)
	add_theme_stylebox_override(&"hover", style)
	add_theme_stylebox_override(&"pressed", style)
	add_theme_stylebox_override(&"focus", style)
