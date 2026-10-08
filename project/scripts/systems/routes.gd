class_name Routes

## Roads between districts and the danger waiting at each stop of a hot run.
## Danger depends on who is where this phase, so it is read from the Roster and never saved.

enum Threat { QUIET, POLICE, FAMILY, VEX }

const THREAT_NAMES: Array[String] = ["quiet", "police", "family crew", "Vex's crew"]
const MAX_STOPS := 4
const STREET_RISK := 0.04
const THREAT_RISK := { Threat.POLICE: 0.12, Threat.FAMILY: 0.15, Threat.VEX: 0.18 }
const HELD_FACTOR := 0.5
const RECON_FACTOR := 0.5
const MIN_RISK := 0.03
const MAX_RISK := 0.25
const MEDIUM_AT := 0.08
const HIGH_AT := 0.15
const RECON_COST := 150


## Every road path between two districts that never doubles back, at most MAX_STOPS stops long.
## A path lists the stops after the start and ends with the destination.
static func paths(from: StringName, to: StringName) -> Array[Array]:
	var found: Array[Array] = []
	var start: Array[StringName] = [from]
	_walk(start, to, found)
	return found


static func is_path(from: StringName, stops: Array[StringName], to: StringName) -> bool:
	return paths(from, to).any(func(path: Array) -> bool: return path == stops)


## The shortest route, then the safest one this phase when it is safer still.
static func options(run: RunState, from: StringName, to: StringName) -> Array[Array]:
	var all := paths(from, to)
	var picked: Array[Array] = []
	if all.is_empty():
		return picked
	var stamp := Calendar.stamp(run)
	var shortest: Array = all[0]
	var safest: Array = all[0]
	for path in all:
		var risk := route_risk(run, path, stamp)
		if path.size() < shortest.size() or (path.size() == shortest.size() and risk < route_risk(run, shortest, stamp)):
			shortest = path
		if risk < route_risk(run, safest, stamp) or (is_equal_approx(risk, route_risk(run, safest, stamp)) and path.size() < safest.size()):
			safest = path
	picked.append(shortest)
	if safest != shortest and route_risk(run, safest, stamp) < route_risk(run, shortest, stamp):
		picked.append(safest)
	return picked


## The chance of running into trouble at least once along the path.
static func route_risk(run: RunState, path: Array, stamp: int) -> float:
	var clear := 1.0
	for stop: StringName in path:
		clear *= 1.0 - stop_risk(run, stop, stamp)
	return 1.0 - clear


static func threat(run: RunState, district_id: StringName, stamp: int) -> Threat:
	if Roster.rival_in(run, district_id, stamp):
		return Threat.VEX
	if Families.hostile_family_in(run, district_id) != null:
		return Threat.FAMILY
	if Roster.strongest_patrol(run, district_id, stamp) != null and not Police.is_quiet(run) and not Police.just_stopped(run):
		return Threat.POLICE
	return Threat.QUIET


## The chance of an ambush on arriving at the district with a crate.
static func stop_risk(run: RunState, district_id: StringName, stamp: int) -> float:
	var district := Content.district(district_id)
	var risk := STREET_RISK * (district.heat_multiplier if district != null else 1.0)
	risk += float(THREAT_RISK.get(threat(run, district_id, stamp), 0.0))
	if Turf.holder(run, district_id) == Turf.Holder.PLAYER:
		risk *= HELD_FACTOR
	if has_recon(run):
		risk *= RECON_FACTOR
	return clampf(risk, MIN_RISK, MAX_RISK)


static func band(risk: float) -> String:
	if risk >= HIGH_AT:
		return "High"
	if risk >= MEDIUM_AT:
		return "Medium"
	return "Low"


## Recon names who is waiting at every stop for the rest of the phase and lets the player slip past the worst of it.
static func has_recon(run: RunState) -> bool:
	return run.recon_stamp == Calendar.stamp(run) or Crew.scouts_routes(run)


static func buy_recon(run: RunState) -> bool:
	if has_recon(run) or run.cash < RECON_COST:
		return false
	run.cash -= RECON_COST
	run.recon_stamp = Calendar.stamp(run)
	return true


## "Slums High" without recon, "Slums High, Vex's crew" with it.
static func describe_stop(run: RunState, district_id: StringName) -> String:
	var district := Content.district(district_id)
	var place := district.display_name if district != null else String(district_id)
	var stamp := Calendar.stamp(run)
	var text := "%s %s" % [place, band(stop_risk(run, district_id, stamp))]
	if has_recon(run):
		text += ", %s" % THREAT_NAMES[threat(run, district_id, stamp)]
	return text


static func describe_risk(run: RunState, path: Array) -> String:
	return "%s risk" % band(route_risk(run, path, Calendar.stamp(run)))


## Rolled on arriving anywhere with a crate. The roll must be in the range [0, 1).
static func ambush_due(run: RunState, roll: float) -> bool:
	return Smuggling.is_carrying(run) and roll < stop_risk(run, run.district_id, Calendar.stamp(run))


static func _walk(visited: Array[StringName], to: StringName, found: Array[Array]) -> void:
	if visited.size() > MAX_STOPS:
		return
	var district := Content.district(visited[-1])
	if district == null:
		return
	for next in district.roads:
		if visited.has(next):
			continue
		var path := visited.duplicate()
		path.append(next)
		if next == to:
			found.append(path.slice(1))
		else:
			_walk(path, to, found)
