class_name TurfSection
extends VBoxContainer

## A page opened from a building on the Turf headquarters.

const ITEM_ROW := preload("res://ui/components/item_row.tscn")
const UNIT_CARD := preload("res://ui/components/unit_card.tscn")
const GAP := 12


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
	var spacing := StyleBoxEmpty.new()
	spacing.content_margin_top = 8
	label.add_theme_stylebox_override("normal", spacing)
	add_child(label)


func _add_row(icon: Texture2D, title: String, value: String, caption: String, detail := "", detail_color := Palette.TEXT_MUTED, action := Callable()) -> void:
	var row: ItemRow = ITEM_ROW.instantiate()
	add_child(row)
	row.show_entry(icon, title, value, caption, detail, detail_color)
	if action.is_valid():
		row.item_selected.connect(func(_item: ItemDef) -> void: action.call())
	else:
		row.disabled = true


func _add_banner(art: Texture2D, value: String, caption: String, value_color := Palette.TEXT_CREAM) -> SceneBanner:
	var banner := SceneBanner.new()
	add_child(banner)
	banner.show_scene(art, value, caption, value_color)
	return banner


## A labelled bar, filled by ratio from 0 to 1.
func _add_meter(caption: String, value: String, ratio: float, color: Color) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var labels := HBoxContainer.new()
	box.add_child(labels)
	var caption_label := Label.new()
	caption_label.theme_type_variation = &"HudCaptionLabel"
	caption_label.text = caption.to_upper()
	caption_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.add_child(caption_label)
	var value_label := Label.new()
	value_label.theme_type_variation = &"HudValueLabel"
	value_label.text = value
	labels.add_child(value_label)
	var bar := ProgressBar.new()
	bar.theme_type_variation = &"ThinBar"
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.value = clampf(ratio, 0.0, 1.0)
	var fill: StyleBoxFlat = bar.get_theme_stylebox("fill").duplicate()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	box.add_child(bar)
	_add_spaced(box)


## Cards side by side, sharing the width.
func _add_card_row() -> HBoxContainer:
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 8)
	_add_spaced(cards)
	return cards


func _add_card(parent: Container, height := 0.0) -> UnitCard:
	var card: UnitCard = UNIT_CARD.instantiate()
	if height > 0.0:
		card.custom_minimum_size.y = height
	parent.add_child(card)
	return card


func _add_button(variation: StringName, text: String, enabled := true) -> Button:
	var button := GameButton.new()
	button.theme_type_variation = variation
	button.custom_minimum_size = Vector2(0, 56)
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.text = text
	button.disabled = not enabled
	_add_spaced(button)
	return button


## Prices for men are kept per thousand. Shown per man, with cents only when there are any.
static func per_man(per_thousand: int) -> String:
	if per_thousand % 1000 == 0:
		return "%s each" % Format.money(per_thousand / 1000)
	return "$%.2f each" % (per_thousand / 1000.0)


func _add_spaced(control: Control) -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", GAP)
	margin.add_child(control)
	add_child(margin)
