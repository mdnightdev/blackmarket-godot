class_name Roadblocks

## Police roadblocks on the roads into a district. Each district rolls once a day from the run seed, so a reload
## cannot change them: most days the roads stay open, some days a roadblock goes up for two phases or until night ends.
## They only stop a player carrying a crate, who can push through, lie low until it clears or take a detour.
## Without recon the player only hears about roadblocks next door; recon shows every one and when it clears.

const DAILY_CHANCE := 0.15
const SHORT_PHASES := 2
const ALL_DAY_CHANCE := 0.4
## Chance of a police stop when pushing through.
const PUSH_RISK := 0.3


## The last phase stamp the roadblock holds, or -1 when the roads into the district are open at that stamp.
static func last_blocked_stamp(run: RunState, district_id: StringName, stamp: int) -> int:
	var phases := RunState.Phase.size()
	var day_index := floori(float(stamp) / phases)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run.price_seed, &"roadblock", district_id, day_index])
	if rng.randf() >= DAILY_CHANCE:
		return -1
	var first := rng.randi_range(0, phases - 1)
	var last := phases - 1 if rng.randf() < ALL_DAY_CHANCE else mini(first + SHORT_PHASES - 1, phases - 1)
	var phase := stamp % phases
	if phase < first or phase > last:
		return -1
	return day_index * phases + last


static func push_risk(run: RunState) -> float:
	return PUSH_RISK * Edges.push_risk_factor(run)


static func blocks(run: RunState, district_id: StringName) -> bool:
	return last_blocked_stamp(run, district_id, Calendar.stamp(run)) >= 0


## True when a trip there with a crate runs into a roadblock and needs the player's answer.
static func stops_crate(run: RunState, destination: DistrictDef) -> bool:
	return Smuggling.is_carrying(run) and destination.id != run.district_id and blocks(run, destination.id)


static func is_known(run: RunState, district_id: StringName) -> bool:
	if Routes.has_recon(run) or district_id == run.district_id:
		return true
	var here := Content.district(run.district_id)
	return here != null and here.roads.has(district_id)


## When the roadblock lifts, for example "Night, day 3". Only recon knows.
static func clears_at(run: RunState, district_id: StringName) -> String:
	var last := last_blocked_stamp(run, district_id, Calendar.stamp(run))
	return Calendar.describe(last + 1).to_lower() if last >= 0 else ""


## The shortest open road path from here to the crate's destination that avoids every roadblock this phase.
## Empty when the roadblock sits on the destination itself or no clear path exists.
static func detour(run: RunState, blocked: DistrictDef) -> Array[StringName]:
	var stops: Array[StringName] = []
	if not Smuggling.is_carrying(run):
		return stops
	var target := StringName(str(run.crate.destination))
	if blocked.id == target:
		return stops
	var best: Array = []
	for path in Routes.paths(run.district_id, target):
		if path.has(blocked.id) or path.any(func(stop: StringName) -> bool:
				return blocks(run, stop) or Travel.is_locked(run, Content.district(stop))):
			continue
		if best.is_empty() or path.size() < best.size():
			best = path
	stops.assign(best)
	return stops
