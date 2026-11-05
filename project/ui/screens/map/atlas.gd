extends BaseScreen

const CANVAS_SIZE := Vector2(3072.0, 3072.0)
const VX0 := 0.06
const VY0 := 0.02
const VSPAN := 0.76

const MIN_ZOOM := 0.70
const MAX_ZOOM := 4.5
const START_ZOOM := 1.15
const WHEEL_ZOOM_STEP := 1.12
const PAN_GESTURE_SPEED := 8.0
const TAP_SLOP := 18.0
const FLING_FRICTION := 5.0
const MIN_FLING_SPEED := 20.0

const ROUTE_SECONDS := 1.25
const CAMERA_GLIDE_SECONDS := 0.45
const BOOKED_TRIP_DELAY_SECONDS := 0.7
const LAPSE_PHASE_SECONDS := 0.6
const LAPSE_DIM := Color(0.45, 0.42, 0.5)
static var CRATE_ROUTE_COLOR: Color:
	get: return Color(Palette.PEACH, 0.65)

const COLOR_OCEAN := Color(0.027, 0.047, 0.078)
const COLOR_COAST_RIM := Color(0.275, 0.376, 0.486)
const COLOR_OUTER_LAND := Color(0.071, 0.086, 0.114)
const COLOR_ISLAND_LAND := Color(0.192, 0.235, 0.294)

const SLATE_TONES: Array[Color] = [
	Color(0.098, 0.122, 0.157),
	Color(0.141, 0.173, 0.220),
	Color(0.192, 0.235, 0.294),
	Color(0.161, 0.200, 0.251),
]

const COLOR_PRIM_CASING := Color(0.078, 0.098, 0.125)
const COLOR_PRIM_FILL := Color(0.212, 0.255, 0.314)
const COLOR_TRUNK_CASING := Color(0.071, 0.086, 0.114)
const COLOR_TRUNK_FILL := Color(0.282, 0.341, 0.416)
const COLOR_MWAY_CASING := Color(0.055, 0.071, 0.094)
const COLOR_MWAY_FILL := Color(0.420, 0.494, 0.588)

const COLOR_SEAM_DARK := Color(0.031, 0.043, 0.063, 0.94)
const COLOR_SEAM_ACTIVE := Color(0.820, 0.894, 0.969, 0.96)
const COLOR_SEAM_LOCKED := Color(0.392, 0.490, 0.600, 0.58)
const COLOR_FAMILY_RING := Color(0.878, 0.686, 0.345, 0.95)
const COLOR_SELECTED_FILL := Color(0.85, 0.66, 0.32, 0.28)
const COLOR_SELECTED_OUTLINE := Color(0.96, 0.82, 0.48, 1.0)
const COLOR_CURRENT_RING := Color(0.42, 0.88, 0.62, 0.95)

