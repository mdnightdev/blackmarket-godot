class_name Rivals

## The gangs the player takes corners from. Once Act 2 opens, every morning a rival banks part of what its corners
## pay, adds men to each corner it holds and buys better weapons when its war chest can pay for them. A rival left
## alone gets harder to hit. run.rivals maps a gang id to { chest, gear, last_strike_day }, missing until it changes.

## Share of each corner's rent and protection the rival keeps for the war.
const SAVINGS_SHARE := 0.25
## Each morning a corner gains this share of its starting crew, up to GARRISON_CAP times that crew.
const DAILY_GROWTH := 0.03
const GARRISON_CAP := 2.5
## What arming the whole crew with the grade costs the rival.
const GEAR_PRICES := {
	Armory.Grade.HANDGUN: 150000,
	Armory.Grade.RIFLE: 600000,
	Armory.Grade.MILITARY: 2000000,
}
## Gang fighters know the street and get more out of what they carry than the player's men.
const SKILL := 2.0


const ANGER_DECAY := 0.2
const MAX_ANGER := 20.0


static func state(run: RunState, gang: GangDef) -> Dictionary:
	var saved: Dictionary = run.rivals.get(gang.id, {})
	return {
		"chest": int(saved.get("chest", 0)),
		"gear": int(saved.get("gear", gang.gear)),
		"last_strike_day": int(saved.get("last_strike_day", 0)),
		"anger": clampf(float(saved.get("anger", 0.0)), 0.0, MAX_ANGER),
		"cop_bribe_until": maxi(0, int(saved.get("cop_bribe_until", 0))),
	}


static func gear(run: RunState, gang: GangDef) -> Armory.Grade:
	return state(run, gang).gear as Armory.Grade


static func chest(run: RunState, gang: GangDef) -> int:
	return int(state(run, gang).chest)


static func last_strike_day(run: RunState, gang: GangDef) -> int:
	return int(state(run, gang).last_strike_day)


static func anger(run: RunState, gang: GangDef) -> float:
	return float(state(run, gang).anger)


static func add_anger(run: RunState, gang: GangDef, delta: float) -> void:
	var next := clampf(anger(run, gang) + delta, 0.0, MAX_ANGER)
	_store_variant(run, gang, "anger", snappedf(next, 0.01))


static func cop_bribe_until(run: RunState, gang: GangDef) -> int:
	return int(state(run, gang).cop_bribe_until)


static func set_cop_bribe(run: RunState, gang: GangDef, until_day: int) -> void:
	_store(run, gang, "cop_bribe_until", maxi(0, until_day))


static func note_strike(run: RunState, gang: GangDef, day: int) -> void:
	_store(run, gang, "last_strike_day", day)


## What one of the gang's fighters is worth in a fight.
static func power_per_man(run: RunState, gang: GangDef) -> float:
	return Armory.power_of(gear(run, gang)) * SKILL


## Corners the gang still holds, across its whole turf.
static func corners(run: RunState, gang: GangDef) -> Array[CornerDef]:
	var held: Array[CornerDef] = []
	for district_id in gang.turf:
		for corner in Corners.of(district_id):
			if not Corners.holds(run, corner.id):
				held.append(corner)
	return held


static func max_garrison(corner: CornerDef) -> int:
	return ceili(corner.defenders * GARRISON_CAP)


## The next grade the gang saves for, or Grade.NONE once it carries the best.
static func next_gear(run: RunState, gang: GangDef) -> Armory.Grade:
	var current := gear(run, gang)
	for grade: Armory.Grade in GEAR_PRICES:
		if grade > current:
			return grade
	return Armory.Grade.NONE


## Grows every rival still in the city. Returns a notice for each one that bought better weapons.
static func morning(run: RunState) -> Array[Dictionary]:
	var notices: Array[Dictionary] = []
	if not Campaign.is_act_two(run):
		return notices
	for gang in Gangs.active(run):
		if grow(run, gang):
			notices.append({
				"line": "Word on the street: %s is carrying %s now." % [gang.crew_name, str(Armory.GRADE_NAMES[gear(run, gang)]).to_lower()],
				"hint": "Their corners just got harder to take.",
			})
	return notices


## One morning for the gang. Returns true when it bought better weapons.
static func grow(run: RunState, gang: GangDef) -> bool:
	if anger(run, gang) > 0.0:
		add_anger(run, gang, -ANGER_DECAY)
	var saved := 0
	for corner in corners(run, gang):
		saved += roundi(corner.daily_cut() * SAVINGS_SHARE)
		var grown := War.defenders(run, corner) + ceili(corner.defenders * DAILY_GROWTH)
		run.corner_defenders[String(corner.id)] = mini(grown, max_garrison(corner))
	var funds := chest(run, gang) + saved
	var upgraded := false
	var next := next_gear(run, gang)
	while next != Armory.Grade.NONE and funds >= int(GEAR_PRICES[next]):
		funds -= int(GEAR_PRICES[next])
		_store(run, gang, "gear", next)
		upgraded = true
		next = next_gear(run, gang)
	_store(run, gang, "chest", funds)
	return upgraded


static func _store(run: RunState, gang: GangDef, key: String, value: int) -> void:
	_store_variant(run, gang, key, value)


static func _store_variant(run: RunState, gang: GangDef, key: String, value: Variant) -> void:
	var entry := state(run, gang)
	entry[key] = value
	run.rivals[gang.id] = entry


static func sanitize(source: Variant) -> Dictionary:
	var clean := {}
	if not source is Dictionary:
		return clean
	for key: Variant in source:
		var gang := Content.gang(StringName(str(key)))
		var entry: Variant = source[key]
		if gang == null or not entry is Dictionary:
			continue
		clean[gang.id] = {
			"chest": maxi(0, int(entry.get("chest", 0))),
			"gear": clampi(int(entry.get("gear", gang.gear)), Armory.Grade.BLADE, Armory.Grade.MILITARY),
			"last_strike_day": maxi(0, int(entry.get("last_strike_day", 0))),
			"anger": clampf(float(entry.get("anger", 0.0)), 0.0, MAX_ANGER),
			"cop_bribe_until": maxi(0, int(entry.get("cop_bribe_until", 0))),
		}
	return clean
