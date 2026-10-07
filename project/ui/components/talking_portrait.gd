class_name TalkingPortrait
extends Control

## While talking the portrait bobs, breathes and, when the speaker has a talk frame, flaps its mouth.
const BOB_PIXELS := 5.0
const BOB_SPEED := 12.0
const PULSE := 0.008
const MIN_FRAME_SECONDS := 0.07
const MAX_FRAME_SECONDS := 0.16
const SETTLE_SPEED := 10.0

const SOFT_EDGES: Shader = preload("res://ui/shaders/soft_edges.gdshader")

## Fill the frame and crop, instead of fitting the whole portrait.
@export var cover := false
## Fade the portrait's edges into whatever is behind it.
@export var soft_edges := false

var _image := TextureRect.new()
var _speaker: SpeakerDef
var _talking := false
var _time := 0.0
var _next_frame_in := 0.0
var _mouth_open := false


func _ready() -> void:
	_image.set_anchors_preset(PRESET_FULL_RECT)
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if cover else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image.mouse_filter = MOUSE_FILTER_IGNORE
	if soft_edges:
		var edge_material := ShaderMaterial.new()
		edge_material.shader = SOFT_EDGES
		_image.material = edge_material
	add_child(_image)
	resized.connect(func() -> void: _image.pivot_offset = Vector2(size.x / 2.0, size.y))
	set_process(false)


func show_speaker(speaker: SpeakerDef) -> void:
	_speaker = speaker
	_set_mouth(false)


func set_talking(talking: bool) -> void:
	_talking = talking
	if not talking:
		_set_mouth(false)
	set_process(true)


func _process(delta: float) -> void:
	if _talking:
		_time += delta
		_image.position.y = -absf(sin(_time * BOB_SPEED)) * BOB_PIXELS
		_image.scale = Vector2.ONE * (1.0 + sin(_time * BOB_SPEED * 0.5) * PULSE)
		_next_frame_in -= delta
		if _next_frame_in <= 0.0:
			_set_mouth(not _mouth_open)
			_next_frame_in = randf_range(MIN_FRAME_SECONDS, MAX_FRAME_SECONDS)
		return

	var weight := minf(1.0, delta * SETTLE_SPEED)
	_image.position.y = lerpf(_image.position.y, 0.0, weight)
	_image.scale = _image.scale.lerp(Vector2.ONE, weight)
	if absf(_image.position.y) < 0.1:
		_image.position.y = 0.0
		_image.scale = Vector2.ONE
		set_process(false)


func _set_mouth(open: bool) -> void:
	_mouth_open = open and _speaker != null and _speaker.talk_portrait != null
	if _speaker == null:
		_image.texture = null
	else:
		_image.texture = _speaker.talk_portrait if _mouth_open else _speaker.portrait
