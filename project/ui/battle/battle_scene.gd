class_name BattleScene
extends Control
## Plays out a fight that has already been decided. Each figure stands for a squad, and the falls,
## head counts and kill feed all follow the result carried by the two BattleSides.

signal finished

const MAX_FIGHTERS := 36
const MIN_FIGHTERS := 6
const COLUMNS := 6
const FIELD_LEFT := 175.0
const FIELD_RIGHT := 545.0
const ROW_GAP := 50.0
const JITTER := 9.0
const ENEMY_FRONT_Y := 400.0
const PLAYER_FRONT_Y := 930.0
const ENEMY_ADVANCE := 120.0
const PLAYER_ADVANCE := 70.0
const ADVANCE_SECONDS := 1.6
const FIGHT_SECONDS := 9.0
const CHARGE_SHARE := 0.4
const MELEE_GAP := 64.0
const FIRST_MELEE_LOSS := 0.4
const LAST_LOSS := 0.92
const SKILL_AT := 3.0
const SKILL_KILLS := 4
const SKILL_KILL_GAP := 0.16
const ACTION_GAP := 0.09
const LUNGE_CHANCE := 0.35
const RESULT_FADE_SECONDS := 0.4
const END_HOLD_SECONDS := 1.8
const FLASH_SECONDS := 0.12
const TRACER_SECONDS := 0.1
const TRACER_COLOR := Color(1.0, 0.86, 0.62, 0.75)
const LOSS_COLOR := Palette.RISK_HIGH

@onready var _field: Node2D = %Field
@onready var _hud: BattleHud = %Hud
@onready var _skill_banner: SkillBanner = %SkillBanner
@onready var _kill_feed: KillFeed = %KillFeed
@onready var _result: Label = %Result

var _rng := RandomNumberGenerator.new()
var _flash_texture := _make_flash_texture()
var _flash_material := CanvasItemMaterial.new()
var _player: _Army
var _enemy: _Army


func _ready() -> void:
	_flash_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_result.modulate.a = 0.0


func play(player_side: BattleSide, enemy_side: BattleSide, result_line: String, seed := 0) -> void:
	_rng.seed = seed
	var largest := maxi(player_side.head_count, enemy_side.head_count)
	_player = _Army.new(player_side, _fighter_count(player_side.head_count, largest))
	_enemy = _Army.new(enemy_side, _fighter_count(enemy_side.head_count, largest))
	_hud.show_sides(player_side, enemy_side)
	_deploy(_player, PLAYER_FRONT_Y, 1.0)
	_deploy(_enemy, ENEMY_FRONT_Y, -1.0)
	_advance(_player, -PLAYER_ADVANCE)
	_advance(_enemy, ENEMY_ADVANCE)
	await _wait(ADVANCE_SECONDS)

	_schedule_losses(_enemy, _player)
	_schedule_losses(_player, _enemy)
	for army: _Army in [_player, _enemy]:
		if not army.side.ranged:
			_charge(army, _player if army == _enemy else _enemy)
		if army.side.has_skill():
			get_tree().create_timer(SKILL_AT, false).timeout.connect(_skill_banner.announce.bind(army.side))

	var elapsed := 0.0
	while elapsed < FIGHT_SECONDS:
		_act(_player, _enemy)
		_act(_enemy, _player)
		await _wait(ACTION_GAP)
		elapsed += ACTION_GAP

	await _finish(result_line)


func _fighter_count(head_count: int, largest: int) -> int:
	var share := sqrt(float(head_count) / maxi(1, largest))
	return clampi(roundi(MAX_FIGHTERS * share), MIN_FIGHTERS, MAX_FIGHTERS)


