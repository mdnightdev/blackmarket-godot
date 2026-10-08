class_name TurfScene
extends Control

## The painted block on the Turf page. Each building carries a badge that opens its part of the page.

signal building_tapped(id: StringName)

const ART: Texture2D = preload("res://assets/backgrounds/turf_block.jpg")
## Badge anchors as fractions of the painting, placed over each building.
const BUILDINGS: Array[Dictionary] = [
	{ "id": &"safehouse", "title": "Safehouse", "at": Vector2(0.23, 0.19) },
	{ "id": &"crew", "title": "Crew", "at": Vector2(0.77, 0.21) },
	{ "id": &"districts", "title": "Districts", "at": Vector2(0.19, 0.47) },
	{ "id": &"businesses", "title": "Businesses", "at": Vector2(0.79, 0.48) },
	{ "id": &"skills", "title": "Skills", "at": Vector2(0.23, 0.76) },
	{ "id": &"families", "title": "Families", "at": Vector2(0.79, 0.75) },
]
const BADGE_MIN_WIDTH := 150.0
const BADGE_ALPHA := 0.88
const BADGE_RADIUS := 10
const BADGE_PADDING := Vector2(14, 8)
const TITLE_FONT_SIZE := 17
const STATUS_FONT_SIZE := 14

var _badges: Dictionary = {}
var _status_labels: Dictionary = {}


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	var art := TextureRect.new()
	art.texture = ART
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(art)
	for building in BUILDINGS:
		_badges[building.id] = _add_badge(building)
	resized.connect(_layout)
	_layout()


## Sets the short line under a building's name. Highlighted lines stand out when something needs attention.
func set_status(id: StringName, text: String, highlighted := false) -> void:
	var label: Label = _status_labels.get(id)
	if label == null:
		return
	label.text = text
	label.add_theme_color_override("font_color", Palette.RISK_LOW if highlighted else Palette.TEXT_MUTED)


func _add_badge(building: Dictionary) -> GameButton:
	var badge := GameButton.new()
	badge.mouse_filter = Control.MOUSE_FILTER_PASS
	badge.custom_minimum_size.x = BADGE_MIN_WIDTH
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		badge.add_theme_stylebox_override(state, _badge_style(state == "pressed"))
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 0)
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_make_label(str(building.title), TITLE_FONT_SIZE, Palette.TEXT_CREAM))
	var status := _make_label("", STATUS_FONT_SIZE, Palette.TEXT_MUTED)
	box.add_child(status)
	badge.add_child(box)
	badge.pressed.connect(building_tapped.emit.bind(building.id))
	_status_labels[building.id] = status
	add_child(badge)
	return badge


func _badge_style(pressed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.SURFACE_ACTIVE if pressed else Palette.INK, BADGE_ALPHA)
	style.border_color = Palette.LINE_MUTED
	style.set_border_width_all(1)
	style.set_corner_radius_all(BADGE_RADIUS)
	style.content_margin_left = BADGE_PADDING.x
	style.content_margin_right = BADGE_PADDING.x
	style.content_margin_top = BADGE_PADDING.y
	style.content_margin_bottom = BADGE_PADDING.y
	return style


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _layout() -> void:
	custom_minimum_size.y = size.x * ART.get_height() / ART.get_width()
	for building in BUILDINGS:
		var badge: GameButton = _badges[building.id]
		var content: Control = badge.get_child(0)
		badge.size = Vector2(maxf(BADGE_MIN_WIDTH, content.get_combined_minimum_size().x + BADGE_PADDING.x * 2.0), content.get_combined_minimum_size().y + BADGE_PADDING.y * 2.0)
		badge.position = Vector2(building.at) * size - badge.size / 2.0
