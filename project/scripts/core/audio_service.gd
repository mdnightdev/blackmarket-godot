extends Node

const MUSIC_BUS: StringName = &"Music"
const SFX_BUS: StringName = &"SFX"
const SFX_VOICES := 6
const MUSIC_FADE_SECONDS := 0.8
const SILENT_DB := -40.0
const SIREN_DB := -9.0
const SIREN_FADE_SECONDS := 0.6
const TYPING_DB := -16.0
const TYPING_PITCH_VARIATION := 0.12

var _music_player: AudioStreamPlayer
var _music_tween: Tween
var _siren_player: AudioStreamPlayer
var _siren_tween: Tween
## Typing blips get their own voice so rapid ticks never cut off other effects.
var _typing_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_sfx_voice := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = MUSIC_BUS
	_music_player.finished.connect(_music_player.play)
	add_child(_music_player)

	for i in SFX_VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		_sfx_players.append(player)

	_siren_player = AudioStreamPlayer.new()
	_siren_player.bus = SFX_BUS
	_siren_player.stream = Sfx.SIREN
	_siren_player.finished.connect(_siren_player.play)
	add_child(_siren_player)

	_typing_player = AudioStreamPlayer.new()
	_typing_player.bus = SFX_BUS
	_typing_player.stream = Sfx.TYPING
	_typing_player.volume_db = TYPING_DB
	add_child(_typing_player)

	Settings.changed.connect(_apply_volumes)
	_apply_volumes()


func play_music(stream: AudioStream) -> void:
	if _music_player.stream == stream and _music_player.playing:
		return
	_music_player.stream = stream
	_music_player.volume_db = SILENT_DB
	_music_player.play()
	_fade_music_to(0.0)


func stop_music() -> void:
	if not _music_player.playing:
		return
	_fade_music_to(SILENT_DB).tween_callback(_music_player.stop)


func play_sfx(stream: AudioStream, pitch_variation: float = 0.0, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	var player := _sfx_players[_next_sfx_voice]
	_next_sfx_voice = (_next_sfx_voice + 1) % SFX_VOICES
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.play()


func play_typing_blip() -> void:
	_typing_player.pitch_scale = 1.0 + randf_range(-TYPING_PITCH_VARIATION, TYPING_PITCH_VARIATION)
	_typing_player.play()


func start_siren() -> void:
	if not _siren_player.playing:
		_siren_player.volume_db = SILENT_DB
		_siren_player.play()
	_fade_siren_to(SIREN_DB)


func stop_siren() -> void:
	if not _siren_player.playing:
		return
	_fade_siren_to(SILENT_DB).tween_callback(_siren_player.stop)


func _fade_siren_to(volume_db: float) -> Tween:
	if _siren_tween:
		_siren_tween.kill()
	_siren_tween = create_tween()
	_siren_tween.tween_property(_siren_player, "volume_db", volume_db, SIREN_FADE_SECONDS)
	return _siren_tween


func _fade_music_to(volume_db: float) -> Tween:
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", volume_db, MUSIC_FADE_SECONDS)
	return _music_tween


func _apply_volumes() -> void:
	_set_bus_volume(MUSIC_BUS, Settings.music_volume)
	_set_bus_volume(SFX_BUS, Settings.sfx_volume)


func _set_bus_volume(bus_name: StringName, linear_volume: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		push_error("Audio bus missing: %s" % bus_name)
		return
	AudioServer.set_bus_mute(bus_index, linear_volume <= 0.0)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(linear_volume, 0.0001)))


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			_music_player.stream_paused = true
			_siren_player.stream_paused = true
		NOTIFICATION_APPLICATION_RESUMED:
			_music_player.stream_paused = false
			_siren_player.stream_paused = false
