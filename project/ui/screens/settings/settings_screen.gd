extends Control

@onready var _music_slider: HSlider = %MusicSlider
@onready var _sfx_slider: HSlider = %SfxSlider
@onready var _vibration_toggle: CheckButton = %VibrationToggle
@onready var _shake_toggle: CheckButton = %ShakeToggle
@onready var _do_not_disturb_toggle: CheckButton = %DoNotDisturbToggle
@onready var _version_label: Label = %VersionLabel

@onready var _new_game_button: Button = %NewGameButton
@onready var _backup_button: Button = %BackupButton
@onready var _restore_button: Button = %RestoreButton
@onready var _wipe_button: Button = %WipeButton
@onready var _data_status_label: Label = %DataStatusLabel
@onready var _confirm_dialog: ConfirmDialog = %ConfirmDialog

var _pending_action := ""


func _ready() -> void:
	SafeArea.apply_top_margin(%Margin, 48)
	_version_label.text = "v%s" % ProjectSettings.get_setting("application/config/version", "")
	%DoneButton.pressed.connect(_leave)
	_music_slider.value = Settings.music_volume
	_sfx_slider.value = Settings.sfx_volume
	_vibration_toggle.button_pressed = Settings.vibration
	_shake_toggle.button_pressed = Settings.screen_shake
	_do_not_disturb_toggle.button_pressed = Settings.do_not_disturb

	_music_slider.value_changed.connect(func(value: float) -> void: Settings.music_volume = value)
	_sfx_slider.value_changed.connect(func(value: float) -> void: Settings.sfx_volume = value)
	_vibration_toggle.toggled.connect(func(enabled: bool) -> void: Settings.vibration = enabled)
	_shake_toggle.toggled.connect(func(enabled: bool) -> void: Settings.screen_shake = enabled)
	_do_not_disturb_toggle.toggled.connect(func(enabled: bool) -> void: Settings.do_not_disturb = enabled)

	_new_game_button.pressed.connect(_on_new_game_pressed)
	_backup_button.pressed.connect(_on_backup_pressed)
	_restore_button.pressed.connect(_on_restore_pressed)
	_wipe_button.pressed.connect(_on_wipe_pressed)
	_confirm_dialog.confirmed.connect(_on_dialog_confirmed)

	_apply_theme_tokens()


func _apply_theme_tokens() -> void:
	_data_status_label.add_theme_color_override("font_color", Palette.PEACH_TITLE)


func handle_back() -> bool:
	if _confirm_dialog.visible:
		_confirm_dialog.close()
		return true
	_leave()
	return true


func _leave() -> void:
	Settings.save()
	var opened_from := SceneRouter.previous_scene
	if opened_from.is_empty() or opened_from == SceneRouter.SETTINGS_SCREEN or opened_from == SceneRouter.TITLE_SCREEN:
		if GameState.run != null:
			SceneRouter.go_to(SceneRouter.DISTRICT_SCREEN)
		else:
			SceneRouter.go_to(SceneRouter.CHARACTER_SELECT)
	else:
		SceneRouter.go_to(opened_from)


func _on_new_game_pressed() -> void:
	if GameState.has_saved_run():
		_pending_action = "new_game"
		_confirm_dialog.open("Start Over?", "Your current progress will be lost.", "Start Over", true)
	else:
		GameState.delete_run()
		SceneRouter.go_to(SceneRouter.CHARACTER_SELECT)


func _on_backup_pressed() -> void:
	var result := GameState.backup_save()
	_data_status_label.text = str(result.get("message", ""))
	if result.get("success", false):
		AudioService.play_sfx(Sfx.COINS_IN)
	else:
		AudioService.play_sfx(Sfx.HAGGLE_FAIL)


func _on_restore_pressed() -> void:
	if not GameState.has_backup():
		_data_status_label.text = "No backup file found on device."
		AudioService.play_sfx(Sfx.HAGGLE_FAIL)
		return
	_pending_action = "restore"
	_confirm_dialog.open("Restore Backup?", "This will replace your current game save with the backup file from your device.", "Restore", true)


func _on_wipe_pressed() -> void:
	_pending_action = "wipe"
	_confirm_dialog.open("Wipe All Data?", "Permanently delete your game save and reset all progress? This action cannot be undone.", "Wipe Everything", true)


func _on_dialog_confirmed() -> void:
	match _pending_action:
		"new_game":
			GameState.delete_run()
			SceneRouter.go_to(SceneRouter.CHARACTER_SELECT)
		"restore":
			var result := GameState.restore_save()
			_data_status_label.text = str(result.get("message", ""))
			if result.get("success", false):
				AudioService.play_sfx(Sfx.COINS_IN)
				await get_tree().create_timer(0.4).timeout
				SceneRouter.go_to(SceneRouter.DISTRICT_SCREEN)
			else:
				AudioService.play_sfx(Sfx.HAGGLE_FAIL)
		"wipe":
			GameState.delete_run()
			_data_status_label.text = "All game data has been wiped."
			AudioService.play_sfx(Sfx.CAUGHT)
			await get_tree().create_timer(0.4).timeout
			SceneRouter.go_to(SceneRouter.CHARACTER_SELECT)
	_pending_action = ""