## Lays an army out in rows behind its front line. direction is +1 for rows stacking downward.
func _deploy(army: _Army, front_y: float, direction: float) -> void:
	var rows := ceili(float(army.count) / COLUMNS)
	var squads := maxi(1, army.side.squad_names.size())
	for index in army.count:
		var row := floori(float(index) / COLUMNS)
		var column := index % COLUMNS
		var fighter := BattleFighter.new()
		fighter.setup(army.side.fighters[_rng.randi() % army.side.fighters.size()], direction > 0.0, army.side.team_color)
		fighter.squad = mini(floori(float(row * squads) / rows), squads - 1)
		var x := lerpf(FIELD_LEFT, FIELD_RIGHT, (column + 0.5) / COLUMNS) + _rng.randf_range(-JITTER, JITTER)
		var y := front_y + row * ROW_GAP * direction + _rng.randf_range(-JITTER, JITTER)
		fighter.position = Vector2(x, y)
		_field.add_child(fighter)
		army.fighters.append(fighter)


func _advance(army: _Army, distance: float) -> void:
	for fighter in army.fighters:
		fighter.march_to(fighter.position + Vector2(0.0, distance), ADVANCE_SECONDS, _rng.randf_range(0.0, 0.2))


func _charge(army: _Army, target: _Army) -> void:
	var target_front := target.front_y_toward(army)
	var line_y := target_front - MELEE_GAP * signf(target_front - army.center_y())
	var own_front := army.front_y_toward(target)
	for fighter in army.fighters:
		var goal := Vector2(fighter.position.x, line_y + _rng.randf_range(-JITTER, JITTER) * 3.0)
		var depth := absf(fighter.position.y - own_front) / ROW_GAP
		fighter.march_to(goal, FIGHT_SECONDS * CHARGE_SHARE, depth * 0.15)


## Times every fall so the field ends on the decided result. Losses land once the attacker can reach:
## at once for gunfire, after the charge for blades.
func _schedule_losses(army: _Army, attacker: _Army) -> void:
	var falls := army.planned_falls()
	if falls == 0:
		return
	var start := 0.08 if attacker.side.ranged else FIRST_MELEE_LOSS
	var times: Array[float] = []
	for index in falls:
		times.append(FIGHT_SECONDS * lerpf(start, LAST_LOSS, (index + _rng.randf()) / falls))
	if attacker.side.has_skill():
		for index in mini(SKILL_KILLS, falls):
			times[index] = SKILL_AT + 0.3 + index * SKILL_KILL_GAP
	times.sort()
	var order := army.fall_order(_rng, attacker)
	for index in falls:
		var share := army.loss_share(index, falls)
		get_tree().create_timer(times[index], false).timeout.connect(_fall.bind(army, order[index], share))


func _fall(army: _Army, fighter: BattleFighter, share: int) -> void:
	fighter.fall(-1.0 if _rng.randf() < 0.5 else 1.0)
	FloatingNumber.spawn(_field, fighter.chest(), "-%d" % share, LOSS_COLOR)
	army.shown -= share
	_hud.set_counts(_player.shown, _enemy.shown)
	if army == _enemy and army.squad_wiped(fighter.squad):
		var names := army.side.squad_names
		if fighter.squad < names.size():
			_kill_feed.add_entry("%s eliminated" % names[fighter.squad], army.side.color)


func _act(army: _Army, target: _Army) -> void:
	var shooter := army.random_alive(_rng)
	var victim := target.random_alive(_rng)
	if shooter == null or victim == null:
		return
	if army.side.ranged:
		_shoot(shooter, victim)
	elif _rng.randf() < LUNGE_CHANCE:
		shooter.lunge()


