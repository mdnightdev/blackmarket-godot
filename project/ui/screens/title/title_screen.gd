extends Control

const MUSIC: AudioStream = preload("res://audio/music/theme.mp3")
const DRIFT_SCALE := Vector2(1.06, 1.06)
const DRIFT_SECONDS := 22.0
const GLOW_ALPHA := 0.16
const LOGO_SLIDE := 24.0

@onready var _background: TextureRect = %Background
@onready var _neon_glow: TextureRect = %NeonGlow
@onready var _logo: Control = %Logo
@onready var _menu: VBoxContainer = %Menu
@onready var _continue_button: Button = %ContinueButton
@onready var _new_game_button: Button = %NewGameButton
@onready var _version_label: Label = %VersionLabel
@onready var _confirm_dialog: ConfirmDialog = %ConfirmDialog
@onready var _exit_dialog: ConfirmDialog = %ExitDialog


func _ready() -> void:
	_refresh_menu()
	_version_label.text = "v%s" % ProjectSettings.get_setting("application/config/version", "")

	_continue_button.pressed.connect(_on_continue_pressed)
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_confirm_dialog.confirmed.connect(_start_new_game)
	_exit_dialog.confirmed.connect(get_tree().quit)
	resized.connect(_center_background_pivot)
	_center_background_pivot()

	AudioService.play_music(MUSIC)
	_play_entrance()
	_start_background_drift()
	_flicker_neon()


func handle_back() -> bool:
	if _confirm_dialog.visible:
		_confirm_dialog.close()
	elif _exit_dialog.visible:
		_exit_dialog.close()
	else:
		_exit_dialog.open("Exit game?", "Your run is saved." if GameState.has_saved_run() else "", "Yes")
	return true


func _refresh_menu() -> void:
	var has_save := GameState.has_saved_run()
	_continue_button.visible = has_save
	_new_game_button.theme_type_variation = &"SecondaryButton" if has_save else &"PrimaryButton"


func _on_continue_pressed() -> void:
	if GameState.load_saved_run():
		SceneRouter.go_to(SceneRouter.END_SCREEN if Campaign.is_over(GameState.run) else SceneRouter.DISTRICT_SCREEN)
		return
	_continue_button.hide()
	_new_game_button.theme_type_variation = &"PrimaryButton"
	_confirm_dialog.open("Save unreadable", "Your last save could not be loaded. Start a new run?", "New game")


func _on_new_game_pressed() -> void:
	if GameState.has_saved_run():
		_confirm_dialog.open("Start over?", "Your current run will be lost.", "Start over", true)
	else:
		_start_new_game()


## The old save stays until a character is picked, so backing out loses nothing.
func _start_new_game() -> void:
	SceneRouter.go_to(SceneRouter.CHARACTER_SELECT)


func _center_background_pivot() -> void:
	_background.pivot_offset = _background.size / 2.0


func _play_entrance() -> void:
	var buttons := _menu.get_children().filter(func(node: Node) -> bool: return node is Control and node.visible)
	_background.modulate.a = 0.0
	_logo.modulate.a = 0.0
	var logo_rest_y := _logo.position.y
	_logo.position.y -= LOGO_SLIDE
	for button: Control in buttons:
		button.modulate.a = 0.0

	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_background, "modulate:a", 1.0, 0.9)
	tween.tween_property(_logo, "modulate:a", 1.0, 0.8).set_delay(0.3)
	tween.tween_property(_logo, "position:y", logo_rest_y, 0.8).set_delay(0.3)
	for index in buttons.size():
		tween.tween_property(buttons[index], "modulate:a", 1.0, 0.4).set_delay(0.7 + index * 0.08)


func _start_background_drift() -> void:
	var tween := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_background, "scale", DRIFT_SCALE, DRIFT_SECONDS)
	tween.tween_property(_background, "scale", Vector2.ONE, DRIFT_SECONDS)


func _flicker_neon() -> void:
	var tween := create_tween()
	if randf() < 0.18:
		tween.tween_property(_neon_glow, "modulate:a", GLOW_ALPHA * 0.35, 0.05)
		tween.tween_property(_neon_glow, "modulate:a", GLOW_ALPHA, 0.08)
	else:
		tween.tween_property(_neon_glow, "modulate:a", GLOW_ALPHA * randf_range(0.8, 1.15), randf_range(0.6, 1.4))
	tween.tween_callback(_flicker_neon)
