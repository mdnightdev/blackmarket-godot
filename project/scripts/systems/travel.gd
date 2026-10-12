class_name Travel

enum Check { OK, ALREADY_HERE, NOT_ENOUGH_CASH, LOCKED }

const TRIP_SECONDS := 60.0
## Walking is free but eats most of a phase, so being broke costs time instead of stranding the player.
const WALK_SECONDS := 240.0


static func fare(run: RunState, destination: DistrictDef) -> int:
	return roundi(destination.travel_cost * (1.0 - Gear.fare_discount(run)))


## The fare for a trip between any two districts. Fares depend only on where the trip ends, and staying put is free.
static func trip_fare(run: RunState, from_id: StringName, destination: DistrictDef) -> int:
	return 0 if destination.id == from_id else fare(run, destination)


static func check(run: RunState, destination: DistrictDef, walking := false) -> Check:
	if run.district_id == destination.id:
		return Check.ALREADY_HERE
	if is_locked(run, destination):
		return Check.LOCKED
	if not walking and run.cash < fare(run, destination):
		return Check.NOT_ENOUGH_CASH
	return Check.OK


static func is_locked(run: RunState, destination: DistrictDef) -> bool:
	return StreetCred.rank(run) < destination.min_rank


## What the player still needs to reach the destination, empty when it is open.
static func lock_reason(run: RunState, destination: DistrictDef) -> String:
	if StreetCred.rank(run) < destination.min_rank:
		return "Needs %s rank" % StreetCred.rank_name(destination.min_rank)
	return ""


## Pays the fare, moves the player and spends TRIP_SECONDS of the phase clock. Walking pays nothing and spends WALK_SECONDS.
## Returns the seconds the trip ran past the end of the phase, 0 when it did not.
## Callers must confirm check() returned OK first.
static func travel(run: RunState, destination: DistrictDef, walking := false) -> float:
	if not walking:
		run.cash -= fare(run, destination)
	run.district_id = destination.id
	run.phase_seconds_left -= (WALK_SECONDS if walking else TRIP_SECONDS) * Edges.trip_factor(run)
	if run.phase_seconds_left > 0.0:
		return 0.0
	var overrun := -run.phase_seconds_left
	run.phase_seconds_left = 0.0
	return overrun
