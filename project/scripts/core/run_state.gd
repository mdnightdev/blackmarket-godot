class_name RunState
extends RefCounted

enum Phase { MORNING, NOON, EVENING, NIGHT }
enum Outcome { ONGOING, WON, LOST }

const PHASE_NAMES: Array[String] = ["Morning", "Noon", "Evening", "Night"]
const STARTING_CASH := 2000
const STARTING_DEBT := 100000
const STARTING_DISTRICT: StringName = &"old_market"
const DEFAULT_PLAYER: StringName = &"kade"
const LEGACY_LOCKBOX: StringName = &"safehouse_lockbox"

var player_id: StringName = DEFAULT_PLAYER
var price_seed: int = randi()
var day: int = 1
var phase: Phase = Phase.MORNING
var phase_seconds_left: float = Calendar.PHASE_SECONDS
var cash: int = STARTING_CASH
var debt: int = STARTING_DEBT
var heat: int = 0
var district_id: StringName = STARTING_DISTRICT
var tutorial_step: int = 0
var tutorial_completed := false
## Item id to units carried.
var inventory: Dictionary = {}
## Item id to units stored in the safehouse stash.
var stash: Dictionary = {}
## Index into Safehouse.UPGRADES plus one. 0 means the safehouse has no stash yet.
var stash_level: int = 0
## Cash kept in the safehouse. Raids, muggings and enforcers only take carried cash.
var stashed_cash: int = 0
## Item id to average price paid per unit, for goods currently held.
var cost_basis: Dictionary = {}
var gear: Array[StringName] = []
## Dealer id to the phase stamp in which that dealer refused to trade.
var walked_out: Dictionary = {}
## Temporary price changes from street events. See StreetEvents for the entry layout.
var market_shifts: Array[Dictionary] = []
## Prices the player has seen at each dealer. See PriceIntel for the entry layout.
var price_sightings: Array[Dictionary] = []
## Accepted bar orders. See Orders for the entry layout.
var orders: Array[Dictionary] = []
## Ids of today's board offers the player already took, so they leave the board.
var taken_orders: Array[String] = []
## Venue id to the phase stamp its rumour was bought in.
var rumors_heard: Dictionary = {}
## The smuggling crate being carried, empty when none. See Smuggling for the layout.
var crate: Dictionary = {}
## Ids of today's crates the player already took.
var taken_crates: Array[String] = []
## Day on which Voronin stopped giving the player work. 0 means never.
var smuggling_ban_day: int = 0
## Phase stamp of the last police stop.
var stop_stamp: int = -1
## Phase stamp of the last raid or failed escape.
var arrest_stamp: int = -1
## Phase stamp of the last paid route recon.
var recon_stamp: int = -1
## Real seconds left in a cell after choosing jail at a police stop.
var jail_seconds_left: float = 0.0
## Phase stamp of the last hijack attempt.
var hijacked_stamp: int = -1
## District id to the player's turf share. Missing districts use the Turf defaults.
var turf: Dictionary = {}
## Phase stamp in which muscle was last sent.
var muscle_stamp: int = -1
## True once Vex has been driven out of the city.
var vex_gone := false
## Rises each time the player ignores Vex's crew. At Vex.MAX_ANGER she hunts the player.
var vex_anger: int = 0
## Phase stamp in which the Fixer last cleaned up the player's heat.
var cleanup_stamp: int = -1
## Family id to the player's standing. See Families.
var family_standing: Dictionary = {}
## Accepted family deliveries. See Favours for the entry layout.
var favours: Array[Dictionary] = []
## Ids of today's favour offers the player already took.
var taken_favours: Array[String] = []
## Phase stamp in which Hana last sold a price hack.
var hack_stamp: int = -1
## The encounter waiting for the player's answer. Saved so closing the app cannot dodge it.
var pending_encounter: Dictionary = {}
## True once the Shark is paid off. Crew, businesses and heists open up.
var career := false
var street_cred: int = 0
## Day that trading_cred_today counts for.
var cred_day: int = 0
var trading_cred_today: int = 0
## Skill id to rank bought. See Skills.
var skills: Dictionary = {}
## District id to the turf level bought there. Holding a district counts as level 1. See Turf.
var turf_levels: Dictionary = {}
## Hired crew. See Crew for the entry layout.
var crew: Array[Dictionary] = []
## What the crew did since the last morning report. See Crew.note().
var crew_report: Dictionary = {}
## Phase stamp of the runner's last delivery.
var runner_stamp: int = -1
## Pay owed for jobs delivered on credit. See Invoices for the entry layout.
var invoices: Array[Dictionary] = []
## Owned businesses. See Businesses for the entry layout.
var businesses: Array[Dictionary] = []
## Today's tasks. See DailyTasks for the entry layout.
var daily_tasks: Array[Dictionary] = []
## Day the daily tasks were dealt for.
var tasks_day: int = 0
## Heist id to the first day it can be pulled again.
var heist_cooldowns: Dictionary = {}
## Day on which the lookout last turned a raid into a warning.
var raid_warning_day: int = 0
## Jobs offered to the player's phone and not yet answered. See Errands for the entry layout.
var errand_offers: Array[Dictionary] = []
## Accepted errands in progress. See Errands for the entry layout.
var errands: Array[Dictionary] = []
## Customer orders on the player's phone and not yet answered. See Customers for the entry layout.
var customer_offers: Array[Dictionary] = []
## Accepted customer orders waiting for the handover. See Customers for the entry layout.
var customer_orders: Array[Dictionary] = []
## Weekly payments to the Shark missed in a row. See Loan.
var missed_weeks: int = 0

