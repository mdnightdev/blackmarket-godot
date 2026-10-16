class_name BattleResultCard
extends Control
## Dedicated post-battle summary card showing casualties, survivors, and turf status.

signal confirmed

@onready var _dimmer := ColorRect.new()
@onready var _card := PanelContainer.new()
@onready var _title_label := Label.new()
@onready var _sub_label := Label.new()
@onready var _survivor_val := Label.new()
@onready var _wounded_val := Label.new()
@onready var _lost_val := Label.new()
@onready var _enemy_val := Label.new()
@onready var _confirm_btn := Button.new()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dimmer.color = Color(0.05, 0.06, 0.08, 0.88)
	add_child(_dimmer)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_card.theme_type_variation = &"Card"
	_card.custom_minimum_size = Vector2(580.0, 420.0)
	center.add_child(_card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	_card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	_title_label.theme_type_variation = &"TitleLabel"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	_sub_label.theme_type_variation = &"NameLabel"
	_sub_label.modulate = Palette.TEXT_CREAM
	_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_sub_label)

	var divider1 := ColorRect.new()
	divider1.color = Palette.LINE
	divider1.custom_minimum_size = Vector2(0.0, 1.0)
	vbox.add_child(divider1)

	var stats_row := HBoxContainer.new()
	stats_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_row.add_theme_constant_override("separation", 24)
	vbox.add_child(stats_row)

	_add_stat_box(stats_row, "FIT", _survivor_val, Palette.RISK_LOW)
	_add_stat_box(stats_row, "WOUNDED", _wounded_val, Palette.PRICE)
	_add_stat_box(stats_row, "FALLEN", _lost_val, Palette.RISK_HIGH)

	var divider2 := ColorRect.new()
	divider2.color = Palette.LINE
	divider2.custom_minimum_size = Vector2(0.0, 1.0)
	vbox.add_child(divider2)

	_enemy_val.theme_type_variation = &"CaptionLabel"
	_enemy_val.modulate = Palette.TEXT_MUTED
	_enemy_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_enemy_val)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	_confirm_btn.theme_type_variation = &"PrimaryButton"
	_confirm_btn.custom_minimum_size = Vector2(0.0, 52.0)
	_confirm_btn.text = "CONTINUE"
	_confirm_btn.pressed.connect(_on_confirm)
	vbox.add_child(_confirm_btn)


func display(won: bool, result_line: String, player_side: BattleSide, enemy_side: BattleSide) -> void:
	if won:
		_title_label.text = "VICTORY"
		_title_label.modulate = Palette.PEACH_BRIGHT
		_confirm_btn.text = "CLAIM TURF"
	else:
		_title_label.text = "RETREAT"
		_title_label.modulate = Palette.RISK_HIGH
		_confirm_btn.text = "PULL BACK"

	_sub_label.text = result_line if result_line != _title_label.text else ""
	_sub_label.visible = not _sub_label.text.is_empty()

	var lost := player_side.losses()
	var wounded := roundi(float(lost) * 0.6)
	var dead := lost - wounded

	_survivor_val.text = str(player_side.survivors)
	_wounded_val.text = str(wounded)
	_lost_val.text = str(dead)

	_enemy_val.text = "%s: %d lost of %d" % [enemy_side.display_name, enemy_side.losses(), enemy_side.head_count]

	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.35)


func _add_stat_box(parent: Node, label_text: String, value_lbl: Label, text_color: Color) -> void:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	value_lbl.theme_type_variation = &"HudValueLabel"
	value_lbl.modulate = text_color
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(value_lbl)

	var caption := Label.new()
	caption.theme_type_variation = &"HudCaptionLabel"
	caption.text = label_text
	caption.modulate = Palette.TEXT_MUTED
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(caption)

	parent.add_child(col)


func _on_confirm() -> void:
	AudioService.play_sfx(Sfx.CLICK)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(confirmed.emit)
