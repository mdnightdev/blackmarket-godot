class_name AmbientParticles
extends CPUParticles2D

## Emitter position as a fraction of the visible screen, so effects adapt to any aspect ratio.
@export var screen_anchor := Vector2(0.5, 0.0)
@export var pixel_offset := Vector2.ZERO
@export var fill_width := true
@export var fill_height := false
## When above zero, lifetime is set so particles cross the whole screen height at this speed.
@export var crossing_speed := 0.0


func _ready() -> void:
	get_viewport().size_changed.connect(_fit_to_screen)
	_fit_to_screen()


func _fit_to_screen() -> void:
	var screen_size := get_viewport_rect().size
	position = screen_size * screen_anchor + pixel_offset
	var extents := emission_rect_extents
	if fill_width:
		extents.x = screen_size.x * 0.6
	if fill_height:
		extents.y = screen_size.y * 0.5
	emission_rect_extents = extents
	if crossing_speed > 0.0:
		lifetime = (screen_size.y + absf(pixel_offset.y) * 2.0) / crossing_speed
