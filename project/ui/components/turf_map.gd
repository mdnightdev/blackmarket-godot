class_name TurfMap
extends Control

## The city map at the top of the Turf page, with every district tinted by who runs it.

signal district_tapped(district: DistrictDef)

const MAP_TEXTURE: Texture2D = preload("res://assets/backgrounds/map_city.jpg")
const MAP_HEIGHT := 460.0
## Normalized margin kept around the outermost districts.
const MAP_PADDING := 0.13
const SHADE := Color(0.0471, 0.0549, 0.0706, 0.45)
const ZONE_RADIUS := 62.0
const ZONE_FILL_ALPHA := 0.38
const ZONE_RING_WIDTH := 3.0
const HERE_RING_GAP := 9.0
const LABEL_WIDTH := 170.0
const NAME_FONT_SIZE := 17
const STATUS_FONT_SIZE := 14
const LABEL_OUTLINE := 6
const TAP_SLOP := 18.0
const OPEN_CITY_COLOR := Palette.LINE_MUTED

var _region := Rect2()
var _press_at := Vector2.ZERO
var _labels: Dictionary = {}


func _ready() -> void:
	custom_minimum_size.y = MAP_HEIGHT
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	for district in Content.districts():
		_labels[district.id] = _add_label(district)
	resized.connect(_layout)
	_layout()


func _add_label(district: DistrictDef) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	box.size = Vector2(LABEL_WIDTH, ZONE_RADIUS * 2.0)
	box.add_child(_make_label(district.display_name, NAME_FONT_SIZE, Palette.TEXT_CREAM))
	box.add_child(_make_label(_status_text(district), STATUS_FONT_SIZE, _zone_color(district).lightened(0.25)))
	add_child(box)
	return box


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Palette.INK)
	label.add_theme_constant_override("outline_size", LABEL_OUTLINE)
	return label


func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_region = _fit_region()
	for district_id: StringName in _labels:
		var box: VBoxContainer = _labels[district_id]
		var center := _to_view(Content.district(district_id).map_position)
		box.position = center - box.size / 2.0
	queue_redraw()


## The part of the map texture that frames every district at this control's aspect ratio.
func _fit_region() -> Rect2:
	var low := Vector2.ONE
	var high := Vector2.ZERO
	for district in Content.districts():
		low = low.min(district.map_position)
		high = high.max(district.map_position)
	var texture_size := Vector2(MAP_TEXTURE.get_size())
	var frame := Rect2(low - Vector2.ONE * MAP_PADDING, high - low + Vector2.ONE * MAP_PADDING * 2.0)
	var pixels := Rect2(frame.position * texture_size, frame.size * texture_size)
	var aspect := size.x / size.y
	if pixels.size.x / pixels.size.y < aspect:
		pixels = pixels.grow_individual((pixels.size.y * aspect - pixels.size.x) / 2.0, 0.0, (pixels.size.y * aspect - pixels.size.x) / 2.0, 0.0)
	else:
		pixels = pixels.grow_individual(0.0, (pixels.size.x / aspect - pixels.size.y) / 2.0, 0.0, (pixels.size.x / aspect - pixels.size.y) / 2.0)
	var bounds := Rect2(Vector2.ZERO, texture_size)
	pixels.position = pixels.position.clamp(Vector2.ZERO, (bounds.size - pixels.size).max(Vector2.ZERO))
	return pixels.intersection(bounds)


func _to_view(normalized: Vector2) -> Vector2:
	var pixel := normalized * Vector2(MAP_TEXTURE.get_size())
	return (pixel - _region.position) / _region.size * size


func _draw() -> void:
	if _region.has_area():
		draw_texture_rect_region(MAP_TEXTURE, Rect2(Vector2.ZERO, size), _region)
	draw_rect(Rect2(Vector2.ZERO, size), SHADE)
	var run := GameState.run
	for district in Content.districts():
		var center := _to_view(district.map_position)
		var color := _zone_color(district)
		draw_circle(center, ZONE_RADIUS, Color(color, ZONE_FILL_ALPHA))
		draw_arc(center, ZONE_RADIUS, 0.0, TAU, 64, color, ZONE_RING_WIDTH, true)
		if run != null and district.id == run.district_id:
			draw_arc(center, ZONE_RADIUS + HERE_RING_GAP, 0.0, TAU, 64, Palette.TEXT_CREAM, 2.0, true)


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return
	if button.pressed:
		_press_at = button.position
		return
	if button.position.distance_to(_press_at) > TAP_SLOP:
		return
	var tapped := _district_at(button.position)
	if tapped != null:
		accept_event()
		district_tapped.emit(tapped)


func _district_at(point: Vector2) -> DistrictDef:
	var nearest: DistrictDef = null
	var nearest_distance := ZONE_RADIUS + HERE_RING_GAP
	for district in Content.districts():
		var distance := point.distance_to(_to_view(district.map_position))
		if distance <= nearest_distance:
			nearest = district
			nearest_distance = distance
	return nearest


func _zone_color(district: DistrictDef) -> Color:
	if not Turf.is_contested(district.id):
		return OPEN_CITY_COLOR
	return TurfBar.holder_color(Turf.holder(GameState.run, district.id), district.id)


func _status_text(district: DistrictDef) -> String:
	var run := GameState.run
	if not Turf.is_contested(district.id):
		return "Open city"
	var share := Turf.share(run, district.id)
	match Turf.holder(run, district.id):
		Turf.Holder.PLAYER:
			return "Yours %d%%" % share
		Turf.Holder.GANG:
			return "%s %d%%" % [Gangs.owner(district.id).display_name, 100 - share]
	return "Contested %d%%" % share
