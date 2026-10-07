extends Node

signal changed

const FILE_PATH := "user://settings.cfg"
const SECTION := "settings"

var music_volume: float = 0.7:
	set(value):
		music_volume = clampf(value, 0.0, 1.0)
		changed.emit()

var sfx_volume: float = 0.8:
	set(value):
		sfx_volume = clampf(value, 0.0, 1.0)
		changed.emit()

var vibration: bool = true:
	set(value):
		vibration = value
		changed.emit()

var screen_shake: bool = true:
	set(value):
		screen_shake = value
		changed.emit()


func _ready() -> void:
	load_from_disk()


func load_from_disk() -> void:
	var config := ConfigFile.new()
	if config.load(FILE_PATH) != OK:
		return
	music_volume = float(config.get_value(SECTION, "music_volume", music_volume))
	sfx_volume = float(config.get_value(SECTION, "sfx_volume", sfx_volume))
	vibration = bool(config.get_value(SECTION, "vibration", vibration))
	screen_shake = bool(config.get_value(SECTION, "screen_shake", screen_shake))


func save() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "music_volume", music_volume)
	config.set_value(SECTION, "sfx_volume", sfx_volume)
	config.set_value(SECTION, "vibration", vibration)
	config.set_value(SECTION, "screen_shake", screen_shake)
	var error := config.save(FILE_PATH)
	if error != OK:
		push_error("Settings save failed: %s" % error_string(error))


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		save()
