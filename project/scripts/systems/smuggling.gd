class_name Smuggling

## Crate runs posted at Pier 9. A crate is stored as
## { id, destination, slots, pay, lead, due, route, stop, off_route, invoice, skimmed, tolls, fragile } where lead is the phases
## allowed once taken, due is the last phase stamp to deliver in (-1 until the crate is taken), route lists the
## stops the player agreed to take ending at the destination, stop is the index of the next one, off_route is set
## once the player strays from it, invoice means the buyer pays later instead of cash on delivery, and skimmed is
## the share of the cargo lost to ambushes, tolls is the cash paid to ambushes along the way. A fragile crate loses
## twice as much to each ambush.

enum Result { OK, CARRYING, NO_ROOM, TAKEN, BANNED, NO_ROUTE }

const CRATE_ICON: Texture2D = preload("res://assets/items/sealed_crate.jpg")
const VENUE: StringName = &"docks"
const ORIGIN: StringName = &"docks"
const POSTED_PER_DAY := 3
const MIN_SLOTS := 4
const MAX_SLOTS := 8
## A sealed crate draws police attention like a bag of risky goods.
const RISK_PER_SLOT := 60
## Crates pay the destination district's job rate, more for a long haul across the map.
const DISTANCE_BONUS := 0.8
const PAY_ROUNDING := 10
const MIN_LEAD_PHASES := 2
const MAX_LEAD_PHASES := 4
## Share of the pay Voronin still hands over when the crate strayed from the agreed route.
const OFF_ROUTE_PAY := 0.6
## Share of the pay when the buyer comes out to meet the player at a stop short of the destination.
const HALFWAY_PAY := 0.7
## Most of a job's pay ambushes can take, skimmed cargo and tolls together, however many times the run goes wrong.
const MAX_LOSS := 0.35
const CLIENT := "Voronin's buyer"
const FRAGILE_SKIM := 2.0


## Today's crates on offer. They come from the run seed, so a reload cannot reroll them.
## The last one always goes beyond Pier 9's neighbours when such a district is open, so there is a route to plan.
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


## The route must be a road path from Pier 9 to the destination. An empty route takes the shortest one.
## origin is where the crate is handed over: Pier 9, or wherever Voronin's runner meets the player.
static func accept(run: RunState, offer: Dictionary, route: Array[StringName] = [], invoice := false, origin := ORIGIN) -> Result:
	var result := check_accept(run, offer)
	if result != Result.OK:
		return result
	var target := StringName(str(offer.destination))
	if target == origin:
		return Result.NO_ROUTE
	var stops: Array[StringName] = route.duplicate()
	if stops.is_empty():
		var options := Routes.options(run, origin, target)
		if not options.is_empty():
			stops.assign(options[0])
	elif not Routes.is_path(origin, stops, target):
		return Result.NO_ROUTE
	var crate := offer.duplicate()
	crate.due = Calendar.stamp(run) + int(offer.lead)
	crate.route = Array(stops).map(func(stop: StringName) -> String: return String(stop))
	crate.stop = 0
	crate.off_route = false
	crate.invoice = invoice
	run.crate = crate
	run.taken_crates.append(str(offer.id))
	return Result.OK


## Moves the run along when the player reaches the next stop, and marks it off route when they go elsewhere.
static func record_stop(run: RunState) -> void:
	if not is_carrying(run):
		return
	var route: Array = run.crate.get("route", [])
	var stop := int(run.crate.get("stop", 0))
	if stop >= route.size():
		return
	if StringName(str(route[stop])) == run.district_id:
		run.crate.stop = stop + 1
	else:
		run.crate.off_route = true


## Swaps the stops still ahead for another road path to the destination, for a detour around a roadblock.
## A detour agreed this way is not straying from the route.
static func reroute(run: RunState, stops: Array[StringName]) -> bool:
	if not is_carrying(run) or not Routes.is_path(run.district_id, stops, StringName(str(run.crate.destination))):
		return false
	var route: Array = run.crate.get("route", [])
	var kept := route.slice(0, int(run.crate.get("stop", 0)))
	kept.append_array(Array(stops).map(func(stop: StringName) -> String: return String(stop)))
	run.crate.route = kept
	return true


## Stops still ahead on the agreed route, ending with the destination.
static func stops_left(crate: Dictionary) -> Array[StringName]:
	var left: Array[StringName] = []
	var route: Array = crate.get("route", [])
	for index in range(int(crate.get("stop", 0)), route.size()):
		left.append(StringName(str(route[index])))
	return left


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


## The stops still ahead with their danger, then the deadline. For a crate being carried.
static func describe_route(run: RunState, crate: Dictionary) -> String:
	var left := stops_left(crate)
	var text := describe(crate)
	if not left.is_empty():
		var stops: PackedStringArray = []
		for stop in left:
			stops.append(Routes.describe_stop(run, stop))
		text = "Next %s. Due by %s" % [", then ".join(stops), Calendar.describe(int(crate.get("due", -1))).to_lower()]
	if bool(crate.get("off_route", false)):
		text = "Off route, pay cut. " + text
	if float(crate.get("skimmed", 0.0)) > 0.0:
		text = "Cargo skimmed. " + text
	if is_invoiced(crate):
		text += ". Invoice, paid %d days after delivery" % Invoices.DAYS_TO_PAY
	return text


static func can_deliver(run: RunState) -> bool:
	return is_carrying(run) \
		and run.district_id == StringName(run.crate.destination) \
		and int(run.crate.due) >= Calendar.stamp(run)


