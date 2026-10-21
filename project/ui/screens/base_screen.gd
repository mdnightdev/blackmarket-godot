class_name BaseScreen
extends Control


## Common entrance animation for screens with a header and scrollable body.
func play_screen_entrance(header: Control, body: Control, header_dur: float = 0.4, body_dur: float = 0.45) -> Tween:
	if header != null:
		header.modulate.a = 0.0
	if body != null:
		body.modulate.a = 0.0
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if header != null:
		tween.tween_property(header, "modulate:a", 1.0, header_dur)
	if body != null:
		tween.tween_property(body, "modulate:a", 1.0, body_dur).set_delay(0.12)
	return tween


func _exit_tree() -> void:
	GameState.clock_active = false
