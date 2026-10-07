extends Control

const MAP_PIN := preload("res://ui/components/map_pin.tscn")
const ROUTE_SECONDS := 1.1
const ROUTE_SAMPLES := 32
const ROUTE_BEND := 0.22
const CAMERA_GLIDE_SECONDS := 0.4

@onready var _city_view: CityView = %CityView
@onready var _route: Line2D = %Route
@onready var _traveller: Control = %Traveller
@onready var _margin: MarginContainer = %Margin
@onready var _input_blocker: Control = %InputBlocker
@onready var _district_sheet: DistrictSheet = %DistrictSheet

var _pins: Array[MapPin] = []


func _ready() -> void:
	if GameState.run == null:
		SceneRouter.go_to.call_deferred(SceneRouter.TITLE_SCREEN)
		return

	SafeArea.apply_top_margin(_margin, 40)
	for district in Content.districts():
		var pin: MapPin = MAP_PIN.instantiate()
		pin.district = district
		pin.is_current = district.id == GameState.run.district_id
		pin.holder = Turf.holder(GameState.run, district.id)
		_city_view.add_pin(pin)
		_pins.append(pin)
	_city_view.focus_on(GameState.current_district().map_position, CityView.START_ZOOM)
	_city_view.district_tapped.connect(_on_district_selected)

	_district_sheet.travel_requested.connect(_on_travel_requested)
	_district_sheet.enter_requested.connect(_return_to_district)
	GameState.clock_active = true
	_play_entrance()


func _exit_tree() -> void:
	GameState.clock_active = false


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


func _on_travel_requested(destination: DistrictDef) -> void:
	var origin := GameState.current_district().map_position
	if GameState.travel_to(destination) != Travel.Check.OK:
		return
	GameState.clock_active = false
	_input_blocker.show()
	_district_sheet.close()
	await _city_view.glide_to((origin + destination.map_position) / 2.0, CityView.MIN_ZOOM, CAMERA_GLIDE_SECONDS).finished
	await _animate_route(_city_view.map_to_view(origin), _city_view.map_to_view(destination.map_position))
	SceneRouter.go_to(SceneRouter.DISTRICT_SCREEN)


func _animate_route(from: Vector2, to: Vector2) -> void:
	var bend_point := (from + to) / 2.0 + (to - from).orthogonal() * ROUTE_BEND
	_route.clear_points()
	_traveller.show()
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(_draw_route.bind(from, bend_point, to), 0.0, 1.0, ROUTE_SECONDS)
	await tween.finished


func _draw_route(progress: float, from: Vector2, bend_point: Vector2, to: Vector2) -> void:
	var points := PackedVector2Array()
	var steps := maxi(1, ceili(ROUTE_SAMPLES * progress))
	for step in steps + 1:
		var t := progress * step / steps
		points.append(from.lerp(bend_point, t).lerp(bend_point.lerp(to, t), t))
	_route.points = points
	_traveller.position = points[points.size() - 1] - _traveller.size / 2.0


func _return_to_district() -> void:
	SceneRouter.go_to(SceneRouter.DISTRICT_SCREEN)


func _play_entrance() -> void:
	_city_view.modulate.a = 0.0
	for pin in _pins:
		pin.modulate.a = 0.0
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_city_view, "modulate:a", 1.0, 0.5)
	for index in _pins.size():
		tween.tween_property(_pins[index], "modulate:a", 1.0, 0.3).set_delay(0.3 + index * 0.06)
