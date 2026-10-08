class_name Smuggling

## Crate runs posted at Pier 9. A crate is stored as
## { id, destination, slots, pay, lead, due } where lead is the phases allowed once taken,
## and due is the last phase stamp to deliver in (-1 until the crate is taken).

enum Result { OK, CARRYING, NO_ROOM, TAKEN, BANNED }

const CRATE_ICON: Texture2D = preload("res://assets/items/sealed_crate.jpg")
const VENUE: StringName = &"docks"
const ORIGIN: StringName = &"docks"
const POSTED_PER_DAY := 3
const MIN_SLOTS := 4
const MAX_SLOTS := 8
## A sealed crate draws police attention like a bag of risky goods.
const RISK_PER_SLOT := 60
const MIN_PAY_PER_SLOT := 90
const MAX_PAY_PER_SLOT := 130
## Pay grows with the map distance the crate has to travel.
const DISTANCE_BONUS := 2.5
const PAY_ROUNDING := 10
const MIN_LEAD_PHASES := 2
const MAX_LEAD_PHASES := 4


## Today's crates on offer. They come from the run seed, so a reload cannot reroll them.
static func board(run: RunState) -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	var origin := Content.district(ORIGIN)
	var destinations := _destinations(run)
	if is_banned(run) or origin == null or destinations.is_empty():
		return offers
	for index in POSTED_PER_DAY:
		var offer := _post(run, run.day - 1, index, origin, destinations)
		if not run.taken_crates.has(offer.id):
			offers.append(offer)
	return offers


static func check_accept(run: RunState, offer: Dictionary) -> Result:
	if is_banned(run):
		return Result.BANNED
	if is_carrying(run):
		return Result.CARRYING
	if run.taken_crates.has(offer.id):
		return Result.TAKEN
	if Inventory.free_space(run) < int(offer.slots):
		return Result.NO_ROOM
	return Result.OK


static func accept(run: RunState, offer: Dictionary) -> Result:
	var result := check_accept(run, offer)
	if result != Result.OK:
		return result
	var crate := offer.duplicate()
	crate.due = Calendar.stamp(run) + int(offer.lead)
	run.crate = crate
	run.taken_crates.append(str(offer.id))
	return Result.OK


static func is_carrying(run: RunState) -> bool:
	return not run.crate.is_empty()


static func is_banned(run: RunState) -> bool:
	return run.smuggling_ban_day == run.day


static func slots_used(run: RunState) -> int:
	return int(run.crate.get("slots", 0))


static func carried_risk(run: RunState) -> int:
	return roundi(slots_used(run) * RISK_PER_SLOT * Skills.crate_risk_factor(run))


## What the police treat the crate as being worth when pricing a bribe.
static func carried_value(run: RunState) -> int:
	return int(run.crate.get("pay", 0))


static func destination(crate: Dictionary) -> DistrictDef:
	return Content.district(StringName(str(crate.get("destination", ""))))


## Where the crate goes and by when, for row captions.
static func describe(crate: Dictionary) -> String:
	var place := destination(crate)
	var place_name := place.display_name if place != null else "the drop"
	if int(crate.get("due", -1)) < 0:
		return "To %s within %d phases" % [place_name, int(crate.get("lead", MIN_LEAD_PHASES))]
	return "To %s by %s" % [place_name, Calendar.describe(int(crate.due)).to_lower()]


static func can_deliver(run: RunState) -> bool:
	return is_carrying(run) \
		and run.district_id == StringName(run.crate.destination) \
		and int(run.crate.due) >= Calendar.stamp(run)


## Hands the crate over and returns the pay, or 0 when it cannot be delivered here.
static func deliver(run: RunState) -> int:
	if not can_deliver(run):
		return 0
	var pay := payout(run, run.crate)
	run.cash += pay
	run.profit += pay
	run.crate = {}
	StreetCred.add(run, StreetCred.CRATE_DELIVERED)
	return pay


## What delivering the crate pays, after the Smuggler skill.
static func payout(run: RunState, crate: Dictionary) -> int:
	return roundi(int(crate.get("pay", 0)) * (1.0 + Skills.crate_pay_bonus(run)))


## The police took the crate. Voronin gives no more work today.
static func seize(run: RunState) -> bool:
	if not is_carrying(run):
		return false
	run.crate = {}
	run.smuggling_ban_day = run.day
	StreetCred.add(run, StreetCred.CRATE_LOST)
	return true


## Drops a crate whose deadline has passed and returns it, or an empty dictionary.
static func expire(run: RunState) -> Dictionary:
	var today := "%d" % (run.day - 1)
	run.taken_crates = run.taken_crates.filter(func(id: String) -> bool: return id.get_slice(":", 1) == today)
	if not is_carrying(run) or int(run.crate.due) >= Calendar.stamp(run):
		return {}
	var lost := run.crate
	run.crate = {}
	run.smuggling_ban_day = run.day
	StreetCred.add(run, StreetCred.CRATE_LOST)
	return lost


static func sanitize(source: Dictionary) -> Dictionary:
	if source.is_empty():
		return {}
	return {
		"id": str(source.get("id", "")),
		"destination": str(source.get("destination", "")),
		"slots": clampi(int(source.get("slots", MIN_SLOTS)), MIN_SLOTS, MAX_SLOTS),
		"pay": maxi(0, int(source.get("pay", 0))),
		"lead": clampi(int(source.get("lead", MIN_LEAD_PHASES)), MIN_LEAD_PHASES, MAX_LEAD_PHASES),
		"due": int(source.get("due", -1)),
	}


static func _destinations(run: RunState) -> Array[DistrictDef]:
	var list: Array[DistrictDef] = []
	for district in Content.districts():
		if district.id != ORIGIN and not Travel.is_locked(run, district):
			list.append(district)
	list.sort_custom(func(a: DistrictDef, b: DistrictDef) -> bool: return String(a.id) < String(b.id))
	return list


static func _post(run: RunState, day_index: int, index: int, origin: DistrictDef, destinations: Array[DistrictDef]) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run.price_seed, &"crate", day_index, index])
	var target := destinations[rng.randi_range(0, destinations.size() - 1)]
	var slots := rng.randi_range(MIN_SLOTS, MAX_SLOTS)
	var distance := origin.map_position.distance_to(target.map_position)
	var pay := slots * rng.randi_range(MIN_PAY_PER_SLOT, MAX_PAY_PER_SLOT) * (1.0 + distance * DISTANCE_BONUS)
	return {
		"id": "crate:%d:%d" % [day_index, index],
		"destination": String(target.id),
		"slots": slots,
		"pay": roundi(pay / PAY_ROUNDING) * PAY_ROUNDING,
		"lead": rng.randi_range(MIN_LEAD_PHASES, MAX_LEAD_PHASES),
		"due": -1,
	}
