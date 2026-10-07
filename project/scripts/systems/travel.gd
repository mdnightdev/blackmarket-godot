class_name Travel

enum Check { OK, ALREADY_HERE, NOT_ENOUGH_CASH }


static func fare(run: RunState, destination: DistrictDef) -> int:
	return roundi(destination.travel_cost * (1.0 - Gear.fare_discount(run)))


static func check(run: RunState, destination: DistrictDef) -> Check:
	if run.district_id == destination.id:
		return Check.ALREADY_HERE
	if run.cash < fare(run, destination):
		return Check.NOT_ENOUGH_CASH
	return Check.OK


## Pays the fare, moves the player and spends one phase. Returns true when a new day started.
## Callers must confirm check() returned OK first.
static func travel(run: RunState, destination: DistrictDef) -> bool:
	run.cash -= fare(run, destination)
	run.district_id = destination.id
	return Calendar.advance_phase(run)
