class_name StrengthBar
extends Control

## The player's force against a corner's scouted defence, drawn to the same scale without numbers. The top bar is
## the force, the bottom band the range the scout reported. Without a report the bottom track stays empty.

const BAR_HEIGHT := 12.0
const GAP := 8.0
## The longer side never quite reaches the end, so a full bar never reads as a sure thing.
const HEADROOM := 1.15

var _mine := 0.0
var _theirs := Vector2.ZERO
var _known := false
var _their_color := Palette.RISK_HIGH


func _ready() -> void:
	custom_minimum_size.y = BAR_HEIGHT * 2.0 + GAP


func show_strength(mine: float, theirs: Vector2, known: bool, their_color: Color) -> void:
	_mine = mine
	_theirs = theirs
	_known = known
	_their_color = their_color
	queue_redraw()


func _draw() -> void:
	var top := Rect2(0.0, 0.0, size.x, BAR_HEIGHT)
	var bottom := Rect2(0.0, BAR_HEIGHT + GAP, size.x, BAR_HEIGHT)
	draw_rect(top, Palette.LINE)
	draw_rect(bottom, Palette.LINE)
	var scale_to := maxf(_mine, _theirs.y if _known else 0.0) * HEADROOM
	if scale_to <= 0.0:
		return
	var mine_width := size.x * _mine / scale_to
	draw_rect(Rect2(top.position, Vector2(mine_width, BAR_HEIGHT)), TurfBar.PLAYER_COLOR)
	if not _known:
		return
	var low := size.x * _theirs.x / scale_to
	var high := maxf(low + 2.0, size.x * _theirs.y / scale_to)
	draw_rect(Rect2(Vector2(0.0, bottom.position.y), Vector2(low, BAR_HEIGHT)), _their_color)
	draw_rect(Rect2(Vector2(low, bottom.position.y), Vector2(high - low, BAR_HEIGHT)), Color(_their_color, 0.45))
	draw_line(Vector2(mine_width, 0.0), Vector2(mine_width, size.y), Palette.TEXT_CREAM, 2.0)
