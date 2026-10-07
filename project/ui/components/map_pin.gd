class_name MapPin
extends GameButton

signal district_selected(district: DistrictDef)

const MARKER_CENTER := Vector2(100, 34)
const PULSE_SECONDS := 1.4

var district: DistrictDef
var is_current := false

@onready var _ring: Panel = %Ring
@onready var _name_label: Label = %NameLabel


func _ready() -> void:
	super()
	_name_label.text = district.display_name
	pressed.connect(func() -> void: district_selected.emit(district))
	_ring.visible = is_current
	if is_current:
		_pulse_ring()


func place_at(map_point: Vector2) -> void:
	position = map_point - MARKER_CENTER


func _pulse_ring() -> void:
	_ring.pivot_offset = _ring.size / 2.0
	var tween := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_ring, "scale", Vector2(2.6, 2.6), PULSE_SECONDS).from(Vector2.ONE)
	tween.parallel().tween_property(_ring, "modulate:a", 0.0, PULSE_SECONDS).from(0.9)
