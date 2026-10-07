class_name CityView
extends Control

signal district_tapped(district: DistrictDef)

const MIN_ZOOM := 1.0
const MAX_ZOOM := 2.0
const START_ZOOM := 1.4
const WHEEL_ZOOM_STEP := 1.1
const PAN_GESTURE_SPEED := 8.0
const TAP_SLOP := 18.0
const FLING_FRICTION := 5.0
const MIN_FLING_SPEED := 20.0

@export var map_texture: Texture2D

@onready var _map_image: TextureRect = %MapImage
@onready var _pin_layer: Control = %PinLayer

var _pins: Array[MapPin] = []
var _zoom := START_ZOOM
## Normalized map point shown at the middle of the view.
var _center := Vector2(0.5, 0.5)
var _touches := {}
var _tap_start := Vector2.ZERO
var _tap_possible := false
var _fling_velocity := Vector2.ZERO


func _ready() -> void:
	_map_image.texture = map_texture
	resized.connect(_apply_camera)
	set_process(false)
	_apply_camera()


func add_pin(pin: MapPin) -> void:
	pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pin_layer.add_child(pin)
	_pins.append(pin)
	_place_pin(pin)


func focus_on(normalized: Vector2, zoom: float) -> void:
	_center = normalized
	_zoom = clampf(zoom, MIN_ZOOM, MAX_ZOOM)
	_apply_camera()


func glide_to(normalized: Vector2, zoom: float, seconds: float) -> Tween:
	_fling_velocity = Vector2.ZERO
	set_process(false)
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(_glide_step.bind(_center, _zoom, normalized, zoom), 0.0, 1.0, seconds)
	return tween


func map_to_view(normalized: Vector2) -> Vector2:
	return _map_offset() + normalized * _drawn_size()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)
	elif event is InputEventMagnifyGesture:
		_zoom_at(event.position, event.factor)
	elif event is InputEventPanGesture:
		_pan(-event.delta * PAN_GESTURE_SPEED)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_zoom_at(event.position, WHEEL_ZOOM_STEP)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_zoom_at(event.position, 1.0 / WHEEL_ZOOM_STEP)
	else:
		return
	accept_event()


func _process(delta: float) -> void:
	_pan(_fling_velocity * delta)
	_fling_velocity *= exp(-FLING_FRICTION * delta)
	if _fling_velocity.length() < MIN_FLING_SPEED:
		_fling_velocity = Vector2.ZERO
		set_process(false)


func _on_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touches[event.index] = event.position
		_fling_velocity = Vector2.ZERO
		set_process(false)
		_tap_possible = _touches.size() == 1
		_tap_start = event.position
		return
	_touches.erase(event.index)
	if _tap_possible:
		_tap(event.position)
	elif _touches.is_empty() and _fling_velocity.length() >= MIN_FLING_SPEED:
		set_process(true)
	_tap_possible = false


func _on_drag(event: InputEventScreenDrag) -> void:
	var previous: Vector2 = _touches.get(event.index, event.position - event.relative)
	_touches[event.index] = event.position
	if _tap_possible and event.position.distance_to(_tap_start) <= TAP_SLOP:
		return
	_tap_possible = false
	if _touches.size() == 1:
		_pan(event.relative)
		_fling_velocity = event.velocity
		return
	var other := _other_touch(event.index)
	var previous_distance := previous.distance_to(other)
	if previous_distance > 0.0:
		_zoom_at((event.position + other) / 2.0, event.position.distance_to(other) / previous_distance)
	_pan(event.relative / 2.0)
	_fling_velocity = Vector2.ZERO


func _other_touch(index: int) -> Vector2:
	for touch_index: int in _touches:
		if touch_index != index:
			return _touches[touch_index]
	return _touches[index]


func _tap(point: Vector2) -> void:
	var closest: MapPin = null
	var closest_distance := INF
	for pin in _pins:
		if not pin.get_rect().has_point(point):
			continue
		var distance := point.distance_to(pin.position + MapPin.MARKER_CENTER)
		if distance < closest_distance:
			closest = pin
			closest_distance = distance
	if closest != null:
		closest.tap()
		district_tapped.emit(closest.district)


func _glide_step(progress: float, from_center: Vector2, from_zoom: float, to_center: Vector2, to_zoom: float) -> void:
	focus_on(from_center.lerp(to_center, progress), lerpf(from_zoom, to_zoom, progress))


func _pan(view_delta: Vector2) -> void:
	_center -= view_delta / _drawn_size()
	_apply_camera()


func _zoom_at(view_point: Vector2, factor: float) -> void:
	var anchor := (view_point - _map_offset()) / _drawn_size()
	_zoom = clampf(_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	var drawn := _drawn_size()
	_center = (size / 2.0 - view_point) / drawn + anchor
	_apply_camera()


func _apply_camera() -> void:
	if map_texture == null or not is_node_ready() or size.x <= 0.0 or size.y <= 0.0:
		return
	var drawn := _drawn_size()
	var half_view := size / 2.0 / drawn
	_center = Vector2(_clamp_axis(_center.x, half_view.x), _clamp_axis(_center.y, half_view.y))
	_map_image.position = _map_offset()
	_map_image.size = drawn
	for pin in _pins:
		_place_pin(pin)


func _place_pin(pin: MapPin) -> void:
	pin.place_at(map_to_view(pin.district.map_position))


func _drawn_size() -> Vector2:
	var texture_size := map_texture.get_size()
	return texture_size * maxf(size.x / texture_size.x, size.y / texture_size.y) * _zoom


func _map_offset() -> Vector2:
	return size / 2.0 - _center * _drawn_size()


static func _clamp_axis(value: float, half_view: float) -> float:
	if half_view >= 0.5:
		return 0.5
	return clampf(value, half_view, 1.0 - half_view)
