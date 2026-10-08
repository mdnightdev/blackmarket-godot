class_name TurfBar
extends GameButton

const PLAYER_COLOR := Palette.RISK_LOW
const OPEN_COLOR := Palette.TEXT_MUTED
const HOLD_MARK_COLOR := Color(1, 1, 1, 0.35)

var _share := 50
var _gang_color := OPEN_COLOR

@onready var _share_label: Label = %ShareLabel
@onready var _status_label: Label = %StatusLabel
@onready var _bar: Control = %Bar


func _ready() -> void:
	super()
	_bar.draw.connect(_draw_bar)


## The colour a district shows on maps and bars: the player's, its gang's, or muted while nobody holds it.
static func holder_color(holder: Turf.Holder, district_id: StringName) -> Color:
	match holder:
		Turf.Holder.PLAYER:
			return PLAYER_COLOR
		Turf.Holder.GANG:
			return Gangs.owner(district_id).color
	return OPEN_COLOR


func show_district(run: RunState, district_id: StringName) -> void:
	var gang := Gangs.owner(district_id)
	if gang == null:
		return
	_share = Turf.share(run, district_id)
	_gang_color = gang.color
	if Gangs.is_gone(run, gang):
		_share_label.text = "TURF  %s has left the city" % gang.display_name
	else:
		_share_label.text = "TURF  You %d%%   %s %d%%" % [_share, gang.display_name, 100 - _share]
	match Turf.holder(run, district_id):
		Turf.Holder.PLAYER:
			_status_label.text = "YOURS"
		Turf.Holder.GANG:
			_status_label.text = "%s HOLDS" % gang.display_name.to_upper()
		_:
			_status_label.text = "CONTESTED"
	_bar.queue_redraw()


func _draw_bar() -> void:
	var full := Rect2(Vector2.ZERO, _bar.size)
	var split := full.size.x * _share / 100.0
	_bar.draw_rect(Rect2(Vector2.ZERO, Vector2(split, full.size.y)), PLAYER_COLOR)
	_bar.draw_rect(Rect2(Vector2(split, 0), Vector2(full.size.x - split, full.size.y)), _gang_color)
	for mark: int in [Turf.GANG_HOLD_SHARE, Turf.HOLD_SHARE]:
		var x := full.size.x * mark / 100.0
		_bar.draw_line(Vector2(x, 0), Vector2(x, full.size.y), HOLD_MARK_COLOR, 2.0)