## The buyer can come out to any stop already reached on the agreed route, short of the destination.
static func can_meet_halfway(run: RunState) -> bool:
	if not is_carrying(run) or can_deliver(run) or int(run.crate.due) < Calendar.stamp(run):
		return false
	var route: Array = run.crate.get("route", [])
	var stop := int(run.crate.get("stop", 0))
	return stop >= 1 and stop < route.size() and StringName(str(route[stop - 1])) == run.district_id


static func is_invoiced(crate: Dictionary) -> bool:
	return bool(crate.get("invoice", false))


## Hands the crate over and returns the pay, or 0 when it cannot be delivered here.
## On an invoice the pay is owed rather than paid.
static func deliver(run: RunState) -> int:
	if not can_deliver(run):
		return 0
	return _hand_over(run, payout(run, run.crate))


## Hands the crate to the buyer at this stop for less pay. Returns the pay, or 0 when there is no meeting here.
static func meet_halfway(run: RunState) -> int:
	if not can_meet_halfway(run):
		return 0
	return _hand_over(run, payout(run, run.crate, true))


## What the crate pays, after the Smuggler skill, any cut for straying or meeting halfway, and the invoice bonus.
static func payout(run: RunState, crate: Dictionary, halfway := false) -> int:
	var pay := int(crate.get("pay", 0)) * (1.0 + Skills.crate_pay_bonus(run))
	if bool(crate.get("off_route", false)):
		pay *= OFF_ROUTE_PAY
	if halfway:
		pay *= HALFWAY_PAY
	pay *= 1.0 - float(crate.get("skimmed", 0.0))
	if is_invoiced(crate):
		pay *= 1.0 + Invoices.PAY_BONUS
	return roundi(pay)


static func _hand_over(run: RunState, pay: int) -> int:
	if is_invoiced(run.crate):
		Invoices.file(run, "invoice:%s" % run.crate.id, CLIENT, pay)
	else:
		run.cash += pay
		run.profit += pay
	run.crate = {}
	StreetCred.add(run, StreetCred.CRATE_DELIVERED)
	return pay


## The share of the pay ambushes can still take from this crate before MAX_LOSS is reached.
static func loss_room(crate: Dictionary) -> float:
	var pay := int(crate.get("pay", 0))
	var tolls := float(crate.get("tolls", 0)) / pay if pay > 0 else 0.0
	return maxf(0.0, MAX_LOSS - float(crate.get("skimmed", 0.0)) - tolls)


## The most an ambush can ask in cash without passing MAX_LOSS.
static func toll_room(crate: Dictionary) -> int:
	return floori(loss_room(crate) * int(crate.get("pay", 0)))


static func record_toll(run: RunState, paid: int) -> void:
	if is_carrying(run) and paid > 0:
		run.crate.tolls = int(run.crate.get("tolls", 0)) + paid


## An ambush pulled part of the cargo out, never past MAX_LOSS with the tolls already paid.
static func skim(run: RunState, share: float) -> void:
	if is_carrying(run):
		var taken := share * (FRAGILE_SKIM if bool(run.crate.get("fragile", false)) else 1.0)
		run.crate.skimmed = float(run.crate.get("skimmed", 0.0)) + minf(taken, loss_room(run.crate))


## The crate was lost to the police. Voronin gives no more work today.
static func seize(run: RunState) -> bool:
	if not is_carrying(run):
		return false
	Journal.mark_failed(run, str(run.crate.id))
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
	var target := str(source.get("destination", ""))
	var route: Array[String] = []
	var saved_route: Variant = source.get("route", [])
	if saved_route is Array:
		for stop: Variant in saved_route:
			if Content.district(StringName(str(stop))) != null:
				route.append(str(stop))
	if route.is_empty() or route[-1] != target:
		route = [target]
	return {
		"id": str(source.get("id", "")),
		"destination": target,
		"slots": clampi(int(source.get("slots", MIN_SLOTS)), MIN_SLOTS, MAX_SLOTS),
		"pay": maxi(0, int(source.get("pay", 0))),
		"lead": clampi(int(source.get("lead", MIN_LEAD_PHASES)), MIN_LEAD_PHASES, MAX_LEAD_PHASES),
		"due": int(source.get("due", -1)),
		"route": route,
		"stop": clampi(int(source.get("stop", 0)), 0, route.size()),
		"off_route": bool(source.get("off_route", false)),
		"invoice": bool(source.get("invoice", false)),
		"skimmed": clampf(float(source.get("skimmed", 0.0)), 0.0, MAX_LOSS),
		"tolls": clampi(int(source.get("tolls", 0)), 0, maxi(0, int(source.get("pay", 0)))),
		"fragile": bool(source.get("fragile", false)),
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
	var pool := destinations
	if index == POSTED_PER_DAY - 1:
		var far := destinations.filter(func(district: DistrictDef) -> bool: return not origin.roads.has(district.id))
		if not far.is_empty():
			pool = far
	var target: DistrictDef = pool[rng.randi_range(0, pool.size() - 1)]
	var slots := rng.randi_range(MIN_SLOTS, MAX_SLOTS)
	var distance := origin.map_position.distance_to(target.map_position)
	var pay := PayScale.roll(rng, run, target.tier) * (1.0 + distance * DISTANCE_BONUS)
	return {
		"id": "crate:%d:%d" % [day_index, index],
		"destination": String(target.id),
		"slots": slots,
		"pay": roundi(pay / PAY_ROUNDING) * PAY_ROUNDING,
		"lead": rng.randi_range(MIN_LEAD_PHASES, MAX_LEAD_PHASES),
		"due": -1,
	}