# All 34  Underworld Sectors:
# - 10 Open / Playable Sectors spread across BOTH sides of the Sumida/Arakawa/Edo rivers & around Tokyo Bay
# - 24 Locked Expansion Sectors (including central buffer wards so labels never crowd)
# - 6 Major Family Strongholds (3 playable + 3 locked)
const SECTOR_INFO := {
	# --- WEST & SOUTH-WEST OF THE RIVER (6 Playable Sectors) ---
	"Shinjuku": {"name": "KABUKICHO", "id": &"the_heights", "tone": 0, "family": "RED LOTUS HALL", "center": Vector2(0.285, 0.125)},
	"Setagaya": {"name": "MONG KOK", "id": &"west_end", "tone": 2, "family": "", "center": Vector2(0.165, 0.225)},
	"Minato": {"name": "WAN CHAI", "id": &"downtown", "tone": 1, "family": "AZURE DRAGON SOCIETY", "center": Vector2(0.315, 0.215)},
	"Ota": {"name": "KOWLOON WALLED", "id": &"slums", "tone": 1, "family": "", "center": Vector2(0.255, 0.345)},
	"Kawasaki": {"name": "HUANGPU DOCKS", "id": &"riverside", "tone": 0, "family": "", "center": Vector2(0.195, 0.425)},
	"Yokohama": {"name": "KAOHSIUNG PORT", "id": &"docks", "tone": 2, "family": "", "center": Vector2(0.145, 0.565)},

	# --- EAST SIDE OF THE SUMIDA / ARAKAWA / EDO RIVERS & EAST BAY (4 Playable Sectors) ---
	"Katsushika": {"name": "WANHUA", "id": &"old_market", "tone": 2, "family": "", "center": Vector2(0.505, 0.068)},
	"Koto": {"name": "GEYLANG", "id": &"warehouse_row", "tone": 2, "family": "", "center": Vector2(0.435, 0.175)},
	"Edogawa": {"name": "MACAU HARBOR", "id": &"golden_mile", "tone": 0, "family": "WHITE TIGER GANG", "center": Vector2(0.528, 0.135)},
	"Funabashi": {"name": "KWAI CHUNG", "id": &"north_port", "tone": 0, "family": "", "center": Vector2(0.675, 0.145)},

	# --- 24 LOCKED EXPANSION SECTORS (Includes 3 Locked Family Strongholds) ---
	"Adachi": {"name": "TSIM SHA TSUI", "id": &"", "tone": 3, "family": "BLACK TORTOISE SYNDICATE", "center": Vector2.ZERO},
	"Chiba": {"name": "PUDONG CITADEL", "id": &"", "tone": 1, "family": "VERMILION BIRD TRIAD", "center": Vector2.ZERO},
	"Yokosuka": {"name": "LINSEN NORTH", "id": &"", "tone": 3, "family": "BAMBOO UNION CITADEL", "center": Vector2.ZERO},
	"Toshima": {"name": "SENJU", "id": &"", "tone": 3, "family": "", "center": Vector2.ZERO},
	"Nakano": {"name": "YAU MA TEI", "id": &"", "tone": 1, "family": "", "center": Vector2.ZERO},
	"Bunkyo": {"name": "KRETA AYER", "id": &"", "tone": 1, "family": "", "center": Vector2.ZERO},
	"Chiyoda": {"name": "MARUNOUCHI", "id": &"", "tone": 2, "family": "", "center": Vector2(0.355, 0.145)},
	"Chuo": {"name": "TSUKIJI", "id": &"", "tone": 0, "family": "", "center": Vector2(0.382, 0.172)},
	"Shibuya": {"name": "DOGENZAKA", "id": &"", "tone": 2, "family": "", "center": Vector2(0.255, 0.195)},
	"Shinagawa": {"name": "TENNOZU", "id": &"", "tone": 0, "family": "", "center": Vector2(0.295, 0.285)},
	"Taito": {"name": "YOSHIWARA", "id": &"", "tone": 3, "family": "", "center": Vector2.ZERO},
	"Sumida": {"name": "SHAM SHUI PO", "id": &"", "tone": 1, "family": "", "center": Vector2.ZERO},
	"Arakawa": {"name": "SANJA", "id": &"", "tone": 0, "family": "", "center": Vector2.ZERO},
	"Meguro": {"name": "BUGIS", "id": &"", "tone": 1, "family": "", "center": Vector2.ZERO},
	"Kita": {"name": "AKABANE", "id": &"", "tone": 2, "family": "", "center": Vector2.ZERO},
	"Urayasu": {"name": "SENTOSA COVE", "id": &"", "tone": 3, "family": "", "center": Vector2(0.555, 0.205)},
	"Ichikawa": {"name": "GYOTOKU", "id": &"", "tone": 1, "family": "", "center": Vector2.ZERO},
	"Narashino": {"name": "TSUDANUMA", "id": &"", "tone": 0, "family": "", "center": Vector2.ZERO},
	"Ichihara": {"name": "GOI REFINERY", "id": &"", "tone": 3, "family": "", "center": Vector2.ZERO},
	"Sodegaura": {"name": "NAGAURA", "id": &"", "tone": 0, "family": "", "center": Vector2.ZERO},
	"Kisarazu": {"name": "AQUA CROSSING", "id": &"", "tone": 2, "family": "", "center": Vector2.ZERO},
	"Futtsu": {"name": "FUTTSU CAPE", "id": &"", "tone": 3, "family": "", "center": Vector2.ZERO},
	"Kimitsu": {"name": "KIMITSU STEEL", "id": &"", "tone": 1, "family": "", "center": Vector2.ZERO},
	"Miura": {"name": "MISAKI STRAIT", "id": &"", "tone": 0, "family": "", "center": Vector2.ZERO},
}

@onready var _map_viewport: Control = %MapViewport
@onready var _world: Node2D = %World
@onready var _static_layer: Node2D = %StaticLayer
@onready var _dynamic_layer: Node2D = %DynamicLayer
@onready var _label_layer: Control = %LabelLayer
@onready var _margin: MarginContainer = %Margin
@onready var _input_blocker: Control = %InputBlocker
@onready var _district_sheet: DistrictSheet = %DistrictSheet

var _zoom := START_ZOOM
var _center := Vector2(0.36, 0.26)
var _touches := {}
var _tap_start := Vector2.ZERO
var _tap_possible := false
var _mouse_pressed := false
var _fling_velocity := Vector2.ZERO

# World-space (0..3072) cached geometry
var _water_world := PackedVector2Array()
var _wards_world: Dictionary = {}
var _wards_norm: Dictionary = {}
var _ward_centers: Dictionary = {}
var _district_to_ward: Dictionary = {}
var _islands_world: Array[PackedVector2Array] = []
var _rivers_world: Array[PackedVector2Array] = []
var _primary_world: Array[PackedVector2Array] = []
var _trunks_world: Array[PackedVector2Array] = []
var _motorways_world: Array[PackedVector2Array] = []

var _selected_ward: String = ""
var _crate_ends := PackedVector2Array()

# Combined Travel FX state (Highway Artery Pulse + Tactical Radar Lock)
var _anim_active := false
var _anim_progress := 0.0
var _anim_from_ward := ""
var _anim_to_ward := ""
var _anim_world_path := PackedVector2Array()


