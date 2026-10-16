class_name BattleCommandBar
extends Control
## Bottom action deck allowing the player to execute tactical orders during battle.

signal command_used(command_name: StringName)

const COOLDOWN_SUPPRESS := 3.5
const COOLDOWN_RALLY := 4.5
const COOLDOWN_BLITZ := 4.0

const ICON_SUPPRESS := preload("res://assets/icons/hud/shield.svg")
const ICON_RALLY := preload("res://assets/icons/hud/flame.svg")
const ICON_BLITZ := preload("res://assets/icons/hud/swords.svg")

var _buttons: Dictionary = {}
var _cooldowns: Dictionary = {}


func _ready() -> void:
	custom_minimum_size = Vector2(0.0, 96.0)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(row)

	_create_command_button(row, &"suppress", "SUPPRESS", "Pin line", ICON_SUPPRESS, COOLDOWN_SUPPRESS)
	_create_command_button(row, &"rally", "RALLY", "Hold ground", ICON_RALLY, COOLDOWN_RALLY)
	_create_command_button(row, &"blitz", "BLITZ", "Front assault", ICON_BLITZ, COOLDOWN_BLITZ)


func _process(delta: float) -> void:
	for cmd: StringName in _cooldowns:
		var current: float = _cooldowns[cmd]
		if current > 0.0:
			current = maxf(0.0, current - delta)
			_cooldowns[cmd] = current
			var data: Dictionary = _buttons[cmd]
			var bar: ColorRect = data.bar
			var btn: Button = data.btn
			var max_time: float = data.max_time
			if current > 0.0:
				bar.anchor_right = current / max_time
				btn.disabled = true
			else:
				bar.anchor_right = 0.0
				btn.disabled = false


func set_active(enabled: bool) -> void:
	visible = enabled
	set_process(enabled)


func _create_command_button(parent: Node, cmd_id: StringName, title: String, subtitle: String, icon_tex: Texture2D, cooldown_time: float) -> void:
	var container := PanelContainer.new()
	container.theme_type_variation = &"Card"
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.custom_minimum_size = Vector2(0.0, 84.0)

	var btn := Button.new()
	btn.theme_type_variation = &"GhostButton"
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.pressed.connect(_on_button_pressed.bind(cmd_id))

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 2)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon_row := HBoxContainer.new()
	icon_row.alignment = BoxContainer.ALIGNMENT_CENTER
	icon_row.add_theme_constant_override("separation", 6)
	icon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon := TextureRect.new()
	icon.texture = icon_tex
	icon.custom_minimum_size = Vector2(18.0, 18.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = Palette.PEACH_TITLE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_row.add_child(icon)

	var title_lbl := Label.new()
	title_lbl.theme_type_variation = &"NameLabel"
	title_lbl.text = title
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_row.add_child(title_lbl)
	content.add_child(icon_row)

	var sub_lbl := Label.new()
	sub_lbl.theme_type_variation = &"CaptionLabel"
	sub_lbl.modulate = Palette.TEXT_MUTED
	sub_lbl.text = subtitle
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(sub_lbl)

	var track := ColorRect.new()
	track.color = Palette.LINE
	track.custom_minimum_size = Vector2(0.0, 3.0)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := ColorRect.new()
	fill.color = Palette.PEACH_BRIGHT
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.anchor_right = 0.0
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(fill)
	content.add_child(track)

	container.add_child(content)
	container.add_child(btn)
	parent.add_child(container)

	_buttons[cmd_id] = {
		"btn": btn,
		"bar": fill,
		"max_time": cooldown_time
	}
	_cooldowns[cmd_id] = 0.0


func _on_button_pressed(cmd_id: StringName) -> void:
	if float(_cooldowns.get(cmd_id, 0.0)) > 0.0:
		return
	var data: Dictionary = _buttons[cmd_id]
	_cooldowns[cmd_id] = float(data.max_time)
	data.btn.disabled = true
	command_used.emit(cmd_id)
