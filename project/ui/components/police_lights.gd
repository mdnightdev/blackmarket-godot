class_name PoliceLights
extends ColorRect
## Red and blue light washing in from the screen edges during police encounters.

const SHADER: Shader = preload("res://ui/shaders/police_lights.gdshader")
const FADE_IN_SECONDS := 0.3
const FADE_OUT_SECONDS := 0.6

var _tween: Tween
var _on := false
var _intensity := 0.0


func _init() -> void:
	var lights_material := ShaderMaterial.new()
	lights_material.shader = SHADER
	material = lights_material
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	hide()


func switch_on(intensity: float) -> void:
	_on = true
	show()
	_fade_to(intensity, FADE_IN_SECONDS)


func switch_off() -> void:
	if not _on:
		return
	_on = false
	_fade_to(0.0, FADE_OUT_SECONDS).tween_callback(hide)


func is_on() -> bool:
	return _on


func _fade_to(intensity: float, duration: float) -> Tween:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_intensity, _intensity, intensity, duration)
	return _tween


func _set_intensity(value: float) -> void:
	_intensity = value
	(material as ShaderMaterial).set_shader_parameter("intensity", value)