func _ready() -> void:
	if GameState.run == null:
		SceneRouter.go_to.call_deferred(SceneRouter.TITLE_SCREEN)
		return

	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)
	SafeArea.apply_top_margin(_margin, 64)

	_load_tokyo_data()
	_static_layer.draw.connect(_draw_static_world)
	_dynamic_layer.draw.connect(_draw_dynamic_world)
	_label_layer.draw.connect(_draw_labels)
	resized.connect(_apply_camera)

	_district_sheet.travel_requested.connect(_on_travel_requested)
	_district_sheet.enter_requested.connect(_return_to_district)

	_show_crate_route()

	var curr_ward: String = _district_to_ward.get(GameState.run.district_id, "Minato")
	if _ward_centers.has(curr_ward):
		focus_on(_ward_centers[curr_ward], START_ZOOM)
	else:
		_apply_camera()

	_static_layer.queue_redraw()
	_dynamic_layer.queue_redraw()
	_label_layer.queue_redraw()

	GameState.clock_active = true
	_play_entrance()
	if not GameState.travelling_to.is_empty():
		_start_booked_trip()


func _exit_tree() -> void:
	GameState.clock_active = false


func _norm_pt(raw_pt: Array) -> Vector2:
	return Vector2((float(raw_pt[0]) - VX0) / VSPAN, (float(raw_pt[1]) - VY0) / VSPAN)


func _load_tokyo_data() -> void:
	var path := "res://data/tokyo.json"
	if not FileAccess.file_exists(path):
		return
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return
	var data: Dictionary = parsed

	_water_world.clear()
	for pt: Array in data.get("water", []):
		_water_world.append(_norm_pt(pt) * CANVAS_SIZE)

	_wards_world.clear()
	_wards_norm.clear()
	_ward_centers.clear()
	_district_to_ward.clear()

	var raw_wards: Dictionary = data.get("wards", {})
	for ward_name: String in raw_wards:
		var rings_raw: Array = raw_wards[ward_name]
		var world_rings: Array[PackedVector2Array] = []
		var norm_rings: Array[PackedVector2Array] = []
		var best_ring := PackedVector2Array()
		var best_len := 0
		for r_raw: Array in rings_raw:
			var w_ring := PackedVector2Array()
			var n_ring := PackedVector2Array()
			for pt: Array in r_raw:
				var np := _norm_pt(pt)
				n_ring.append(np)
				w_ring.append(np * CANVAS_SIZE)
			if n_ring.size() >= 3:
				norm_rings.append(n_ring)
				for clean_sub: PackedVector2Array in _clean_polygon(w_ring):
					world_rings.append(clean_sub)
				if n_ring.size() > best_len:
					best_len = n_ring.size()
					best_ring = n_ring
		_wards_norm[ward_name] = norm_rings
		_wards_world[ward_name] = world_rings

		var info: Dictionary = SECTOR_INFO.get(ward_name, {})
		var dist_id: StringName = info.get("id", &"")
		if dist_id != &"":
			_district_to_ward[dist_id] = ward_name

		var override_c: Vector2 = info.get("center", Vector2.ZERO)
		if override_c != Vector2.ZERO:
			_ward_centers[ward_name] = Vector2((override_c.x - VX0) / VSPAN, (override_c.y - VY0) / VSPAN)
		elif best_ring.size() > 0:
			var sum := Vector2.ZERO
			for p: Vector2 in best_ring:
				sum += p
			_ward_centers[ward_name] = sum / float(best_ring.size())

	_islands_world = _parse_world_polygons(data.get("islands", []))
	var raw_rivers: Variant = data.get("rivers", [])
	if raw_rivers is Array:
		_rivers_world = _parse_world_polylines(raw_rivers)
	_primary_world = _parse_world_polylines(data.get("primary", []))
	_trunks_world = _parse_world_polylines(data.get("trunks", []))
	_motorways_world = _parse_world_polylines(data.get("motorways", []))


static func _clean_polygon(raw_poly: PackedVector2Array) -> Array[PackedVector2Array]:
	var pts := PackedVector2Array()
	for p: Vector2 in raw_poly:
		if pts.is_empty() or not pts[-1].is_equal_approx(p):
			pts.append(p)
	if pts.size() > 3 and pts[0].is_equal_approx(pts[-1]):
		pts.remove_at(pts.size() - 1)
	if pts.size() < 3:
		return []
	var ind := Geometry2D.triangulate_polygon(pts)
	if not ind.is_empty():
		return [pts]
	var merged := Geometry2D.merge_polygons(pts, PackedVector2Array())
	var valid: Array[PackedVector2Array] = []
	for sub: PackedVector2Array in merged:
		if sub.size() >= 3 and not Geometry2D.triangulate_polygon(sub).is_empty():
			valid.append(sub)
	if not valid.is_empty():
		return valid
	var convex := Geometry2D.decompose_polygon_in_convex(pts)
	if not convex.is_empty():
		return convex
	var hull := Geometry2D.convex_hull(pts)
	if hull.size() >= 3 and not Geometry2D.triangulate_polygon(hull).is_empty():
		return [hull]
	return []


func _parse_world_polygons(raw_list: Array) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for chain: Array in raw_list:
		var arr := PackedVector2Array()
		for pt: Array in chain:
			arr.append(_norm_pt(pt) * CANVAS_SIZE)
		for cleaned: PackedVector2Array in _clean_polygon(arr):
			result.append(cleaned)
	return result


func _parse_world_polylines(raw_list: Array) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for chain: Array in raw_list:
		var arr := PackedVector2Array()
		for pt: Array in chain:
			arr.append(_norm_pt(pt) * CANVAS_SIZE)
		if arr.size() >= 2:
			result.append(arr)
	return result


