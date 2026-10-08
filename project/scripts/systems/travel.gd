class_name Travel

enum Check { OK, ALREADY_HERE, NOT_ENOUGH_CASH, LOCKED }

const TRIP_SECONDS := 60.0


static func fare(run: RunState, destination: DistrictDef) -> int:
	return roundi(destination.travel_cost * (1.0 - Gear.fare_discount(run)))


## The fare for a trip between any two districts. Fares depend only on where the trip ends, and staying put is free.
static func trip_fare(run: RunState, from_id: StringName, destination: DistrictDef) -> int:
	return 0 if destination.id == from_id else fare(run, destination)


static func check(run: RunState, destination: DistrictDef) -> Check:
	if run.district_id == destination.id:
		return Check.ALREADY_HERE
	if is_locked(run, destination):
		return Check.LOCKED
	if run.cash < fare(run, destination):
		return Check.NOT_ENOUGH_CASH
	return Check.OK


static func is_locked(run: RunState, destination: DistrictDef) -> bool:
	return StreetCred.rank(run) < destination.min_rank or Turf.power(run) < destination.min_power


## What the player still needs to reach the destination, empty when it is open.
static func lock_reason(run: RunState, destination: DistrictDef) -> String:
	var needs: Array[String] = []
	if StreetCred.rank(run) < destination.min_rank:
		needs.append("%s rank" % StreetCred.rank_name(destination.min_rank))
	if Turf.power(run) < destination.min_power:
		needs.append("Power %d" % destination.min_power)
	return "Needs %s" % " and ".join(needs) if not needs.is_empty() else ""


## Pays the fare, moves the player and spends TRIP_SECONDS of the phase clock.
## Returns the seconds the trip ran past the end of the phase, 0 when it did not.
## Callers must confirm check() returned OK first.
static func travel(run: RunState, destination: DistrictDef) -> float:
	run.cash -= fare(run, destination)
	run.district_id = destination.id
	run.phase_seconds_left -= TRIP_SECONDS
	if run.phase_seconds_left > 0.0:
		return 0.0
	var overrun := -run.phase_seconds_left
	run.phase_seconds_left = 0.0
	return overrun
