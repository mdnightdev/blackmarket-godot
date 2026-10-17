extends Control

const MAP_PIN := preload("res://ui/components/map_pin.tscn")
const ROUTE_SECONDS := 1.1
const CAMERA_GLIDE_SECONDS := 0.4
const LOCKED_PIN_ALPHA := 0.45
const BOOKED_TRIP_DELAY_SECONDS := 0.7
const LAPSE_PHASE_SECONDS := 0.6
const LAPSE_DIM := Color(0.45, 0.42, 0.5)
const CRATE_ROUTE_COLOR := Color(Palette.PEACH, 0.55)

@onready var _city_view: CityView = %CityView
@onready var _route: Line2D = %Route
@onready var _traveller: Control = %Traveller
@onready var _margin: MarginContainer = %Margin
@onready var _input_blocker: Control = %InputBlocker
@onready var _district_sheet: DistrictSheet = %DistrictSheet
@onready var _location_label: Label = %LocationLabel

var _pins: Array[MapPin] = []


func _ready() -> void:
	if GameState.run == null:
		SceneRouter.go_to.call_deferred(SceneRouter.TITLE_SCREEN)
		return

	SafeArea.apply_top_margin(_margin, 64)
	for district in Content.districts():
		var pin: MapPin = MAP_PIN.instantiate()
		pin.district = district
		pin.is_current = district.id == GameState.run.district_id
		pin.holder = Turf.holder(GameState.run, district.id)
		_city_view.add_pin(pin)
		_pins.append(pin)
	_show_crate_route()
	_location_label.text = "You are in %s" % GameState.current_district().display_name
	_city_view.focus_on(GameState.current_district().map_position, CityView.START_ZOOM)
	_city_view.district_tapped.connect(_on_district_selected)

	_district_sheet.travel_requested.connect(_on_travel_requested)
	_district_sheet.enter_requested.connect(_return_to_district)
	GameState.clock_active = true
	_play_entrance()
	if not GameState.travelling_to.is_empty():
		_start_booked_trip()


func _exit_tree() -> void:
	GameState.clock_active = false


## Only a crate run follows the roads, so the map draws the stops still ahead of the crate and nothing else.
func _show_crate_route() -> void:
	var run := GameState.run
	var ends := PackedVector2Array()
	var colors := PackedColorArray()
	if Smuggling.is_carrying(run):
		var route: Array = run.crate.get("route", [])
		var from := GameState.current_district()
		for index in range(int(run.crate.get("stop", 0)), route.size()):
			var stop := Content.district(StringName(str(route[index])))
			if stop == null:
				break
			ends.append(from.map_position)
			ends.append(stop.map_position)
			colors.append(CRATE_ROUTE_COLOR)
			from = stop
	_city_view.set_roads(ends, colors)


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
	_district_sheet.show_district(district, Travel.check(GameState.run, district))


## A trip booked from another screen waits for the map to fade in. If it can no longer go ahead,
## the district sheet shows the reason instead.
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
	var middle := (origin.map_position + destination.map_position) / 2.0
	await _city_view.glide_to(middle, CityView.MIN_ZOOM, CAMERA_GLIDE_SECONDS).finished
	await _animate_route(PackedVector2Array([_city_view.map_to_view(origin.map_position), _city_view.map_to_view(destination.map_position)]))
	SceneRouter.go_to(SceneRouter.DISTRICT_SCREEN)


## Passes the time until the roadblock lifts while the map dims and brightens once for every phase.
func _wait_out_roadblock(destination: DistrictDef) -> void:
	var run := GameState.run
	var start := Calendar.stamp(run)
	_input_blocker.show()
	var open := GameState.wait_out_roadblock(destination.id)
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	for stamp in range(start + 1, Calendar.stamp(run) + 1):
		tween.tween_callback(_location_label.set_text.bind("Lying low. %s" % Calendar.describe(stamp)))
		tween.tween_property(_city_view, "modulate", LAPSE_DIM, LAPSE_PHASE_SECONDS / 2.0)
		tween.tween_property(_city_view, "modulate", Color.WHITE, LAPSE_PHASE_SECONDS / 2.0)
	tween.tween_interval(0.0)
	await tween.finished
	_location_label.text = "You are in %s" % GameState.current_district().display_name
	_input_blocker.hide()
	if open and not Encounters.has_pending(run):
		_travel(destination, false)


func _animate_route(points: PackedVector2Array) -> void:
	var length := 0.0
	for index in range(1, points.size()):
		length += points[index - 1].distance_to(points[index])
	_route.clear_points()
	_traveller.show()
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(_draw_route.bind(points, length), 0.0, 1.0, ROUTE_SECONDS)
	await tween.finished


func _draw_route(progress: float, points: PackedVector2Array, length: float) -> void:
	var remaining := length * progress
	var drawn := PackedVector2Array([points[0]])
	for index in range(1, points.size()):
		var leg := points[index - 1].distance_to(points[index])
		if remaining < leg:
			drawn.append(points[index - 1].lerp(points[index], remaining / leg))
			break
		remaining -= leg
		drawn.append(points[index])
	_route.points = drawn
	_traveller.position = drawn[drawn.size() - 1] - _traveller.size / 2.0


func _return_to_district() -> void:
	SceneRouter.go_to(SceneRouter.DISTRICT_SCREEN)


func _play_entrance() -> void:
	_city_view.modulate.a = 0.0
	for pin in _pins:
		pin.modulate.a = 0.0
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_city_view, "modulate:a", 1.0, 0.5)
	for index in _pins.size():
		var pin := _pins[index]
		var alpha := LOCKED_PIN_ALPHA if not pin.is_current and Travel.is_locked(GameState.run, pin.district) else 1.0
		tween.tween_property(pin, "modulate:a", alpha, 0.3).set_delay(0.3 + index * 0.06)