## Draws the static Tokyo Bay vector map ONCE in 0..3072 world coordinates.
## Pan and zoom transform the parent _world Node2D on the GPU with zero redraws!
func _draw_static_world() -> void:
	# 1. Outer landmass background (extended well beyond bounds for overscroll)
	_static_layer.draw_rect(Rect2(-2048.0, -2048.0, 7168.0, 7168.0), COLOR_OUTER_LAND, true)

	# 2. All 34 Ward Polygons (4-tone topological slate)
	for ward_name: String in _wards_world:
		var info: Dictionary = SECTOR_INFO.get(ward_name, {})
		var tone_idx: int = int(info.get("tone", 0)) % SLATE_TONES.size()
		var fill_col: Color = SLATE_TONES[tone_idx]
		var rings: Array = _wards_world[ward_name]
		for ring: PackedVector2Array in rings:
			if ring.size() >= 3 and not Geometry2D.triangulate_polygon(ring).is_empty():
				_static_layer.draw_colored_polygon(ring, fill_col)

	# 3. Ward Boundary Seams on Land (Drawn BEFORE Tokyo Bay Ocean so the Bay masks out sea seams in 0 ms!)
	for ward_name: String in _wards_world:
		var info: Dictionary = SECTOR_INFO.get(ward_name, {})
		var is_playable: bool = (info.get("id", &"") != &"")
		var ridge_col: Color = COLOR_SEAM_ACTIVE if is_playable else COLOR_SEAM_LOCKED
		var seam_w: float = 5.5 if is_playable else 3.5
		var rings: Array = _wards_world[ward_name]
		for ring: PackedVector2Array in rings:
			var closed := ring.duplicate()
			closed.append(ring[0])
			_static_layer.draw_polyline(closed, COLOR_SEAM_DARK, seam_w + 5.0)
			_static_layer.draw_polyline(closed, ridge_col, seam_w)

	# 4. Tokyo Bay Ocean Polygon & Coastline Rim (Automatically covers administrative sea-extension borders!)
	if _water_world.size() >= 3:
		_static_layer.draw_colored_polygon(_water_world, COLOR_OCEAN)
		var bay_rim := _water_world.duplicate()
		bay_rim.append(_water_world[0])
		_static_layer.draw_polyline(bay_rim, COLOR_COAST_RIM, 4.5)

	# 5. Reclaimed Harbor Islands (Sits on top of Tokyo Bay)
	for isl: PackedVector2Array in _islands_world:
		if isl.size() >= 3 and not Geometry2D.triangulate_polygon(isl).is_empty():
			_static_layer.draw_colored_polygon(isl, COLOR_ISLAND_LAND)
			var isl_rim := isl.duplicate()
			isl_rim.append(isl[0])
			_static_layer.draw_polyline(isl_rim, COLOR_COAST_RIM, 3.0)

	# 6. Rivers & Canals
	for riv: PackedVector2Array in _rivers_world:
		_static_layer.draw_polyline(riv, COLOR_COAST_RIM, 8.0)
		_static_layer.draw_polyline(riv, COLOR_OCEAN, 5.5)

	# 7. Multi-Level Street & Highway Network
	for way: PackedVector2Array in _primary_world:
		_static_layer.draw_polyline(way, COLOR_PRIM_CASING, 5.5)
		_static_layer.draw_polyline(way, COLOR_PRIM_FILL, 3.0)

	for way: PackedVector2Array in _trunks_world:
		_static_layer.draw_polyline(way, COLOR_TRUNK_CASING, 7.5)
		_static_layer.draw_polyline(way, COLOR_TRUNK_FILL, 4.2)

	for way: PackedVector2Array in _motorways_world:
		_static_layer.draw_polyline(way, COLOR_MWAY_CASING, 10.0)
		_static_layer.draw_polyline(way, COLOR_MWAY_FILL, 6.0)


## Draws only dynamic world-space overlays: selected ward highlight, crate route, and active travel FX.
func _draw_dynamic_world() -> void:
	# 1. Selected Ward Highlight
	if not _selected_ward.is_empty() and _wards_world.has(_selected_ward):
		var rings: Array = _wards_world[_selected_ward]
		for ring: PackedVector2Array in rings:
			if ring.size() >= 3 and not Geometry2D.triangulate_polygon(ring).is_empty():
				_dynamic_layer.draw_colored_polygon(ring, COLOR_SELECTED_FILL)
			var closed := ring.duplicate()
			closed.append(ring[0])
			_dynamic_layer.draw_polyline(closed, COLOR_SELECTED_OUTLINE, 7.0)

	# 2. Active Smuggling Crate Route
	if _crate_ends.size() >= 2:
		for i in range(0, _crate_ends.size() - 1, 2):
			var p0: Vector2 = _crate_ends[i] * CANVAS_SIZE
			var p1: Vector2 = _crate_ends[i + 1] * CANVAS_SIZE
			_dynamic_layer.draw_dashed_line(p0, p1, CRATE_ROUTE_COLOR, 7.0, 22.0)

	# 3. Active Travel Animation FX in World Space
	if _anim_active:
		_draw_travel_fx_world()


