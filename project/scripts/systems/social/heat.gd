class_name Heat

## Calm, then Noticed: stops get likelier. Watched: Officer Brandt follows the player between districts.
## Wanted, at the top: Brandt raids. Only loud moves make the player hot: escapes, fights, hijacks, heists and wars.
## Buying, selling and travelling with goods add nothing. Carrying still draws stops, see Police.stop_chance.
enum Level { CALM, NOTICED, WATCHED, WANTED }

const LEVEL_NAMES := {
	Level.CALM: "Calm",
	Level.NOTICED: "Noticed",
	Level.WATCHED: "Watched",
	Level.WANTED: "Wanted",
}
const MAX := 100
## From here the player counts as hot: the top bar warns and Lexie explains it.
const NOTICED := 30
const WATCHED := 60
const DECAY_PER_PHASE := 4
const OVERNIGHT_DECAY := 6


static func carried_risk(run: RunState) -> int:
	var total := Smuggling.carried_risk(run)
	for item_id: StringName in run.inventory:
		var item := Content.item(item_id)
		if item != null:
			total += item.risk * int(run.inventory[item_id])
	return total


static func level(run: RunState) -> Level:
	if run.heat >= MAX:
		return Level.WANTED
	if run.heat >= WATCHED or run.heat_timer > 180.0:
		return Level.WATCHED
	if run.heat >= NOTICED or run.heat_timer > 0.0:
		return Level.NOTICED
	return Level.CALM


static func level_name(run: RunState) -> String:
	return LEVEL_NAMES[level(run)]


static func add(run: RunState, amount: int) -> void:
	run.heat = clampi(run.heat + amount, 0, MAX)


static func cool_down(run: RunState, new_day_started: bool) -> void:
	add(run, -(DECAY_PER_PHASE + Skills.extra_cooling(run) + (OVERNIGHT_DECAY if new_day_started else 0)))


static func is_maxed(run: RunState) -> bool:
	return run.heat >= MAX


static func activate_frenzy(run: RunState, duration: float) -> void:
	run.heat_timer = maxf(run.heat_timer, duration)


static func tick_frenzy(run: RunState, delta: float) -> void:
	if run.heat_timer > 0.0:
		run.heat_timer = maxf(0.0, run.heat_timer - delta)
