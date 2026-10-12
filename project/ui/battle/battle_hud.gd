class_name BattleHud
extends PanelContainer
## Top bar of a fight: both sides' names and live head counts, each over a strength bar.

const BAR_HEIGHT := 6.0
const COUNT_SECONDS := 0.25

var _left := _SideReadout.new()
var _right := _SideReadout.new()


func _ready() -> void:
	theme_type_variation = &"HudCard"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	add_child(row)
	row.add_child(_left.build(HORIZONTAL_ALIGNMENT_LEFT))
	var versus := Label.new()
	versus.theme_type_variation = &"TitleLabel"
	versus.text = "VS"
	versus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(versus)
	row.add_child(_right.build(HORIZONTAL_ALIGNMENT_RIGHT))


func show_sides(left: BattleSide, right: BattleSide) -> void:
	_left.show_side(left)
	_right.show_side(right)


func set_counts(left_count: int, right_count: int) -> void:
	_left.set_count(self, left_count)
	_right.set_count(self, right_count)


class _SideReadout:
	var _name := Label.new()
	var _count := Label.new()
	var _fill := ColorRect.new()
	var _head_count := 1
	var _shown := 0
	var _mirrored := false

	func build(alignment: HorizontalAlignment) -> Control:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 4)
		var labels := HBoxContainer.new()
		labels.alignment = BoxContainer.ALIGNMENT_END if alignment == HORIZONTAL_ALIGNMENT_RIGHT else BoxContainer.ALIGNMENT_BEGIN
		labels.add_theme_constant_override("separation", 8)
		_name.theme_type_variation = &"HudCaptionLabel"
		_count.theme_type_variation = &"HudValueLabel"
		if alignment == HORIZONTAL_ALIGNMENT_RIGHT:
			labels.add_child(_count)
			labels.add_child(_name)
		else:
			labels.add_child(_name)
			labels.add_child(_count)
		column.add_child(labels)
		var track := ColorRect.new()
		track.color = Palette.LINE
		track.custom_minimum_size.y = BAR_HEIGHT
		_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
		_mirrored = alignment == HORIZONTAL_ALIGNMENT_RIGHT
		track.add_child(_fill)
		column.add_child(track)
		return column

	func show_side(side: BattleSide) -> void:
		_name.text = side.display_name.to_upper()
		_fill.color = side.color
		_head_count = maxi(1, side.head_count)
		_shown = side.head_count
		_count.text = str(_shown)
		_fill.anchor_left = 0.0
		_fill.anchor_right = 1.0

	func set_count(owner: Node, count: int) -> void:
		var tween := owner.create_tween().set_parallel(true)
		tween.tween_method(_show_count, _shown, count, BattleHud.COUNT_SECONDS)
		var share := float(count) / _head_count
		if _mirrored:
			tween.tween_property(_fill, "anchor_left", 1.0 - share, BattleHud.COUNT_SECONDS)
		else:
			tween.tween_property(_fill, "anchor_right", share, BattleHud.COUNT_SECONDS)
		_shown = count

	func _show_count(value: int) -> void:
		_count.text = str(value)
