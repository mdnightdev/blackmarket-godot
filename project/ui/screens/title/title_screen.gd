extends Control

const MUSIC_PATH := "res://audio/music/theme.mp3"
const DRIFT_SCALE := Vector2(1.06, 1.06)
const DRIFT_SECONDS := 22.0
const GLOW_ALPHA := 0.16
const BOOT_DELAY_SECONDS := 2.0

var _music: AudioStream

@onready var _background: TextureRect = %Background
@onready var _neon_glow: TextureRect = %NeonGlow
@onready var _logo: Control = %Logo
@onready var _exit_dialog: ConfirmDialog = %ExitDialog

@onready var _loading_section: MarginContainer = %LoadingSection
@onready var _progress_bar: ProgressBar = %ProgressBar
@onready var _status_label: Label = %StatusLabel
@onready var _percent_label: Label = %PercentLabel


func _ready() -> void:
	_exit_dialog.confirmed.connect(get_tree().quit)
	resized.connect(_center_background_pivot)
	_center_background_pivot()

	_apply_theme_tokens()

	_background.modulate.a = 1.0
	_logo.modulate.a = 1.0
	_loading_section.modulate.a = 1.0
	_start_background_drift()
	_flicker_neon()

	# If content already loaded (e.g. headless tests or returning to welcome screen), enter game directly
	if Content.is_loaded():
		_enter_game()
		return

	# Immediately display the Title Screen and wait 2 seconds before the loading bar starts to load
	await get_tree().create_timer(BOOT_DELAY_SECONDS).timeout
	_run_boot_sequence()


func _apply_theme_tokens() -> void:
	# Theming driven exclusively by Palette single source of truth
	var bg_box := StyleBoxFlat.new()
	bg_box.bg_color = Palette.PANEL
	bg_box.border_color = Palette.LINE
	bg_box.set_border_width_all(1)
	bg_box.set_corner_radius_all(8)
	_progress_bar.add_theme_stylebox_override("background", bg_box)

	var fill_box := StyleBoxFlat.new()
	fill_box.bg_color = Palette.PEACH_BRIGHT
	fill_box.set_corner_radius_all(7)
	_progress_bar.add_theme_stylebox_override("fill", fill_box)

	_status_label.add_theme_color_override("font_color", Palette.TEXT_MUTED)
	_percent_label.add_theme_color_override("font_color", Palette.PEACH_TITLE)


func _run_boot_sequence() -> void:
	var targets := [15.0, 35.0, 52.0, 68.0, 82.0, 92.0]
	for step in range(6):
		var status_text: String = Content.load_step(step)
		_set_status(targets[step], status_text)
		await get_tree().process_frame

	_set_status(98.0, "Preparing Syndicate Interface...")
	_music = load(MUSIC_PATH)
	GameOverlay.ensure_setup()
	await get_tree().process_frame

	_set_status(100.0, "Welcome to Black Market")
	await get_tree().create_timer(0.25).timeout

	_enter_game()


func _set_status(val: float, status: String) -> void:
	_status_label.text = status
	var from_val := _progress_bar.value
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_progress_bar, "value", val, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(v: float) -> void: _percent_label.text = "%d%%" % int(v), from_val, val, 0.18)


func _enter_game() -> void:
	if _music == null:
		_music = load(MUSIC_PATH)
	AudioService.play_music(_music)
	if GameState.has_saved_run() and GameState.load_saved_run():
		SceneRouter.go_to(SceneRouter.END_SCREEN if Campaign.is_over(GameState.run) else SceneRouter.DISTRICT_SCREEN)
	else:
		SceneRouter.go_to(SceneRouter.CHARACTER_SELECT)


func handle_back() -> bool:
	if _exit_dialog.visible:
		_exit_dialog.close()
	else:
		_exit_dialog.open("Exit game?", "Your run is saved." if GameState.has_saved_run() else "", "Yes")
	return true


func _center_background_pivot() -> void:
	_background.pivot_offset = _background.size / 2.0


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