func _draw_travel_fx_world() -> void:
	var p := _anim_progress

	# 1. Origin ward flashes and fades out on departure
	if not _anim_from_ward.is_empty() and _wards_world.has(_anim_from_ward):
		var orig_alpha := clampf(1.0 - p * 1.8, 0.0, 1.0) * 0.38
		if orig_alpha > 0.01:
			for ring: PackedVector2Array in _wards_world[_anim_from_ward]:
				_dynamic_layer.draw_colored_polygon(ring, Color(0.42, 0.88, 0.62, orig_alpha))

	# 2. Highway Artery Pulse traces along the real road & bridge network
	if _anim_world_path.size() >= 2:
		var partial := _slice_polyline(_anim_world_path, clampf(p * 1.18, 0.0, 1.0))
		if partial.size() >= 2:
			_dynamic_layer.draw_polyline(partial, Color(0.95, 0.72, 0.25, 0.38), 22.0)
			_dynamic_layer.draw_polyline(partial, COLOR_SELECTED_OUTLINE, 9.0)
			var head := partial[partial.size() - 1]
			_dynamic_layer.draw_circle(head, 16.0, Color(0.96, 0.82, 0.48, 0.45))
			_dynamic_layer.draw_circle(head, 8.0, Palette.TEXT_CREAM)

	# 3. Tactical Radar Crosshair Rings + Destination Territory Border Ignition
	if not _anim_to_ward.is_empty() and _ward_centers.has(_anim_to_ward):
		var target_w: Vector2 = _ward_centers[_anim_to_ward] * CANVAS_SIZE
		var radar_t := clampf((p - 0.15) / 0.85, 0.0, 1.0)
		if radar_t > 0.0:
			var r1 := lerpf(240.0, 34.0, clampf(radar_t * 1.15, 0.0, 1.0))
			var r2 := lerpf(360.0, 70.0, clampf(radar_t * 1.05, 0.0, 1.0))
			_dynamic_layer.draw_arc(target_w, r1, 0.0, TAU, 48, COLOR_SELECTED_OUTLINE, 6.0)
			_dynamic_layer.draw_arc(target_w, r2, 0.0, TAU, 48, Color(0.96, 0.82, 0.48, 0.45), 4.0)
			var ch := r1 + 24.0
			_dynamic_layer.draw_line(target_w + Vector2(-ch, 0), target_w + Vector2(-r1 * 0.4, 0), COLOR_SELECTED_OUTLINE, 5.0)
			_dynamic_layer.draw_line(target_w + Vector2(r1 * 0.4, 0), target_w + Vector2(ch, 0), COLOR_SELECTED_OUTLINE, 5.0)
			_dynamic_layer.draw_line(target_w + Vector2(0, -ch), target_w + Vector2(0, -r1 * 0.4), COLOR_SELECTED_OUTLINE, 5.0)
			_dynamic_layer.draw_line(target_w + Vector2(0, r1 * 0.4), target_w + Vector2(0, ch), COLOR_SELECTED_OUTLINE, 5.0)

		if p > 0.50 and _wards_world.has(_anim_to_ward):
			var lock_t := (p - 0.50) / 0.50
			var pulse := sin(lock_t * PI)
			for ring: PackedVector2Array in _wards_world[_anim_to_ward]:
				_dynamic_layer.draw_colored_polygon(ring, Color(0.96, 0.78, 0.35, 0.44 * pulse))
				var closed := ring.duplicate()
				closed.append(ring[0])
				_dynamic_layer.draw_polyline(closed, Color(1.0, 0.90, 0.60, 0.95), 10.0)


## Draws crisp screen-space sector labels, current location badge, turf status, and family rings.
func _draw_labels() -> void:
	var drawn := _drawn_size()
	if drawn.x <= 0.0 or drawn.y <= 0.0:
		return
	var offset := _map_offset()
	var font: Font = get_theme_default_font()
	var curr_dist_id: StringName = GameState.run.district_id if GameState.run != null else &""

	for ward_name: String in _ward_centers:
		var center_norm: Vector2 = _ward_centers[ward_name]
		var info: Dictionary = SECTOR_INFO.get(ward_name, {})
		var dist_id: StringName = info.get("id", &"")
		var is_playable: bool = (dist_id != &"")
		var has_family: bool = not String(info.get("family", "")).is_empty()
		var is_sel: bool = (ward_name == _selected_ward)
		var is_current: bool = (is_playable and dist_id == curr_dist_id)

		# At default zoom, show all 10 Playable Sectors + 3 Locked Family Strongholds (13 well-spaced labels).
		# As user zooms in, reveal the remaining 21 locked urban buffer sectors!
		if not is_playable and not has_family and not is_sel and _zoom < 1.45:
			continue

		var screen_pos: Vector2 = offset + center_norm * drawn
		var label_text: String = info.get("name", ward_name.to_upper())
		var font_size: int = 14 if (is_sel or is_current or has_family) else (12 if is_playable else 11)
		var text_size: Vector2 = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)

		if is_current:
			_label_layer.draw_circle(screen_pos + Vector2(0, -text_size.y - 9), 7.0, COLOR_CURRENT_RING)
			_label_layer.draw_circle(screen_pos + Vector2(0, -text_size.y - 9), 3.0, COLOR_OCEAN)
		elif has_family:
			_label_layer.draw_circle(screen_pos + Vector2(0, -text_size.y - 8), 6.0, COLOR_FAMILY_RING)
			_label_layer.draw_circle(screen_pos + Vector2(0, -text_size.y - 8), 2.5, COLOR_OCEAN)

		var pad_x := 8.0
		var pad_y := 4.0
		var pill := Rect2(
			screen_pos.x - text_size.x / 2.0 - pad_x,
			screen_pos.y - text_size.y + 2.0 - pad_y,
			text_size.x + pad_x * 2.0,
			text_size.y + pad_y * 2.0
		)
		var bg_alpha := 0.92 if (is_playable or is_sel) else 0.72
		_label_layer.draw_rect(pill, Color(0.05, 0.07, 0.10, bg_alpha), true)

		var border_col := COLOR_CURRENT_RING if is_current else (
			COLOR_SELECTED_OUTLINE if is_sel else (
				COLOR_FAMILY_RING if has_family else (
					COLOR_SEAM_ACTIVE if is_playable else COLOR_SEAM_LOCKED
				)
			)
		)
		_label_layer.draw_rect(pill, border_col, false, 2.0 if (is_current or is_sel or has_family) else 1.0)

		var txt_col: Color = Palette.TEXT_CREAM if (is_playable or is_sel or has_family) else Palette.TEXT_MUTED
		_label_layer.draw_string(
			font,
			Vector2(screen_pos.x - text_size.x / 2.0, screen_pos.y),
			label_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			font_size,
			txt_col
		)


