class_name CornerMap
extends Control

## The pins over a district's corner map. The screen draws the map itself, stretched to cover, so the pins follow the
## same cover fit and stay on their corners at any screen size.

signal corner_tapped(corner: CornerDef, people: Array[SpeakerDef])

const CORNER_PIN := preload("res://ui/components/corner_pin.tscn")

var _map_size := Vector2.ZERO
var _pins: Array[CornerPin] = []


func _ready() -> void:
	resized.connect(_place_pins)


func show_corners(run: RunState, district: DistrictDef) -> void:
	for pin in _pins:
		pin.queue_free()
	_pins.clear()
	_map_size = district.corner_map.get_size()
	var people := Corners.people_at(run, district.id)
	for corner in district.corners:
		var pin: CornerPin = CORNER_PIN.instantiate()
		pin.corner = corner
		pin.holder_color = holder_color(run, district.id, corner)
		pin.people.assign(people.get(corner.id, []))
		pin.pressed.connect(func() -> void: corner_tapped.emit(corner, pin.people))
		add_child(pin)
		_pins.append(pin)
	_place_pins()


static func holder_color(run: RunState, district_id: StringName, corner: CornerDef) -> Color:
	if Corners.holds(run, corner.id):
		return TurfBar.PLAYER_COLOR
	if not Turf.is_contested(district_id):
		return TurfBar.OPEN_COLOR
	var gang := Corners.gang_of(corner.id)
	return gang.color if gang != null else TurfBar.OPEN_COLOR


func _place_pins() -> void:
	if _map_size == Vector2.ZERO:
		return
	var drawn := _map_size * maxf(size.x / _map_size.x, size.y / _map_size.y)
	var origin := (size - drawn) / 2.0
	for pin in _pins:
		pin.place_at(origin + pin.corner.map_position * drawn)
