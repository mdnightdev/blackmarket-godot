class_name JailCard
extends Control

## Covers the game while the player sits in a cell, swallowing every tap until the time is served.

@onready var _time_label: Label = %TimeLabel


func _process(_delta: float) -> void:
	var jailed := GameState.clock_active and GameState.run != null and Police.is_jailed(GameState.run)
	if visible != jailed:
		visible = jailed
	if jailed:
		_time_label.text = Format.clock(GameState.run.jail_seconds_left)
