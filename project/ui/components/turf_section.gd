class_name TurfSection
extends VBoxContainer

## A page of rows opened from a building on the Turf headquarters.

const ITEM_ROW := preload("res://ui/components/item_row.tscn")


func _ready() -> void:
	add_theme_constant_override("separation", 0)
	_build(GameState.run)


func _build(_run: RunState) -> void:
	pass


func _add_heading(text: String) -> void:
	var label := Label.new()
	label.theme_type_variation = &"ListHeading"
	label.text = text
	add_child(label)


func _add_note(text: String) -> void:
	var label := Label.new()
	label.theme_type_variation = &"MutedLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	add_child(label)


func _add_row(icon: Texture2D, title: String, value: String, caption: String, detail := "", detail_color := Palette.TEXT_MUTED, action := Callable()) -> void:
	var row: ItemRow = ITEM_ROW.instantiate()
	add_child(row)
	row.show_entry(icon, title, value, caption, detail, detail_color)
	if action.is_valid():
		row.item_selected.connect(func(_item: ItemDef) -> void: action.call())
	else:
		row.disabled = true
