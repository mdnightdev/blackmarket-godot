class_name TurfScene
extends Control

## The headquarters compound on the Turf page. Each building carries a badge with its status that opens its part of
## the page. Buildings that are not built yet stay on the map, marked as coming soon.

signal building_tapped(id: StringName)

enum Status { OPEN, NEEDS_YOU, LOCKED, COMING_SOON }

const ART: Texture2D = preload("res://assets/backgrounds/turf_hq.jpg")
## Badge anchors as fractions of the painting, placed over each building.
const BUILDINGS: Array[Dictionary] = [
	{ "id": &"headquarters", "title": "Headquarters", "icon": preload("res://assets/icons/hud/crown.svg"), "at": Vector2(0.52, 0.31) },
	{ "id": &"pool", "title": "Pool & Lounge", "icon": preload("res://assets/icons/hud/waves.svg"), "at": Vector2(0.23, 0.215) },
	{ "id": &"gym", "title": "Gym", "icon": preload("res://assets/icons/hud/dumbbell.svg"), "at": Vector2(0.44, 0.145) },
	{ "id": &"hospital", "title": "Hospital", "icon": preload("res://assets/icons/hud/cross.svg"), "at": Vector2(0.7, 0.14) },
	{ "id": &"armory", "title": "Armory", "icon": preload("res://assets/icons/hud/swords.svg"), "at": Vector2(0.85, 0.23) },
	{ "id": &"safehouse", "title": "Safehouse", "icon": preload("res://assets/icons/hud/house.svg"), "at": Vector2(0.17, 0.36) },
	{ "id": &"garage", "title": "Garage", "icon": preload("res://assets/icons/hud/car.svg"), "at": Vector2(0.85, 0.4) },
	{ "id": &"intel", "title": "Research & Intel", "icon": preload("res://assets/icons/hud/radar.svg"), "at": Vector2(0.2, 0.49) },
	{ "id": &"businesses", "title": "Business Center", "icon": preload("res://assets/icons/hud/briefcase-business.svg"), "at": Vector2(0.8, 0.5) },
	{ "id": &"donations", "title": "Donations", "icon": preload("res://assets/icons/hud/handshake.svg"), "at": Vector2(0.17, 0.635) },
	{ "id": &"families", "title": "Families", "icon": preload("res://assets/icons/hud/users.svg"), "at": Vector2(0.72, 0.63) },
]
const STATUS_COLORS := {
	Status.OPEN: Palette.RISK_LOW,
	Status.NEEDS_YOU: Palette.PEACH_BRIGHT,
	Status.LOCKED: Palette.TEXT_MUTED,
	Status.COMING_SOON: Palette.TEXT_MUTED,
}
const COMING_SOON := "Coming soon"
const EDGE_MARGIN := 6.0
const BADGE_ALPHA := 0.86
const BADGE_RADIUS := 10
const BADGE_PADDING := Vector2(12, 7)
const ICON_SIZE := Vector2(22, 22)
const DOT_SIZE := Vector2(8, 8)
const TITLE_FONT_SIZE := 16
const STATUS_FONT_SIZE := 13
const DIMMED := Color(1, 1, 1, 0.72)

var _art: TextureRect
var _badges: Dictionary = {}
var _status_labels: Dictionary = {}
var _status_dots: Dictionary = {}


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	_art = TextureRect.new()
	_art.texture = ART
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_art)
	for building in BUILDINGS:
		_badges[building.id] = _add_badge(building)
		set_status(building.id, COMING_SOON, Status.COMING_SOON)
	resized.connect(_layout)
	_layout()


## Sets the short line under a building's name and how its badge reads. Coming-soon buildings cannot be opened.
func set_status(id: StringName, text: String, status: Status) -> void:
	var badge: GameButton = _badges.get(id)
	if badge == null:
		return
	var label: Label = _status_labels[id]
	label.text = text
	label.add_theme_color_override("font_color", Palette.PEACH_BRIGHT if status == Status.NEEDS_YOU else Palette.TEXT_MUTED)
	var dot: Panel = _status_dots[id]
	(dot.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = STATUS_COLORS[status]
	badge.disabled = status == Status.COMING_SOON
	badge.modulate = DIMMED if status in [Status.LOCKED, Status.COMING_SOON] else Color.WHITE
	_layout.call_deferred()


func _add_badge(building: Dictionary) -> GameButton:
	var badge := GameButton.new()
	badge.mouse_filter = Control.MOUSE_FILTER_PASS
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		badge.add_theme_stylebox_override(state, _badge_style(state == "pressed"))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	row.position = BADGE_PADDING
	var icon := TextureRect.new()
	icon.texture = building.icon
	icon.custom_minimum_size = ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.self_modulate = Palette.TEXT_CREAM
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_constant_override("separation", 0)
	text.add_child(_make_label(str(building.title), TITLE_FONT_SIZE, Palette.TEXT_CREAM))
	var status_row := HBoxContainer.new()
	status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_row.add_theme_constant_override("separation", 6)
	var dot := Panel.new()
	dot.custom_minimum_size = DOT_SIZE
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.add_theme_stylebox_override("panel", _dot_style())
	status_row.add_child(dot)
	var status := _make_label("", STATUS_FONT_SIZE, Palette.TEXT_MUTED)
	status_row.add_child(status)
	text.add_child(status_row)
	row.add_child(text)
	badge.add_child(row)
	badge.pressed.connect(building_tapped.emit.bind(building.id))
	_status_labels[building.id] = status
	_status_dots[building.id] = dot
	add_child(badge)
	return badge


func _badge_style(pressed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.SURFACE_ACTIVE if pressed else Palette.INK, BADGE_ALPHA)
	style.border_color = Palette.LINE_MUTED
	style.set_border_width_all(1)
	style.set_corner_radius_all(BADGE_RADIUS)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 6
	return style


func _dot_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(int(DOT_SIZE.x))
	return style


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


## Badges follow the painting's cover fit and stay inside the page at any screen size.
func _layout() -> void:
	var art_size := ART.get_size()
	var drawn := art_size * maxf(size.x / art_size.x, size.y / art_size.y)
	var origin := (size - drawn) / 2.0
	for building in BUILDINGS:
		var badge: GameButton = _badges[building.id]
		var content: Control = badge.get_child(0)
		content.size = content.get_combined_minimum_size()
		badge.size = content.size + BADGE_PADDING * 2.0
		var center := origin + Vector2(building.at) * drawn
		var top_left := center - badge.size / 2.0
		badge.position = top_left.clamp(Vector2.ONE * EDGE_MARGIN, size - badge.size - Vector2.ONE * EDGE_MARGIN)