## Builds the smuggling crate route between ward centers when carrying a crate.
func _show_crate_route() -> void:
	_crate_ends.clear()
	var run := GameState.run
	if run != null and Smuggling.is_carrying(run):
		var route: Array = run.crate.get("route", [])
		var from_id: StringName = run.district_id
		for index in range(int(run.crate.get("stop", 0)), route.size()):
			var stop_id := StringName(str(route[index]))
			var w_from: String = _district_to_ward.get(from_id, "")
			var w_to: String = _district_to_ward.get(stop_id, "")
			if not w_from.is_empty() and not w_to.is_empty() and _ward_centers.has(w_from) and _ward_centers.has(w_to):
				_crate_ends.append(_ward_centers[w_from])
				_crate_ends.append(_ward_centers[w_to])
			from_id = stop_id
	_dynamic_layer.queue_redraw()


func can_present_encounter() -> bool:
	return not _input_blocker.visible


func handle_back() -> bool:
	if _input_blocker.visible:
		return true
	if _district_sheet.visible:
		_district_sheet.close()
		return true
	_return_to_district()
	return true


func _on_district_selected(district: DistrictDef) -> void:
	var w_name: String = _district_to_ward.get(district.id, "")
	if not w_name.is_empty():
		_selected_ward = w_name
		_dynamic_layer.queue_redraw()
		_label_layer.queue_redraw()
	_district_sheet.show_district(district, Travel.check(GameState.run, district))


func _start_booked_trip() -> void:
	var destination := Content.district(GameState.travelling_to)
	GameState.travelling_to = &""
	if destination == null:
		return
	_input_blocker.show()
	await get_tree().create_timer(BOOKED_TRIP_DELAY_SECONDS).timeout
	if Travel.check(GameState.run, destination) != Travel.Check.OK:
		_input_blocker.hide()
		_on_district_selected(destination)
		return
	_on_travel_requested(destination)


func _on_travel_requested(destination: DistrictDef, walking := false) -> void:
	if Roadblocks.stops_crate(GameState.run, destination):
		_input_blocker.hide()
		_district_sheet.close()
		RoadblockTalk.open(destination, _travel, _wait_out_roadblock)
		return
	_travel(destination, false, walking)


func _travel(destination: DistrictDef, through_roadblock: bool, walking := false) -> void:
	var origin := GameState.current_district()
	var result := GameState.push_through_roadblock(destination) if through_roadblock \
		else GameState.travel_to(destination, walking)
	if result != Travel.Check.OK:
		_input_blocker.hide()
		_on_district_selected(destination)
		return
	GameState.clock_active = false
	_input_blocker.show()
	_district_sheet.close()

	var from_ward: String = _district_to_ward.get(origin.id, "Minato")
	var to_ward: String = _district_to_ward.get(destination.id, "Shinjuku")
	await _run_vector_travel_animation(from_ward, to_ward)
	SceneRouter.go_to(SceneRouter.DISTRICT_SCREEN)


func _run_vector_travel_animation(from_ward: String, to_ward: String) -> void:
	var c_from: Vector2 = _ward_centers.get(from_ward, _center)
	var c_to: Vector2 = _ward_centers.get(to_ward, _center)
	_anim_from_ward = from_ward
	_anim_to_ward = to_ward
	_anim_world_path = _build_travel_path_world(c_from * CANVAS_SIZE, c_to * CANVAS_SIZE)
	_anim_active = true
	_anim_progress = 0.0

	var mid := (c_from + c_to) / 2.0
	var span := c_from.distance_to(c_to)
	var overview_zoom := clampf(0.75 / maxf(span, 0.22), MIN_ZOOM, 1.35)
	await glide_to(mid, overview_zoom, CAMERA_GLIDE_SECONDS).finished

	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(func(t: float) -> void:
		_anim_progress = t
		focus_on(mid.lerp(c_to, t * 0.55), lerpf(overview_zoom, maxf(overview_zoom, 1.35), t))
		_dynamic_layer.queue_redraw()
	, 0.0, 1.0, ROUTE_SECONDS)
	await tween.finished

	_anim_active = false
	_dynamic_layer.queue_redraw()


