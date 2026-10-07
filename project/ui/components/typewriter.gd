class_name Typewriter
extends Label

signal finished

const CHARACTERS_PER_SECOND := 55.0
const BLIP_EVERY_CHARACTERS := 3

@export var blips := true

var _tween: Tween


func _ready() -> void:
	visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING


func type_text(value: String) -> void:
	stop()
	text = value
	if value.is_empty():
		_finish()
		return
	visible_characters = 0
	_tween = create_tween()
	_tween.tween_method(_reveal, 0.0, float(value.length()), value.length() / CHARACTERS_PER_SECOND)
	_tween.finished.connect(_finish)


func is_typing() -> bool:
	return _tween != null


func skip() -> void:
	if is_typing():
		stop()
		_finish()


## Halts typing without announcing it finished.
func stop() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null


func _reveal(progress: float) -> void:
	var count := int(progress)
	if count == visible_characters:
		return
	visible_characters = count
	if blips and count > 0 and count % BLIP_EVERY_CHARACTERS == 0 and text[count - 1] != " ":
		AudioService.play_typing_blip()


func _finish() -> void:
	_tween = null
	visible_characters = -1
	finished.emit()
