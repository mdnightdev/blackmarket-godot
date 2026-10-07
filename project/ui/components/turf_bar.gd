class_name TurfBar
extends GameButton

const PLAYER_COLOR := Palette.RISK_LOW
const VEX_COLOR := Palette.PEACH
const HOLD_MARK_COLOR := Color(1, 1, 1, 0.35)
const STATUS_TEXT := {
	Turf.Holder.PLAYER: "YOURS",
	Turf.Holder.VEX: "VEX HOLDS",
	Turf.Holder.NOBODY: "CONTESTED",
}

var _share := 50

@onready var _share_label: Label = %ShareLabel
@onready var _status_label: Label = %StatusLabel
@onready var _bar: Control = %Bar


func _ready() -> void:
	super()
	_bar.draw.connect(_draw_bar)


func show_district(run: RunState, district_id: StringName) -> void:
	_share = Turf.share(run, district_id)
	if run.vex_gone:
		_share_label.text = "TURF  Vex has left the city"
	else:
		_share_label.text = "TURF  You %d%%   Vex %d%%" % [_share, 100 - _share]
	_status_label.text = STATUS_TEXT[Turf.holder(run, district_id)]
	_bar.queue_redraw()


func _draw_bar() -> void:
	var full := Rect2(Vector2.ZERO, _bar.size)
	var split := full.size.x * _share / 100.0
	_bar.draw_rect(Rect2(Vector2.ZERO, Vector2(split, full.size.y)), PLAYER_COLOR)
	_bar.draw_rect(Rect2(Vector2(split, 0), Vector2(full.size.x - split, full.size.y)), VEX_COLOR)
	for mark: int in [Turf.VEX_HOLD_SHARE, Turf.HOLD_SHARE]:
		var x := full.size.x * mark / 100.0
		_bar.draw_line(Vector2(x, 0), Vector2(x, full.size.y), HOLD_MARK_COLOR, 2.0)