var next_due_day: int = Loan.PAYMENT_PERIOD_DAYS + 1
var period_minimum: int = Loan.FIRST_PAYMENT
var paid_this_period: int = 0

var outcome: Outcome = Outcome.ONGOING
var trades: int = 0
var profit: int = 0
var busts: int = 0


static func phase_name(value: Phase) -> String:
	return PHASE_NAMES[value]


func to_dict() -> Dictionary:
	var saved_gear: Array[String] = []
	for item_id in gear:
		saved_gear.append(String(item_id))
	return {
		"player_id": String(player_id),
		"price_seed": price_seed,
		"day": day,
		"phase": phase,
		"phase_seconds_left": phase_seconds_left,
		"cash": cash,
		"debt": debt,
		"heat": heat,
		"district_id": String(district_id),
		"inventory": _string_keys(inventory),
		"stash": _string_keys(stash),
		"stash_level": stash_level,
		"stashed_cash": stashed_cash,
		"cost_basis": _string_keys(cost_basis),
		"gear": saved_gear,
		"walked_out": _string_keys(walked_out),
		"market_shifts": market_shifts,
		"price_sightings": price_sightings,
		"orders": orders,
		"taken_orders": taken_orders,
		"rumors_heard": _string_keys(rumors_heard),
		"crate": crate,
		"taken_crates": taken_crates,
		"smuggling_ban_day": smuggling_ban_day,
		"stop_stamp": stop_stamp,
		"arrest_stamp": arrest_stamp,
		"jail_seconds_left": jail_seconds_left,
		"recon_stamp": recon_stamp,
		"hijacked_stamp": hijacked_stamp,
		"turf": _string_keys(turf),
		"muscle_stamp": muscle_stamp,
		"vex_gone": vex_gone,
		"vex_anger": vex_anger,
		"cleanup_stamp": cleanup_stamp,
		"family_standing": _string_keys(family_standing),
		"favours": favours,
		"taken_favours": taken_favours,
		"hack_stamp": hack_stamp,
		"pending_encounter": pending_encounter,
		"career": career,
		"street_cred": street_cred,
		"cred_day": cred_day,
		"trading_cred_today": trading_cred_today,
		"skills": _string_keys(skills),
		"turf_levels": _string_keys(turf_levels),
		"crew": crew,
		"crew_report": _string_keys(crew_report),
		"runner_stamp": runner_stamp,
		"invoices": invoices,
		"businesses": businesses,
		"daily_tasks": daily_tasks,
		"tasks_day": tasks_day,
		"heist_cooldowns": _string_keys(heist_cooldowns),
		"raid_warning_day": raid_warning_day,
		"errand_offers": errand_offers,
		"errands": errands,
		"customer_offers": customer_offers,
		"customer_orders": customer_orders,
		"missed_weeks": missed_weeks,
		"next_due_day": next_due_day,
		"period_minimum": period_minimum,
		"paid_this_period": paid_this_period,
		"outcome": outcome,
		"trades": trades,
		"profit": profit,
		"busts": busts,
		"tutorial_step": tutorial_step,
		"tutorial_completed": tutorial_completed,
	}


