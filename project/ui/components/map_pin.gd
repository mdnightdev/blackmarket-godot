class_name MapPin
extends GameButton

const MARKER_CENTER := Vector2(100, 34)
const PULSE_SECONDS := 1.4
const HOLDER_COLORS := {
	Turf.Holder.NOBODY: Palette.TEXT_MUTED,
	Turf.Holder.PLAYER: TurfBar.PLAYER_COLOR,
	Turf.Holder.VEX: TurfBar.VEX_COLOR,
}

var district: DistrictDef
var is_current := false
var holder := Turf.Holder.NOBODY

@onready var _ring: Panel = %Ring
@onready var _marker: Panel = %Marker
@onready var _name_label: Label = %NameLabel


func _ready() -> void:
	super()
	_name_label.text = district.display_name
	_tint_marker(HOLDER_COLORS[holder])
	_ring.visible = is_current
	if is_current:
		_pulse_ring()


func place_at(map_point: Vector2) -> void:
	position = map_point - MARKER_CENTER


## Pins never take touches themselves, so a drag that starts on one still pans the city.
func tap() -> void:
	_on_pressed()
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", PRESSED_SCALE, 0.06)
	tween.tween_property(self, "scale", Vector2.ONE, 0.16)


func _tint_marker(color: Color) -> void:
	var style: StyleBoxFlat = _marker.get_theme_stylebox("panel").duplicate()
	style.bg_color = color
	_marker.add_theme_stylebox_override("panel", style)


func _pulse_ring() -> void:
	_ring.pivot_offset = _ring.size / 2.0
	var tween := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_ring, "scale", Vector2(2.6, 2.6), PULSE_SECONDS).from(Vector2.ONE)
	tween.parallel().tween_property(_ring, "modulate:a", 0.0, PULSE_SECONDS).from(0.9)