func _build_travel_path_world(w_from: Vector2, w_to: Vector2) -> PackedVector2Array:
	var path := PackedVector2Array()
	path.append(w_from)
	var steps := 6
	for s in range(1, steps):
		var t := float(s) / float(steps)
		var ideal := w_from.lerp(w_to, t)
		var snapped := _nearest_highway_point(ideal, 260.0)
		path.append(snapped)
	path.append(w_to)
	return path


func _nearest_highway_point(target: Vector2, max_dist: float) -> Vector2:
	var best_pt := target
	var best_d2 := max_dist * max_dist
	for way: PackedVector2Array in _motorways_world:
		for pt: Vector2 in way:
			var d2 := target.distance_squared_to(pt)
			if d2 < best_d2:
				best_d2 = d2
				best_pt = pt
	for way: PackedVector2Array in _trunks_world:
		for pt: Vector2 in way:
			var d2 := target.distance_squared_to(pt)
			if d2 < best_d2:
				best_d2 = d2
				best_pt = pt
	return best_pt


func _slice_polyline(points: PackedVector2Array, progress: float) -> PackedVector2Array:
	if points.size() < 2 or progress <= 0.0:
		return PackedVector2Array()
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	var remaining := total * clampf(progress, 0.0, 1.0)
	var out := PackedVector2Array([points[0]])
	for i in range(1, points.size()):
		var seg := points[i - 1].distance_to(points[i])
		if remaining < seg and seg > 0.0:
			out.append(points[i - 1].lerp(points[i], remaining / seg))
			break
		remaining -= seg
		out.append(points[i])
	return out


func _wait_out_roadblock(destination: DistrictDef) -> void:
	var run := GameState.run
	var start := Calendar.stamp(run)
	_input_blocker.show()
	var open := GameState.wait_out_roadblock(destination.id)
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	for stamp in range(start + 1, Calendar.stamp(run) + 1):
		tween.tween_property(_map_viewport, "modulate", LAPSE_DIM, LAPSE_PHASE_SECONDS / 2.0)
		tween.tween_property(_map_viewport, "modulate", Color.WHITE, LAPSE_PHASE_SECONDS / 2.0)
	tween.tween_interval(0.0)
	await tween.finished
	_input_blocker.hide()
	if open and not Encounters.has_pending(run):
		_travel(destination, false)


func _return_to_district() -> void:
	SceneRouter.go_to(SceneRouter.DISTRICT_SCREEN)


func _play_entrance() -> void:
	_map_viewport.modulate.a = 0.0
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_map_viewport, "modulate:a", 1.0, 0.45)


func _on_tap(point: Vector2) -> void:
	var drawn := _drawn_size()
	if drawn.x <= 0.0 or drawn.y <= 0.0:
		return
	var offset := _map_offset()
	var norm_pos := (point - offset) / drawn

	var tapped_ward: String = ""
	# First check if user tapped directly on or near a sector label center
	var best_label_dist := 44.0
	for ward_name: String in _ward_centers:
		var info: Dictionary = SECTOR_INFO.get(ward_name, {})
		var is_playable: bool = (info.get("id", &"") != &"")
		var has_family: bool = not String(info.get("family", "")).is_empty()
		if not is_playable and not has_family and _zoom < 1.45:
			continue
		var s_pos: Vector2 = offset + _ward_centers[ward_name] * drawn
		var d := point.distance_to(s_pos)
		if d < best_label_dist:
			best_label_dist = d
			tapped_ward = ward_name

	# Otherwise check polygon containment
	if tapped_ward.is_empty():
		for ward_name: String in _wards_norm:
			var rings: Array = _wards_norm[ward_name]
			for ring: PackedVector2Array in rings:
				if Geometry2D.is_point_in_polygon(norm_pos, ring):
					tapped_ward = ward_name
					break
			if not tapped_ward.is_empty():
				break

	if tapped_ward.is_empty():
		_selected_ward = ""
		_district_sheet.close()
		_dynamic_layer.queue_redraw()
		_label_layer.queue_redraw()
		return

	_selected_ward = tapped_ward
	_dynamic_layer.queue_redraw()
	_label_layer.queue_redraw()

	if _ward_centers.has(tapped_ward):
		glide_to(_ward_centers[tapped_ward], maxf(_zoom, 1.35), 0.28)

	var info: Dictionary = SECTOR_INFO.get(tapped_ward, {})
	var dist_id: StringName = info.get("id", &"")
	var pan_name: String = info.get("name", tapped_ward.to_upper())
	var family_name: String = info.get("family", "")

	if dist_id != &"":
		var district := Content.district(dist_id)
		if district != null:
			_district_sheet.show_district(district, Travel.check(GameState.run, district))
			return

	var tagline := (family_name + "Uncharted Syndicate Stronghold") if not family_name.is_empty() \
		else "Restricted Underworld Sector"
	_district_sheet.show_locked_sector(pan_name, tagline)