func _shoot(shooter: BattleFighter, victim: BattleFighter) -> void:
	var from := shooter.muzzle()
	var flash := Sprite2D.new()
	flash.texture = _flash_texture
	flash.material = _flash_material
	flash.position = from
	flash.z_index = 5
	_field.add_child(flash)
	var flash_tween := flash.create_tween().set_parallel(true)
	flash_tween.tween_property(flash, "scale", Vector2.ONE * 1.4, FLASH_SECONDS).from(Vector2.ONE * 0.6)
	flash_tween.tween_property(flash, "modulate:a", 0.0, FLASH_SECONDS)
	flash_tween.chain().tween_callback(flash.queue_free)

	var tracer := Line2D.new()
	tracer.points = PackedVector2Array([from, victim.chest()])
	tracer.width = 1.6
	tracer.default_color = TRACER_COLOR
	tracer.z_index = 4
	_field.add_child(tracer)
	var tracer_tween := tracer.create_tween()
	tracer_tween.tween_property(tracer, "modulate:a", 0.0, TRACER_SECONDS)
	tracer_tween.tween_callback(tracer.queue_free)


func _finish(result_line: String) -> void:
	var loser := _enemy if _enemy.survival_share() < _player.survival_share() else _player
	for fighter in loser.fighters:
		if fighter.alive:
			fighter.surrender()
	_hud.set_counts(_player.side.survivors, _enemy.side.survivors)
	_result.text = result_line
	create_tween().tween_property(_result, "modulate:a", 1.0, RESULT_FADE_SECONDS)
	await _wait(END_HOLD_SECONDS)
	finished.emit()


func _wait(seconds: float) -> Signal:
	return get_tree().create_timer(seconds, false).timeout


static func _make_flash_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.93, 0.72, 1.0))
	gradient.set_color(1, Color(1.0, 0.55, 0.25, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 28
	texture.height = 28
	return texture


class _Army:
	var side: BattleSide
	var count := 0
	var shown := 0
	var fighters: Array[BattleFighter] = []

	func _init(battle_side: BattleSide, fighter_count: int) -> void:
		side = battle_side
		count = fighter_count
		shown = battle_side.head_count

	func planned_falls() -> int:
		if side.losses() <= 0:
			return 0
		if side.survivors <= 0:
			return count
		return clampi(roundi(count * float(side.losses()) / side.head_count), 1, count - 1)

	## Whole-number share of the losses for the index-th fall, so the shares add up to the exact losses.
	func loss_share(index: int, falls: int) -> int:
		var total := float(side.losses())
		return floori(total * (index + 1) / falls) - floori(total * index / falls)

	## Gunfire cuts squads down in order, front squad first. Blades take whoever stands nearest.
	func fall_order(rng: RandomNumberGenerator, attacker: _Army) -> Array[BattleFighter]:
		var order: Array[BattleFighter] = fighters.duplicate()
		for index in range(order.size() - 1, 0, -1):
			var swap := rng.randi_range(0, index)
			var held := order[index]
			order[index] = order[swap]
			order[swap] = held
		if attacker.side.ranged:
			order.sort_custom(func(a: BattleFighter, b: BattleFighter) -> bool: return a.squad < b.squad)
		else:
			var front := front_y_toward(attacker)
			order.sort_custom(func(a: BattleFighter, b: BattleFighter) -> bool:
				return absf(a.position.y - front) < absf(b.position.y - front))
		return order

	func center_y() -> float:
		var sum := 0.0
		for fighter in fighters:
			sum += fighter.position.y
		return sum / maxi(1, fighters.size())

	## The edge of the formation facing the other army.
	func front_y_toward(other: _Army) -> float:
		var nearest := center_y()
		var other_center := other.center_y()
		for fighter in fighters:
			if absf(fighter.position.y - other_center) < absf(nearest - other_center):
				nearest = fighter.position.y
		return nearest

	func random_alive(rng: RandomNumberGenerator) -> BattleFighter:
		var alive := fighters.filter(func(fighter: BattleFighter) -> bool: return fighter.alive)
		return alive[rng.randi() % alive.size()] if not alive.is_empty() else null

	func squad_wiped(squad: int) -> bool:
		return fighters.all(func(fighter: BattleFighter) -> bool: return fighter.squad != squad or not fighter.alive)

	func survival_share() -> float:
		return float(side.survivors) / maxi(1, side.head_count)
