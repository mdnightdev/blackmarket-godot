class_name Travel

enum Check { OK, ALREADY_HERE, NOT_ENOUGH_CASH, LOCKED }


static func fare(run: RunState, destination: DistrictDef) -> int:
	return roundi(destination.travel_cost * (1.0 - Gear.fare_discount(run)))


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


## Pays the fare, moves the player and spends one phase. Returns true when a new day started.
## Callers must confirm check() returned OK first.
static func travel(run: RunState, destination: DistrictDef) -> bool:
	run.cash -= fare(run, destination)
	run.district_id = destination.id
	return Calendar.advance_phase(run)
