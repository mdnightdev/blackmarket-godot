class_name GearCard
extends PanelContainer

## Art-first card for one piece of gear: big icon, name, effect line, price and status.
## The frame (Slot* theme variation) shows state: gold = owned, cyan = can buy, steel = can't afford.
## Built entirely in code, so there is no .tscn to wire up.

signal item_selected(item: ItemDef)

const ICON_SIZE := 96

var _item: ItemDef
var _owned := false


func display(item: ItemDef, owned: bool, affordable: bool, caption: String) -> void:
	_item = item
	_owned = owned
	for child in get_children():
		child.queue_free()

	theme_type_variation = &"SlotLegendary" if owned else (&"SlotRare" if affordable else &"SlotCommon")
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(0, 232)

	var tap := Button.new()
	tap.theme_type_variation = &"GhostButton"
	tap.focus_mode = Control.FOCUS_NONE
	tap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tap.disabled = owned
	tap.pressed.connect(func() -> void: item_selected.emit(_item))
	add_child(tap)


	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	add_child(box)

	var icon := TextureRect.new()
	icon.texture = item.icon
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)

	box.add_child(_label(item.display_name, &"Label", 17, Palette.TEXT_CREAM))
	box.add_child(_label(caption, &"MutedLabel", 13, Palette.TEXT_MUTED))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(spacer)

	var price_text := "OWNED" if owned else Format.money(item.base_price)
	box.add_child(_label(price_text, &"Label", 18, Palette.PRICE if (owned or affordable) else Palette.TEXT_MUTED))
	if not owned:
		box.add_child(_label("TAP TO BUY" if affordable else "NOT ENOUGH CASH", &"HudCaptionLabel", 12, Palette.TEXT_MUTED))



func _label(text: String, variation: StringName, size: int, color: Color) -> Label:
	var label := Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