func focus_on(normalized: Vector2, zoom: float) -> void:
	_center = normalized
	_zoom = clampf(zoom, MIN_ZOOM, MAX_ZOOM)
	_apply_camera()


func glide_to(normalized: Vector2, zoom: float, seconds: float) -> Tween:
	_fling_velocity = Vector2.ZERO
	set_process(false)
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var start_c := _center
	var start_z := _zoom
	tween.tween_method(func(t: float) -> void:
		focus_on(start_c.lerp(normalized, t), lerpf(start_z, zoom, t))
	, 0.0, 1.0, seconds)
	return tween


func _process(delta: float) -> void:
	_pan(_fling_velocity * delta)
	_fling_velocity *= exp(-FLING_FRICTION * delta)
	if _fling_velocity.length() < MIN_FLING_SPEED:
		_fling_velocity = Vector2.ZERO
		set_process(false)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			_fling_velocity = Vector2.ZERO
			set_process(false)
			_tap_possible = (_touches.size() == 1)
			_tap_start = event.position
		else:
			_touches.erase(event.index)
			if _tap_possible and event.position.distance_to(_tap_start) <= TAP_SLOP:
				_on_tap(event.position)
			elif _touches.is_empty() and _fling_velocity.length() >= MIN_FLING_SPEED:
				set_process(true)
			_tap_possible = false
		accept_event()
	elif event is InputEventScreenDrag:
		var previous: Vector2 = _touches.get(event.index, event.position - event.relative)
		_touches[event.index] = event.position
		if _tap_possible and event.position.distance_to(_tap_start) <= TAP_SLOP:
			accept_event()
			return
		_tap_possible = false
		if _touches.size() == 1:
			_pan(event.relative)
			_fling_velocity = event.velocity
		elif _touches.size() >= 2:
			var other := _other_touch(event.index)
			var prev_dist := previous.distance_to(other)
			if prev_dist > 0.0:
				_zoom_at((event.position + other) / 2.0, event.position.distance_to(other) / prev_dist)
			_pan(event.relative / 2.0)
			_fling_velocity = Vector2.ZERO
		accept_event()
	elif event is InputEventMagnifyGesture:
		_zoom_at(event.position, event.factor)
		accept_event()
	elif event is InputEventPanGesture:
		_pan(-event.delta * PAN_GESTURE_SPEED)
		accept_event()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_tap_start = event.position
				_mouse_pressed = true
				_tap_possible = true
				_fling_velocity = Vector2.ZERO
				set_process(false)
			else:
				if _mouse_pressed and _tap_possible and event.position.distance_to(_tap_start) <= TAP_SLOP:
					_on_tap(event.position)
				_mouse_pressed = false
				_tap_possible = false
			accept_event()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(event.position, WHEEL_ZOOM_STEP)
			accept_event()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(event.position, 1.0 / WHEEL_ZOOM_STEP)
			accept_event()
	elif event is InputEventMouseMotion and _mouse_pressed:
		if _tap_possible and event.position.distance_to(_tap_start) > TAP_SLOP:
			_tap_possible = false
		if not _tap_possible:
			_pan(event.relative)
		accept_event()


func _other_touch(index: int) -> Vector2:
	for touch_index: int in _touches:
		if touch_index != index:
			return _touches[touch_index]
	return _touches[index]


func _pan(view_delta: Vector2) -> void:
	var drawn := _drawn_size()
	if drawn.x <= 0.0 or drawn.y <= 0.0:
		return
	_center -= view_delta / drawn
	_apply_camera()


func _zoom_at(view_point: Vector2, factor: float) -> void:
	var old_drawn := _drawn_size()
	if old_drawn.x <= 0.0 or old_drawn.y <= 0.0:
		return
	var anchor := (view_point - _map_offset()) / old_drawn
	_zoom = clampf(_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	var new_drawn := _drawn_size()
	var view_size := _view_size()
	_center = (view_size / 2.0 - view_point) / new_drawn + anchor
	_apply_camera()


## Updates the GPU Node2D transform of _world without re-triangulating or redrawing static map geometry!
func _apply_camera() -> void:
	if not is_node_ready():
		return
	var view_size := _view_size()
	var drawn := _drawn_size()
	if view_size.x <= 0.0 or view_size.y <= 0.0 or drawn.x <= 0.0 or drawn.y <= 0.0:
		return
	var half_view := view_size / 2.0 / drawn
	_center.x = 0.5 if half_view.x >= 0.5 else clampf(_center.x, half_view.x, 1.0 - half_view.x)
	_center.y = 0.5 if half_view.y >= 0.5 else clampf(_center.y, half_view.y, 1.0 - half_view.y)

	_world.position = _map_offset()
	_world.scale = drawn / CANVAS_SIZE
	_label_layer.queue_redraw()


func _view_size() -> Vector2:
	return size if size != Vector2.ZERO else get_viewport_rect().size


func _drawn_size() -> Vector2:
	var v := _view_size()
	return CANVAS_SIZE * maxf(v.x / CANVAS_SIZE.x, v.y / CANVAS_SIZE.y) * _zoom


func _map_offset() -> Vector2:
	return _view_size() / 2.0 - _center * _drawn_size()
