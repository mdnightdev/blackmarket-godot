class_name TurfBar
extends GameButton

const PLAYER_COLOR := Palette.RISK_LOW
const OPEN_COLOR := Palette.TEXT_MUTED
const HOLD_MARK_COLOR := Color(1, 1, 1, 0.35)
const PIP_GAP := 4.0

var _share := 50
var _gang_color := OPEN_COLOR
var _corner_colors: Array[Color] = []

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
	_corner_colors.clear()
	for corner in Corners.of(district_id):
		_corner_colors.append(PLAYER_COLOR if Corners.holds(run, corner.id) else gang.color)
	if not _corner_colors.is_empty():
		_share_label.text = "CORNERS  You %d   %s %d" % [Corners.held_count(run, district_id), gang.display_name, _corner_colors.size() - Corners.held_count(run, district_id)]
	elif Gangs.is_gone(run, gang):
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
	if not _corner_colors.is_empty():
		_draw_pips()
		return
	var full := Rect2(Vector2.ZERO, _bar.size)
	var split := full.size.x * _share / 100.0
	_bar.draw_rect(Rect2(Vector2.ZERO, Vector2(split, full.size.y)), PLAYER_COLOR)
	_bar.draw_rect(Rect2(Vector2(split, 0), Vector2(full.size.x - split, full.size.y)), _gang_color)
	for mark: int in [Turf.GANG_HOLD_SHARE, Turf.HOLD_SHARE]:
		var x := full.size.x * mark / 100.0
		_bar.draw_line(Vector2(x, 0), Vector2(x, full.size.y), HOLD_MARK_COLOR, 2.0)


func _draw_pips() -> void:
	var count := _corner_colors.size()
	var width := (_bar.size.x - PIP_GAP * (count - 1)) / count
	for index in count:
		var left := index * (width + PIP_GAP)
		_bar.draw_rect(Rect2(Vector2(left, 0), Vector2(width, _bar.size.y)), _corner_colors[index])
