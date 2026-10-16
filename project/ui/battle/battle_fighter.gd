class_name BattleFighter
extends Node2D
## One figure on the battlefield, standing in for a squad of men. Its origin sits at the feet.

const DISPLAY_HEIGHT := 64.0
const SHADOW_RADIUS := 18.0
const SHADOW_SQUASH := 0.36
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.5)
const LUNGE_DISTANCE := 20.0
const LUNGE_SECONDS := 0.12
const FALL_SECONDS := 0.4
const FALLEN_TINT := Color(0.45, 0.42, 0.42, 0.75)
const HIT_FLASH_TINT := Color(2.0, 0.6, 0.6, 1.0)
const SURRENDER_TINT := Color(0.7, 0.66, 0.66, 1.0)
const SURRENDER_SQUASH := 0.82
const SLASH_COLOR := Color(1.0, 0.92, 0.75, 0.85)
const TEAM_COLOR_SHADER: Shader = preload("res://ui/battle/team_color.gdshader")

var squad := 0
var alive := true
var facing := 1.0

var _sprite := Sprite2D.new()


func setup(texture: Texture2D, faces_up: bool, team_color: Color) -> void:
	facing = -1.0 if faces_up else 1.0
	_sprite.texture = texture
	if team_color.a > 0.0:
		var repaint := ShaderMaterial.new()
		repaint.shader = TEAM_COLOR_SHADER
		repaint.set_shader_parameter(&"team_color", team_color)
		_sprite.material = repaint
	_sprite.scale = Vector2.ONE * (DISPLAY_HEIGHT / texture.get_height())
	_sprite.offset.y = -texture.get_height() / 2.0
	add_child(_sprite)


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, SHADOW_SQUASH))
	draw_circle(Vector2.ZERO, SHADOW_RADIUS, SHADOW_COLOR)


func march_to(target: Vector2, seconds: float, delay := 0.0) -> void:
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_property(self, "position", target, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func lunge() -> void:
	if not alive:
		return
	var tween := create_tween()
	tween.tween_property(_sprite, "position:y", LUNGE_DISTANCE * facing, LUNGE_SECONDS)
	tween.tween_property(_sprite, "position:y", 0.0, LUNGE_SECONDS * 1.5)
	_spawn_slash()


func _spawn_slash() -> void:
	var slash := Line2D.new()
	var forward := Vector2(0.0, LUNGE_DISTANCE * facing)
	var tip := Vector2(0.0, -DISPLAY_HEIGHT * 0.45) + forward
	slash.points = PackedVector2Array([
		tip + Vector2(-18.0, -2.0 * facing),
		tip + Vector2(0.0, 10.0 * facing),
		tip + Vector2(18.0, -2.0 * facing),
	])
	slash.width = 3.2
	slash.default_color = SLASH_COLOR
	slash.z_index = 3
	add_child(slash)
	var tween := slash.create_tween()
	tween.tween_property(slash, "modulate:a", 0.0, 0.14)
	tween.tween_callback(slash.queue_free)


## Where shots leave the weapon, in the fighter's parent space.
func muzzle() -> Vector2:
	return position + Vector2(0.0, -DISPLAY_HEIGHT * (1.0 if facing < 0.0 else 0.35))


func chest() -> Vector2:
	return position + Vector2(0.0, -DISPLAY_HEIGHT * 0.55)


func fall(side_sign: float) -> void:
	alive = false
	z_index = -1
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_sprite, "position:y", _sprite.position.y - 12.0 * facing, FALL_SECONDS * 0.35)
	tween.chain().tween_property(_sprite, "position:y", 0.0, FALL_SECONDS * 0.65)
	tween.tween_property(_sprite, "rotation", deg_to_rad(80.0) * side_sign, FALL_SECONDS)
	tween.tween_property(_sprite, "modulate", HIT_FLASH_TINT, 0.07)
	tween.chain().tween_property(_sprite, "modulate", FALLEN_TINT, FALL_SECONDS - 0.07)


func surrender() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_sprite, "modulate", SURRENDER_TINT, FALL_SECONDS)
	tween.tween_property(_sprite, "scale:y", _sprite.scale.y * SURRENDER_SQUASH, FALL_SECONDS)
