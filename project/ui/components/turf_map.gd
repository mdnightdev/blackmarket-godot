class_name TurfMap
extends Control

## The city map at the top of the Turf page, rendering the Tokyo Bay vector sectors tinted by who runs each turf.

signal district_tapped(district: DistrictDef)

const MAP_HEIGHT := 460.0
const VX0 := 0.06
const VY0 := 0.02
const VSPAN := 0.76
const LABEL_WIDTH := 156.0
const LABEL_HEIGHT := 54.0
const NAME_FONT_SIZE := 14
const STATUS_FONT_SIZE := 12
const LABEL_OUTLINE := 5
const TAP_SLOP := 18.0
static var OPEN_CITY_COLOR: Color:
	get: return Palette.LINE_MUTED

const COLOR_OCEAN := Color(0.027, 0.047, 0.078)
const COLOR_COAST_RIM := Color(0.275, 0.376, 0.486, 0.85)
const COLOR_OUTER_LAND := Color(0.071, 0.086, 0.114)
const COLOR_LOCKED_WARD := Color(0.118, 0.145, 0.184)
const COLOR_SEAM_DARK := Color(0.031, 0.043, 0.063, 0.9)

const DISTRICT_TO_WARD := {
	&"the_heights": "Shinjuku",
	&"west_end": "Setagaya",
	&"downtown": "Minato",
	&"slums": "Ota",
	&"riverside": "Kawasaki",
	&"docks": "Yokohama",
	&"old_market": "Katsushika",
	&"warehouse_row": "Koto",
	&"golden_mile": "Edogawa",
	&"north_port": "Funabashi",
}

var _press_at := Vector2.ZERO
var _labels: Dictionary = {}
var _water_norm := PackedVector2Array()
var _wards_norm: Dictionary = {}
var _ward_centers: Dictionary = {}
var _ward_to_district: Dictionary = {}


func _ready() -> void:
	custom_minimum_size.y = MAP_HEIGHT
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	_load_vector_data()
	for district in Content.districts():
		_labels[district.id] = _add_label(district)
	resized.connect(_layout)
	_layout()


func _norm_pt(raw_pt: Array) -> Vector2:
	return Vector2((float(raw_pt[0]) - VX0) / VSPAN, (float(raw_pt[1]) - VY0) / VSPAN)


func _load_vector_data() -> void:
	for dist_id: StringName in DISTRICT_TO_WARD:
		_ward_to_district[DISTRICT_TO_WARD[dist_id]] = dist_id

	var path := "res://data/tokyo.json"
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return
	var data: Dictionary = parsed

	_water_norm.clear()
	for pt: Array in data.get("water", []):
		_water_norm.append(_norm_pt(pt))

	_wards_norm.clear()
	_ward_centers.clear()
	var raw_wards: Dictionary = data.get("wards", {})
	for ward_name: String in raw_wards:
		var rings_raw: Array = raw_wards[ward_name]
		var rings: Array[PackedVector2Array] = []
		var best_ring := PackedVector2Array()
		var best_len := 0
		for r_raw: Array in rings_raw:
			var ring := PackedVector2Array()
			for pt: Array in r_raw:
				ring.append(_norm_pt(pt))
			if ring.size() >= 3:
				rings.append(ring)
				if ring.size() > best_len:
					best_len = ring.size()
					best_ring = ring
		_wards_norm[ward_name] = rings
		if best_ring.size() > 0:
			var sum := Vector2.ZERO
			for p: Vector2 in best_ring:
				sum += p
			_ward_centers[ward_name] = sum / float(best_ring.size())


func _add_label(district: DistrictDef) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	box.size = Vector2(LABEL_WIDTH, LABEL_HEIGHT)
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
	for district_id: StringName in _labels:
		var box: VBoxContainer = _labels[district_id]
		var center := _district_view_pos(district_id)
		box.position = center - box.size / 2.0
	queue_redraw()


func _to_view(norm_pt: Vector2) -> Vector2:
	# Frame the active Tokyo Bay metro region (x: 0.02..0.88, y: 0.0..0.78)
	var min_n := Vector2(0.02, 0.00)
	var span_n := Vector2(0.86, 0.78)
	var scale_f := maxf(size.x / span_n.x, size.y / span_n.y)
	var drawn := span_n * scale_f
	var offset := (size - drawn) / 2.0
	return offset + (norm_pt - min_n) * scale_f


func _district_view_pos(district_id: StringName) -> Vector2:
	var ward_name: String = DISTRICT_TO_WARD.get(district_id, "")
	if not ward_name.is_empty() and _ward_centers.has(ward_name):
		return _to_view(_ward_centers[ward_name])
	var d := Content.district(district_id)
	return _to_view(d.map_position) if d != null else size / 2.0


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_OUTER_LAND, true)
	var run := GameState.run

	for ward_name: String in _wards_norm:
		var dist_id: StringName = _ward_to_district.get(ward_name, &"")
		var fill_col := COLOR_LOCKED_WARD
		var border_col := Color(0.32, 0.39, 0.48, 0.45)
		var border_w := 1.2
		if dist_id != &"":
			var district := Content.district(dist_id)
			if district != null:
				var z_col := _zone_color(district)
				fill_col = COLOR_LOCKED_WARD.lerp(z_col, 0.42)
				border_col = Palette.TEXT_CREAM if (run != null and run.district_id == dist_id) else z_col
				border_w = 2.6 if (run != null and run.district_id == dist_id) else 1.8

		var rings: Array = _wards_norm[ward_name]
		for ring: PackedVector2Array in rings:
			var v_pts := PackedVector2Array()
			for pt: Vector2 in ring:
				v_pts.append(_to_view(pt))
			draw_colored_polygon(v_pts, fill_col)
			v_pts.append(v_pts[0])
			draw_polyline(v_pts, COLOR_SEAM_DARK, border_w + 1.5)
			draw_polyline(v_pts, border_col, border_w)

	if _water_norm.size() >= 3:
		var bay_pts := PackedVector2Array()
		for pt: Vector2 in _water_norm:
			bay_pts.append(_to_view(pt))
		draw_colored_polygon(bay_pts, COLOR_OCEAN)
		bay_pts.append(bay_pts[0])
		draw_polyline(bay_pts, COLOR_COAST_RIM, 1.5)


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
	var nearest_distance := 64.0
	for district in Content.districts():
		var distance := point.distance_to(_district_view_pos(district.id))
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
		var family := Turf.home_family(district.id)
		return family.chinese_name if family != null else "Open city"
	var share := Turf.share(run, district.id)
	var owners := Gangs.owners(district.id)
	match Turf.holder(run, district.id):
		Turf.Holder.PLAYER:
			return "Yours %d%%" % share
		Turf.Holder.GANG:
			if owners.size() > 1:
				return "%s / %s" % [owners[0].display_name, owners[1].display_name]
			return "%s %d%%" % [owners[0].display_name, 100 - share]
	return "Contested %d%%" % share
