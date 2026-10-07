class_name DealFlash
extends Control
## Short celebration when a trade closes: cash bundles slide in (sale) or out (purchase)
## while the amount counts up. Big deals add the handshake and block taps until skipped.

const BIG_HOLD_SECONDS := 1.1
const SMALL_HOLD_SECONDS := 0.4
const FADE_OUT_SECONDS := 0.3
const SKIP_FADE_SECONDS := 0.15
const SMALL_DIM_ALPHA := 0.55
const HANDSHAKE_START_SCALE := 1.12
const COUNT_SECONDS := 0.6
const SLIDE_SECONDS := 0.4
const SLIDE_DELAY := 0.15
const SLIDE_STAGGER := 0.07
const BUNDLE_SPACING := 96.0
const BUNDLE_ANGLES: Array[float] = [-9.0, 3.0, 12.0]

@onready var _dim: ColorRect = %Dim
@onready var _handshake: TextureRect = %Handshake
@onready var _lane: Control = %Lane
@onready var _amount: Label = %Amount

var _bundles: Array[TextureRect] = []
var _tween: Tween
var _skippable := false


func _ready() -> void:
	hide()
	_bundles.assign(_lane.get_children())
	gui_input.connect(_on_tap)


func play(cash_delta: int, with_handshake: bool) -> void:
	if _tween:
		_tween.kill()
	var earning := cash_delta > 0
	_skippable = with_handshake
	mouse_filter = Control.MOUSE_FILTER_STOP if with_handshake else Control.MOUSE_FILTER_IGNORE
	modulate.a = 1.0
	_dim.modulate.a = 0.0
	_handshake.visible = with_handshake
	_amount.text = ""
	_amount.add_theme_color_override("font_color", Palette.RISK_LOW if earning else Palette.PEACH_BRIGHT)
	show()
	await get_tree().process_frame

	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_dim, "modulate:a", 1.0 if with_handshake else SMALL_DIM_ALPHA, 0.2)
	if with_handshake:
		_handshake.pivot_offset = _handshake.size / 2.0
		_handshake.scale = Vector2.ONE * HANDSHAKE_START_SCALE
		_handshake.modulate.a = 0.0
		_tween.tween_property(_handshake, "modulate:a", 1.0, 0.25)
		_tween.tween_property(_handshake, "scale", Vector2.ONE, 0.5)
		AudioService.play_sfx(Sfx.HANDSHAKE)
	_slide_bundles(earning)
	_tween.tween_callback(AudioService.play_sfx.bind(Sfx.COINS_IN if earning else Sfx.COINS_OUT, 0.05)).set_delay(SLIDE_DELAY)
	_tween.tween_method(_show_amount.bind(earning), 0.0, float(absi(cash_delta)), COUNT_SECONDS).set_delay(SLIDE_DELAY)

	_tween.chain().tween_interval(BIG_HOLD_SECONDS if with_handshake else SMALL_HOLD_SECONDS)
	_tween.chain().tween_property(self, "modulate:a", 0.0, FADE_OUT_SECONDS)
	_tween.chain().tween_callback(_finish)


func _slide_bundles(earning: bool) -> void:
	var lane_width := _lane.size.x
	for index in _bundles.size():
		var bundle := _bundles[index]
		var resting_x := lane_width / 2.0 + (index - 1) * BUNDLE_SPACING - bundle.size.x / 2.0
		var from_x := resting_x + lane_width if earning else resting_x
		var to_x := resting_x if earning else resting_x - lane_width
		bundle.position = Vector2(from_x, 0.0)
		bundle.rotation_degrees = BUNDLE_ANGLES[index]
		var ease_type := Tween.EASE_OUT if earning else Tween.EASE_IN
		_tween.tween_property(bundle, "position:x", to_x, SLIDE_SECONDS) \
				.set_trans(Tween.TRANS_BACK).set_ease(ease_type).set_delay(SLIDE_DELAY + index * SLIDE_STAGGER)


func _show_amount(value: float, earning: bool) -> void:
	_amount.text = ("+" if earning else "-") + Format.money(roundi(value))


func _on_tap(event: InputEvent) -> void:
	if not _skippable or not (event is InputEventMouseButton and event.pressed):
		return
	_skippable = false
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, SKIP_FADE_SECONDS)
	_tween.tween_callback(_finish)


func _finish() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