static func from_dict(data: Dictionary) -> RunState:
	var state := RunState.new()
	state.player_id = StringName(str(data.get("player_id", state.player_id)))
	state.price_seed = int(data.get("price_seed", state.price_seed))
	state.day = maxi(1, int(data.get("day", state.day)))
	state.phase = clampi(int(data.get("phase", state.phase)), 0, Phase.size() - 1) as Phase
	state.phase_seconds_left = clampf(float(data.get("phase_seconds_left", state.phase_seconds_left)), 0.0, Calendar.PHASE_SECONDS)
	state.cash = int(data.get("cash", state.cash))
	state.debt = maxi(0, int(data.get("debt", state.debt)))
	state.heat = clampi(int(data.get("heat", state.heat)), 0, 100)
	state.district_id = StringName(str(data.get("district_id", state.district_id)))
	state.inventory = _positive_counts(data.get("inventory"))
	state.stash = _positive_counts(data.get("stash"))
	state.stash_level = clampi(int(data.get("stash_level", 0)), 0, Safehouse.UPGRADES.size())
	state.stashed_cash = maxi(0, int(data.get("stashed_cash", 0)))
	state.cost_basis = _positive_counts(data.get("cost_basis"))
	state.walked_out = _positive_counts(data.get("walked_out"), 0)

	var saved_gear: Variant = data.get("gear", [])
	if saved_gear is Array:
		for item_id: Variant in saved_gear:
			var gear_id := StringName(str(item_id))
			if gear_id == LEGACY_LOCKBOX:
				state.stash_level = maxi(state.stash_level, 1)
			elif not state.gear.has(gear_id):
				state.gear.append(gear_id)

	var saved_shifts: Variant = data.get("market_shifts", [])
	if saved_shifts is Array:
		for shift: Variant in saved_shifts:
			if shift is Dictionary:
				state.market_shifts.append(StreetEvents.sanitize_shift(shift))
	var saved_sightings: Variant = data.get("price_sightings", [])
	if saved_sightings is Array:
		for sighting: Variant in saved_sightings:
			if sighting is Dictionary:
				state.price_sightings.append(PriceIntel.sanitize_sighting(sighting))
	var saved_orders: Variant = data.get("orders", [])
	if saved_orders is Array:
		for order: Variant in saved_orders:
			if order is Dictionary and state.orders.size() < Orders.MAX_ACTIVE:
				state.orders.append(Orders.sanitize(order))
	var saved_taken: Variant = data.get("taken_orders", [])
	if saved_taken is Array:
		for id: Variant in saved_taken:
			state.taken_orders.append(str(id))
	state.rumors_heard = _positive_counts(data.get("rumors_heard"), 0)
	var saved_crate: Variant = data.get("crate", {})
	if saved_crate is Dictionary:
		state.crate = Smuggling.sanitize(saved_crate)
	var saved_taken_crates: Variant = data.get("taken_crates", [])
	if saved_taken_crates is Array:
		for id: Variant in saved_taken_crates:
			state.taken_crates.append(str(id))
	state.smuggling_ban_day = maxi(0, int(data.get("smuggling_ban_day", 0)))
	state.stop_stamp = int(data.get("stop_stamp", -1))
	state.arrest_stamp = int(data.get("arrest_stamp", -1))
	state.recon_stamp = int(data.get("recon_stamp", -1))
	state.jail_seconds_left = clampf(float(data.get("jail_seconds_left", 0.0)), 0.0, Police.JAIL_SECONDS)
	state.hijacked_stamp = int(data.get("hijacked_stamp", -1))
	state.turf = Turf.sanitize(data.get("turf", {}))
	state.muscle_stamp = int(data.get("muscle_stamp", -1))
	state.vex_gone = bool(data.get("vex_gone", false))
	state.vex_anger = clampi(int(data.get("vex_anger", 0)), 0, Vex.MAX_ANGER)
	state.cleanup_stamp = int(data.get("cleanup_stamp", -1))
	state.family_standing = Families.sanitize(data.get("family_standing", {}))
	var saved_favours: Variant = data.get("favours", [])
	if saved_favours is Array:
		for favour: Variant in saved_favours:
			if favour is Dictionary:
				var clean := Favours.sanitize(favour)
				if not clean.is_empty() and Favours.active_for(state, StringName(clean.family)).is_empty():
					state.favours.append(clean)
	var saved_taken_favours: Variant = data.get("taken_favours", [])
	if saved_taken_favours is Array:
		for id: Variant in saved_taken_favours:
			state.taken_favours.append(str(id))
	state.hack_stamp = int(data.get("hack_stamp", -1))
	var saved_encounter: Variant = data.get("pending_encounter", {})
	if saved_encounter is Dictionary:
		state.pending_encounter = saved_encounter
	state.career = bool(data.get("career", false)) or bool(data.get("endless", false))
	state.street_cred = clampi(int(data.get("street_cred", 0)), 0, StreetCred.MAX)
	state.cred_day = maxi(0, int(data.get("cred_day", 0)))
	state.trading_cred_today = clampi(int(data.get("trading_cred_today", 0)), 0, StreetCred.DAILY_TRADING_CAP)
	state.tutorial_step = maxi(0, int(data.get("tutorial_step", 0)))
	state.tutorial_completed = bool(data.get("tutorial_completed", false))
	state.skills = _positive_counts(data.get("skills"))
	state.turf_levels = _positive_counts(data.get("turf_levels"))
	for member in _dictionaries(data.get("crew")):
		var clean := Crew.sanitize(member)
		if not clean.is_empty() and state.crew.size() < Crew.cap(state) and not Crew.has(state, StringName(clean.role)):
			state.crew.append(clean)
	state.crew_report = _positive_counts(data.get("crew_report"))
	state.runner_stamp = int(data.get("runner_stamp", -1))
	for invoice in _dictionaries(data.get("invoices")):
		var clean := Invoices.sanitize(invoice)
		if not clean.is_empty():
			state.invoices.append(clean)
	for entry in _dictionaries(data.get("businesses")):
		var clean := Businesses.sanitize(entry)
		if not clean.is_empty():
			state.businesses.append(clean)
	for task in _dictionaries(data.get("daily_tasks")):
		var clean := DailyTasks.sanitize(task)
		if not clean.is_empty():
			state.daily_tasks.append(clean)
	state.tasks_day = maxi(0, int(data.get("tasks_day", 0)))
	state.heist_cooldowns = _positive_counts(data.get("heist_cooldowns"))
	state.raid_warning_day = maxi(0, int(data.get("raid_warning_day", 0)))
	for offer in _dictionaries(data.get("errand_offers")):
		var clean := Errands.sanitize(offer)
		if not clean.is_empty() and state.errand_offers.size() < Errands.MAX_OPEN_OFFERS:
			state.errand_offers.append(clean)
	for errand in _dictionaries(data.get("errands")):
		var clean := Errands.sanitize(errand)
		if not clean.is_empty() and state.errands.size() < Errands.MAX_ACTIVE:
			state.errands.append(clean)
	for offer in _dictionaries(data.get("customer_offers")):
		var clean := Customers.sanitize(offer)
		if not clean.is_empty() and state.customer_offers.size() < Customers.MAX_OPEN_OFFERS:
			state.customer_offers.append(clean)
	for order in _dictionaries(data.get("customer_orders")):
		var clean := Customers.sanitize(order)
		if not clean.is_empty() and state.customer_orders.size() < Customers.MAX_ACTIVE:
			state.customer_orders.append(clean)
	state.missed_weeks = maxi(0, int(data.get("missed_weeks", 0)))

	state.next_due_day = maxi(2, int(data.get("next_due_day", state.next_due_day)))
	state.period_minimum = maxi(0, int(data.get("period_minimum", state.period_minimum)))
	state.paid_this_period = maxi(0, int(data.get("paid_this_period", state.paid_this_period)))
	state.outcome = clampi(int(data.get("outcome", state.outcome)), 0, Outcome.size() - 1) as Outcome
	if state.outcome == Outcome.WON:
		state.outcome = Outcome.ONGOING
		state.career = true
	state.trades = maxi(0, int(data.get("trades", state.trades)))
	state.profit = int(data.get("profit", state.profit))
	state.busts = maxi(0, int(data.get("busts", state.busts)))
	return state


static func _string_keys(source: Dictionary) -> Dictionary:
	var result := {}
	for key: StringName in source:
		result[String(key)] = source[key]
	return result


static func _dictionaries(source: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if source is Array:
		for entry: Variant in source:
			if entry is Dictionary:
				result.append(entry)
	return result


static func _positive_counts(source: Variant, minimum: int = 1) -> Dictionary:
	var result := {}
	if source is Dictionary:
		for key: Variant in source:
			var value := int(source[key])
			if value >= minimum:
				result[StringName(str(key))] = value
	return result
