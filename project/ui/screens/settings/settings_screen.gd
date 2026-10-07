extends Control

@onready var _music_slider: HSlider = %MusicSlider
@onready var _sfx_slider: HSlider = %SfxSlider
@onready var _vibration_toggle: CheckButton = %VibrationToggle
@onready var _shake_toggle: CheckButton = %ShakeToggle


func _ready() -> void:
	_music_slider.value = Settings.music_volume
	_sfx_slider.value = Settings.sfx_volume
	_vibration_toggle.button_pressed = Settings.vibration
	_shake_toggle.button_pressed = Settings.screen_shake

	_music_slider.value_changed.connect(func(value: float) -> void: Settings.music_volume = value)
	_sfx_slider.value_changed.connect(func(value: float) -> void: Settings.sfx_volume = value)
	_vibration_toggle.toggled.connect(func(enabled: bool) -> void: Settings.vibration = enabled)
	_shake_toggle.toggled.connect(func(enabled: bool) -> void: Settings.screen_shake = enabled)


func handle_back() -> bool:
	_leave()
	return true


func _leave() -> void:
	Settings.save()
	var opened_from := SceneRouter.previous_scene
	SceneRouter.go_to(SceneRouter.TITLE_SCREEN if opened_from.is_empty() or opened_from == SceneRouter.SETTINGS_SCREEN else opened_from)
