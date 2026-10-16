class_name Scouting

## Scouting a rival corner before hitting it. A scout costs cash and the rest of the phase, and comes back with a
## rough count of the men on the corner and what they carry. The true count is always inside the range. Ramos on the
## payroll narrows it. Sometimes the rival spots the scout and moves more men in, and the report says so. Reports
## go stale after a few days. run.scouted maps a corner id to { low, high, gear, day, seen }.

enum Result { OK, NOT_A_TARGET, NOT_ENOUGH_CASH }

const COST_PER_TIER := 1000
## Width of the reported range as a share of the true count.
const SPREAD := 0.8
const RAMOS_SPREAD := 0.2
const NOTICE_CHANCE := 0.25
## Share of the corner's crew the rival adds when it spots the scout.
const NOTICED_REINFORCEMENT := 0.25
## A report is good for the day it was made and this many days after.
const FRESH_DAYS := 2
## The player's strength over the estimated defence, best reading first. Below the last it reads "suicide".
const READINGS: Array[Dictionary] = [
	{ "at": 1.5, "label": "easy" },
	{ "at": 1.15, "label": "good odds" },
	{ "at": 0.9, "label": "even" },
	{ "at": 0.65, "label": "risky" },
]
const SUICIDE := "suicide"
const UNKNOWN := "unknown"


static func cost(corner: CornerDef) -> int:
	var district := Content.district(Corners.district_of(corner.id))
	return COST_PER_TIER * (district.tier if district != null else 1)


static func spread(run: RunState) -> float:
	return RAMOS_SPREAD if Ramos.is_asset(run) else SPREAD


## notice_roll decides whether the rival spots the scout, range_roll where the true count sits in the range. Both
## are in [0, 1).
static func scout(run: RunState, corner_id: StringName, notice_roll: float, range_roll: float) -> Result:
	var corner := Corners.find(corner_id)
	if corner == null or not War.is_target(run, corner):
		return Result.NOT_A_TARGET
	var price := cost(corner)
	if run.cash < price:
		return Result.NOT_ENOUGH_CASH
	run.cash -= price
	var seen := notice_roll < NOTICE_CHANCE
	if seen:
		var reinforced := War.defenders(run, corner) + ceili(corner.defenders * NOTICED_REINFORCEMENT)
		run.corner_defenders[String(corner_id)] = mini(reinforced, Rivals.max_garrison(corner))
		Heat.activate_frenzy(run, 180.0)
	var men := War.defenders(run, corner)
	var width := spread(run)
	var gang := Corners.gang_of(corner_id)
	var bell_roll := Odds.bell_from_roll(range_roll, 0.0, 0.5, 1.0)
	run.scouted[String(corner_id)] = {
		"low": floori(men * (1.0 - width * bell_roll)),
		"high": ceili(men * (1.0 + width * (1.0 - bell_roll))),
		"gear": Rivals.gear(run, gang) if gang != null else Armory.Grade.BLADE,
		"day": run.day,
		"seen": seen,
	}
	return Result.OK


## The corner's latest report while it is fresh, empty otherwise.
static func report(run: RunState, corner: CornerDef) -> Dictionary:
	var entry: Dictionary = run.scouted.get(String(corner.id), {})
	if entry.is_empty() or run.day - int(entry.day) > FRESH_DAYS:
		return {}
	return entry


## The weakest and strongest defence the report allows, as x and y.
static func power_range(corner: CornerDef, entry: Dictionary) -> Vector2:
	var per_man := Armory.power_of(int(entry.gear) as Armory.Grade) * Rivals.SKILL * (War.STRONGHOLD_FACTOR if corner.stronghold else 1.0)
	return Vector2(int(entry.low), int(entry.high)) * per_man


## The defence the report points to, from the middle of its range.
static func estimated_power(corner: CornerDef, entry: Dictionary) -> float:
	var bounds := power_range(corner, entry)
	return (bounds.x + bounds.y) / 2.0


## How sending the deployment against the corner looks from the latest report.
static func reading(run: RunState, corner: CornerDef, deployment: Dictionary) -> String:
	var entry := report(run, corner)
	if entry.is_empty():
		return UNKNOWN
	var ratio := Army.power(run, deployment) / maxf(estimated_power(corner, entry), 1.0)
	for step in READINGS:
		if ratio >= float(step.at):
			return str(step.label)
	return SUICIDE


static func sanitize(source: Variant) -> Dictionary:
	var clean := {}
	if not source is Dictionary:
		return clean
	for key: Variant in source:
		var entry: Variant = source[key]
		if Corners.find(StringName(str(key))) == null or not entry is Dictionary:
			continue
		var low := maxi(0, int(entry.get("low", 0)))
		clean[str(key)] = {
			"low": low,
			"high": maxi(low, int(entry.get("high", low))),
			"gear": clampi(int(entry.get("gear", Armory.Grade.BLADE)), Armory.Grade.BLADE, Armory.Grade.MILITARY),
			"day": maxi(0, int(entry.get("day", 0))),
			"seen": bool(entry.get("seen", false)),
		}
	return clean
