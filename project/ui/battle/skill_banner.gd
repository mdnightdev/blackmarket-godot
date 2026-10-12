class_name SkillBanner
extends PanelContainer
## Slides in from the right edge when an enforcer's skill fires, then slides back out.

const PORTRAIT_SIZE := Vector2(64.0, 76.0)
const SLIDE_SECONDS := 0.3
const HOLD_SECONDS := 1.6

var _portrait := TextureRect.new()
var _owner_label := Label.new()
var _skill_label := Label.new()
var _rest_x := 0.0


func _ready() -> void:
	theme_type_variation = &"Card"
	modulate.a = 0.0
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	_portrait.custom_minimum_size = PORTRAIT_SIZE
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	row.add_child(_portrait)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(column)
	_owner_label.theme_type_variation = &"NameLabel"
	_skill_label.theme_type_variation = &"MutedLabel"
	column.add_child(_owner_label)
	column.add_child(_skill_label)


func announce(side: BattleSide) -> void:
	_portrait.texture = side.skill_portrait
	_owner_label.text = side.skill_owner
	_skill_label.text = side.skill_name
	await get_tree().process_frame
	_rest_x = position.x
	var parent_width := get_parent_area_size().x
	position.x = parent_width
	modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(self, "position:x", _rest_x, SLIDE_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(HOLD_SECONDS)
	tween.tween_property(self, "position:x", parent_width, SLIDE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		modulate.a = 0.0
		position.x = _rest_x)
