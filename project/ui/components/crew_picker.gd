class_name CrewPicker
extends Control

## Lets the player pick how many men of each tier go into a fight. The whole stays inside the expansion's limit.

const OPEN_SECONDS := 0.18
const CLOSE_SECONDS := 0.12
const ROW_SEPARATION := 4

@onready var _dim: ColorRect = %Dim
@onready var _card: PanelContainer = %Card
@onready var _title_label: Label = %TitleLabel
@onready var _message_label: Label = %MessageLabel
@onready var _tiers: VBoxContainer = %Tiers
@onready var _summary_label: Label = %SummaryLabel
@onready var _cancel_button: Button = %CancelButton
@onready var _send_button: Button = %SendButton

var _send_format := ""
var _on_sent := Callable()
var _on_cancel := Callable()
var _wanted := {}
var _sliders := {}
var _count_labels := {}
var _tween: Tween


func _ready() -> void:
	hide()
	_cancel_button.pressed.connect(cancel)
	_send_button.pressed.connect(_send)
	_card.resized.connect(func() -> void: _card.pivot_offset = _card.size / 2.0)


## send_format takes the number of men picked, like "Attack with %d". on_sent receives the deployment. on_cancel may
## be empty.
func open(title: String, message: String, send_format: String, cancel_text: String, on_sent: Callable, on_cancel: Callable) -> void:
	var run := GameState.run
	_title_label.text = title
	_message_label.text = message
	_send_format = send_format
	_cancel_button.text = cancel_text
	_on_sent = on_sent
	_on_cancel = on_cancel
	_wanted = Army.deployment(run)
	_build_rows(run)
	_refresh()
	_dim.modulate.a = 0.0
	_card.modulate.a = 0.0
	_card.scale = Vector2(0.94, 0.94)
	show()
	_animate(1.0, Vector2.ONE, OPEN_SECONDS)


func cancel() -> void:
	if not visible:
		return
	_close()
	if _on_cancel.is_valid():
		_on_cancel.call()


func _send() -> void:
	var deployment := Army.picked(GameState.run, _wanted)
	if deployment.is_empty():
		return
	_close()
	_on_sent.call(deployment)


func _close() -> void:
	_animate(0.0, Vector2(0.96, 0.96), CLOSE_SECONDS).chain().tween_callback(hide)


func _build_rows(run: RunState) -> void:
	for child in _tiers.get_children():
		child.queue_free()
	_sliders.clear()
	_count_labels.clear()
	for tier in Army.DEPLOY_ORDER:
		if Army.count(run, tier) > 0:
			_add_row(run, tier)


func _add_row(run: RunState, tier: Army.Tier) -> void:
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", ROW_SEPARATION)
	var header := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = Army.TIER_NAMES[tier]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)
	var count_label := Label.new()
	count_label.theme_type_variation = &"HudValueLabel"
	header.add_child(count_label)
	rows.add_child(header)
	var slider := HSlider.new()
	slider.max_value = Army.count(run, tier)
	slider.step = 1
	slider.value = int(_wanted.get(tier, 0))
	slider.value_changed.connect(_on_slider_moved.bind(tier))
	rows.add_child(slider)
	_tiers.add_child(rows)
	_sliders[tier] = slider
	_count_labels[tier] = count_label


func _on_slider_moved(amount: float, tier: Army.Tier) -> void:
	var others := Army.deployed_count(_wanted) - int(_wanted.get(tier, 0))
	var allowed := mini(int(amount), Army.deploy_cap(GameState.run) - others)
	_wanted[tier] = allowed
	if allowed != int(amount):
		(_sliders[tier] as HSlider).set_value_no_signal(allowed)
	_refresh()


func _refresh() -> void:
	var run := GameState.run
	for tier: int in _sliders:
		(_count_labels[tier] as Label).text = "%d of %d" % [int(_wanted.get(tier, 0)), Army.count(run, tier)]
	var deployment := Army.picked(run, _wanted)
	var total := Army.deployed_count(deployment)
	var summary := "%d of at most %d in one fight." % [total, Army.deploy_cap(run)]
	var weapons := WarTalk.weapons_text(run, deployment)
	_summary_label.text = "%s %s" % [summary, weapons] if not weapons.is_empty() else summary
	_send_button.text = _send_format % total if total > 0 else "Nobody picked"
	_send_button.disabled = total <= 0


func _animate(alpha: float, card_scale: Vector2, duration: float) -> Tween:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_dim, "modulate:a", alpha, duration)
	_tween.tween_property(_card, "modulate:a", alpha, duration)
	_tween.tween_property(_card, "scale", card_scale, duration)
	return _tween
