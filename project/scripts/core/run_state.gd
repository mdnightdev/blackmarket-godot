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
## Clean bank balance from laundering fronts.
var clean: int = 0
var debt: int = STARTING_DEBT
var heat: int = 0
## Active frenzy countdown in real seconds. While > 0, heat is active and police/rivals are aggressive.
var heat_timer: float = 0.0
## Active 3-day laundering batches.
var laundering: Array[Dictionary] = []
var district_id: StringName = STARTING_DISTRICT
## The Shark's terms, played once when the run starts. See OpeningTalk.
var opening_done := false
## Lexie's lessons switched off by the player. See Tutorial.
var tutorial_completed := false
var lessons_seen: Array[String] = []
var lessons_queued: Array[String] = []
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
## Unix time when the player walks out of a cell, 0 when free. See Police.
var jail_until: float = 0.0
var jail_bail: int = 0
## Phase stamp of the last hijack attempt.
var hijacked_stamp: int = -1
## Gangs driven out of the city.
var gangs_gone: Array[StringName] = []
## Gang id to how angry its boss is. It rises each time the player refuses the crew, and at Gangs.MAX_ANGER
## the crew hunts the player.
var gang_anger: Dictionary = {}
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
## The player bought the Shark's business. Borrowing ends and lending to dealers opens.
var shark_bought := false
## Day on which the Shark offers his lending desk for sale (7 days after debt paid).
var shark_sale_day: int = 0
## Whether the Shark's retirement buyout letter has been sent.
var shark_mail_sent := false
## Money lent to dealers. See Lending for the entry layout.
var dealer_loans: Array[Dictionary] = []
## Dealer id to the day until their stall is shuttered by the Shark.
var dealer_lockdowns: Dictionary = {}
## Dealer id to the day until they can request loans again.
var dealer_loan_blacklist: Dictionary = {}
var street_cred: int = 0
## Day that trading_cred_today counts for.
var cred_day: int = 0
var trading_cred_today: int = 0
## Skill id to rank bought. See Skills.
var skills: Dictionary = {}
## Hired crew. See Crew for the entry layout.
var crew: Array[Dictionary] = []
## What the crew did since the last morning report. See Crew.note().
var crew_report: Dictionary = {}
## Phase stamp of the runner's last delivery.
var runner_stamp: int = -1
var muscle_stamp: int = -1
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
## Board jobs offered by phone and not yet answered. See JobPings for the entry layout.
var job_pings: Array[Dictionary] = []
## Ids of today's board entries already sent as pings, so each one rings once.
var seen_pings: Array[String] = []
## Weekly payments to the Shark missed in a row. See Loan.
var missed_weeks: int = 0
## Every weekly payment ever missed. The Shark's inheritance talk needs a clean record.
var missed_total: int = 0
## Day the current week's payment was fully covered. 0 while it is still owed.
var covered_day: int = 0
## Who holds the debt: the Shark, or Vex after he sells it. See DebtSale.
var lender: StringName = Loan.LENDER
## See SharkTrust.
var shark_trust: int = SharkTrust.START
var shark_letter_sent := false
var inheritance_promised := false
## What the player did with 午夜兔子's savings. See DebtSale.RabbitOffer.
var rabbit_offer: DebtSale.RabbitOffer = DebtSale.RabbitOffer.NONE
## 午夜兔子's night in the cells. See RabbitCells.
var rabbit_cells: RabbitCells.Stage = RabbitCells.Stage.NONE
## Phase stamp he walks out at while held. -1 when he is not held.
var rabbit_release_stamp: int = -1
## Ramos kept his service medal.
var rabbit_medal_held := false
## How hard the police hunt for whoever tips the player off before raids. Never shown. See Ramos.
var leak_suspicion: int = 0
## Ramos gives no raid tips until this day. 0 when he is not lying low.
var ramos_quiet_until: int = 0
## See Story.
var story_flags: Array[String] = []
## Weapon grade to how many men it arms. See Armory.
var armory: Dictionary = {}
## Orders placed with Rook. Jackal's men walk in on the second.
var rook_orders: int = 0
## Cash spent with Rook. His back rooms open with it.
var rook_spent: int = 0
## Voronin's crates delivered in a row. A lost or seized crate resets it.
var crate_streak: int = 0
## Corner ids the player holds. See Corners.
var corners_held: Array[String] = []
## Tier to a count of men per state. See Army.
var army: Dictionary = {}
## Tier to the men who died fighting, over the whole run.
var fallen: Dictionary = {}
## Index into Army.EXPANSIONS.
var army_level: int = 0
## Index into Hospital.LEVELS. Saved as hospital_size, since older saves kept hospital_level on a smaller scale whose
## top matched today's first level.
var hospital_level: int = 0
## Corner id to the gang fighters on it, once a fight or the gang's growth changed it. Missing corners keep their
## starting crew.
var corner_defenders: Dictionary = {}
## Corner id to the player's men posted to hold it. See Corners.
var player_garrisons: Dictionary = {}
## Gang id to its war chest, weapons and last strike. See Rivals.
var rivals: Dictionary = {}
## Corner id to the latest scouting report. See Scouting.
var scouted: Dictionary = {}
## Finished jobs, newest first. See Journal for the entry layout.
var journal: Array[Dictionary] = []
## Jobs closed early as failures since the last commit. Never saved. See Journal.mark_failed.
var failed_job_ids: Array[String] = []

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
		"clean": clean,
		"debt": debt,
		"heat": heat,
		"heat_timer": heat_timer,
		"laundering": laundering,
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
		"jail_until": jail_until,
		"jail_bail": jail_bail,
		"recon_stamp": recon_stamp,
		"hijacked_stamp": hijacked_stamp,
		"gangs_gone": Array(gangs_gone).map(func(gang_id: StringName) -> String: return String(gang_id)),
		"gang_anger": _string_keys(gang_anger),
		"cleanup_stamp": cleanup_stamp,
		"family_standing": _string_keys(family_standing),
		"favours": favours,
		"taken_favours": taken_favours,
		"hack_stamp": hack_stamp,
		"pending_encounter": pending_encounter,
		"career": career,
		"shark_bought": shark_bought,
		"shark_sale_day": shark_sale_day,
		"shark_mail_sent": shark_mail_sent,
		"dealer_loans": dealer_loans,
		"dealer_lockdowns": _string_keys(dealer_lockdowns),
		"dealer_loan_blacklist": _string_keys(dealer_loan_blacklist),
		"street_cred": street_cred,
		"cred_day": cred_day,
		"trading_cred_today": trading_cred_today,
		"skills": _string_keys(skills),
		"crew": crew,
		"crew_report": _string_keys(crew_report),
		"runner_stamp": runner_stamp,
		"muscle_stamp": muscle_stamp,
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
		"job_pings": job_pings,
		"seen_pings": seen_pings,
		"missed_weeks": missed_weeks,
		"missed_total": missed_total,
		"covered_day": covered_day,
		"lender": String(lender),
		"shark_trust": shark_trust,
		"shark_letter_sent": shark_letter_sent,
		"inheritance_promised": inheritance_promised,
		"rabbit_offer": rabbit_offer,
		"rabbit_cells": rabbit_cells,
		"rabbit_release_stamp": rabbit_release_stamp,
		"rabbit_medal_held": rabbit_medal_held,
		"leak_suspicion": leak_suspicion,
		"ramos_quiet_until": ramos_quiet_until,
		"story_flags": story_flags,
		"armory": armory,
		"rook_orders": rook_orders,
		"rook_spent": rook_spent,
		"crate_streak": crate_streak,
		"corners_held": corners_held,
		"army": army,
		"war_scale": Army.WAR_SCALE,
		"fallen": fallen,
		"army_level": army_level,
		"hospital_size": hospital_level,
		"corner_defenders": corner_defenders,
		"player_garrisons": player_garrisons,
		"rivals": _string_keys(rivals),
		"scouted": scouted,
		"journal": journal,
		"next_due_day": next_due_day,
		"period_minimum": period_minimum,
		"paid_this_period": paid_this_period,
		"outcome": outcome,
		"trades": trades,
		"profit": profit,
		"busts": busts,
		"opening_done": opening_done,
		"tutorial_completed": tutorial_completed,
		"lessons_seen": lessons_seen,
		"lessons_queued": lessons_queued,
	}


static func from_dict(data: Dictionary) -> RunState:
	var state := RunState.new()
	state.player_id = StringName(str(data.get("player_id", state.player_id)))
	state.price_seed = int(data.get("price_seed", state.price_seed))
	state.day = maxi(1, int(data.get("day", state.day)))
	state.phase = clampi(int(data.get("phase", state.phase)), 0, Phase.size() - 1) as Phase
	state.phase_seconds_left = clampf(float(data.get("phase_seconds_left", state.phase_seconds_left)), 0.0, Calendar.PHASE_SECONDS)
	state.cash = int(data.get("cash", state.cash))
	state.clean = maxi(0, int(data.get("clean", 0)))
	state.debt = maxi(0, int(data.get("debt", state.debt)))
	state.heat = clampi(int(data.get("heat", state.heat)), 0, 100)
	state.heat_timer = maxf(0.0, float(data.get("heat_timer", 0.0)))
	var saved_laundering: Variant = data.get("laundering", [])
	if saved_laundering is Array:
		for batch: Variant in saved_laundering:
			if batch is Dictionary:
				var dirty := int(batch.get("dirty_amount", 0))
				var days := int(batch.get("days_left", 0))
				if dirty <= 0 or days <= 0:
					continue
				var inst := StringName(str(batch.get("instrument", batch.get("business", ""))))
				if not Money.INSTRUMENTS.has(inst) and Content.item(inst) == null and Content.business(inst) == null:
					continue
				state.laundering.append(batch)
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
	state.jail_until = maxf(0.0, float(data.get("jail_until", 0.0)))
	state.jail_bail = maxi(0, int(data.get("jail_bail", 0)))
	var legacy_jail := clampf(float(data.get("jail_seconds_left", 0.0)), 0.0, Police.JAIL_SECONDS)
	if legacy_jail > 0.0:
		state.jail_until = Time.get_unix_time_from_system() + legacy_jail
		state.jail_bail = Police.MIN_BAIL
	state.hijacked_stamp = int(data.get("hijacked_stamp", -1))
	var legacy_gone: Array = [Gangs.LEGACY_GANG] if bool(data.get("vex_gone", false)) else []
	state.gangs_gone = Gangs.sanitize_gone(data.get("gangs_gone", legacy_gone))
	state.gang_anger = Gangs.sanitize_anger(data.get("gang_anger", { Gangs.LEGACY_GANG: data.get("vex_anger", 0) }))
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
		state.pending_encounter = Gangs.migrate_encounter(saved_encounter)
	state.career = bool(data.get("career", false)) or bool(data.get("endless", false))
	state.shark_bought = state.career and bool(data.get("shark_bought", false))
	state.shark_sale_day = maxi(0, int(data.get("shark_sale_day", 0)))
	state.shark_mail_sent = bool(data.get("shark_mail_sent", false))
	if state.career and state.debt <= 0 and not state.shark_bought and state.shark_sale_day == 0:
		state.shark_sale_day = 1
	for loan in _dictionaries(data.get("dealer_loans")):
		var clean := Lending.sanitize(loan)
		if not clean.is_empty() and not Lending.has_loan(state, StringName(clean.dealer)):
			state.dealer_loans.append(clean)
	state.dealer_lockdowns = _positive_counts(data.get("dealer_lockdowns"))
	state.dealer_loan_blacklist = _positive_counts(data.get("dealer_loan_blacklist"))
	state.street_cred = clampi(int(data.get("street_cred", 0)), 0, StreetCred.MAX)
	state.cred_day = maxi(0, int(data.get("cred_day", 0)))
	state.trading_cred_today = clampi(int(data.get("trading_cred_today", 0)), 0, StreetCred.DAILY_TRADING_CAP)
	state.opening_done = bool(data.get("opening_done", true))
	state.tutorial_completed = bool(data.get("tutorial_completed", false))
	state.lessons_seen = _lessons(data.get("lessons_seen"))
	for lesson in _lessons(data.get("lessons_queued")):
		if not state.lessons_seen.has(lesson):
			state.lessons_queued.append(lesson)
	state.skills = _positive_counts(data.get("skills"))
	for member in _dictionaries(data.get("crew")):
		var clean := Crew.sanitize(member)
		if clean.is_empty():
			continue
		var role_id := StringName(str(clean.get("role", "")))
		if Content.crew_role(role_id) == null:
			continue
		var has_room := Crew.is_free(clean) or Crew.hired_count(state) < Crew.cap(state)
		if has_room and not Crew.has(state, role_id):
			state.crew.append(clean)
	state.crew_report = _positive_counts(data.get("crew_report"))
	state.runner_stamp = int(data.get("runner_stamp", -1))
	state.muscle_stamp = int(data.get("muscle_stamp", -1))
	for invoice in _dictionaries(data.get("invoices")):
		var clean := Invoices.sanitize(invoice)
		if not clean.is_empty():
			state.invoices.append(clean)
	var businesses_by_pair: Dictionary = {}
	for entry in _dictionaries(data.get("businesses")):
		var clean := Businesses.sanitize(entry)
		if clean.is_empty():
			continue
		var pair_key := "%s:%s" % [clean.business, clean.district]
		if businesses_by_pair.has(pair_key):
			var existing: Dictionary = businesses_by_pair[pair_key]
			if Businesses.level_of(clean) > Businesses.level_of(existing):
				existing["level"] = Businesses.level_of(clean)
		else:
			businesses_by_pair[pair_key] = clean
	for b in businesses_by_pair.values():
		state.businesses.append(b)
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
	for ping in _dictionaries(data.get("job_pings")):
		var clean := JobPings.sanitize(ping)
		if not clean.is_empty() and state.job_pings.size() < JobPings.MAX_OPEN:
			state.job_pings.append(clean)
	var saved_seen_pings: Variant = data.get("seen_pings", [])
	if saved_seen_pings is Array:
		for id: Variant in saved_seen_pings:
			state.seen_pings.append(str(id))
	state.missed_weeks = maxi(0, int(data.get("missed_weeks", 0)))
	state.missed_total = maxi(state.missed_weeks, int(data.get("missed_total", 0)))
	state.covered_day = maxi(0, int(data.get("covered_day", 0)))
	state.lender = Loan.VEX_LENDER if str(data.get("lender", "")) == String(Loan.VEX_LENDER) else Loan.LENDER
	state.shark_trust = clampi(int(data.get("shark_trust", SharkTrust.START)), 0, SharkTrust.MAX)
	state.shark_letter_sent = bool(data.get("shark_letter_sent", false))
	state.inheritance_promised = bool(data.get("inheritance_promised", false))
	state.rabbit_offer = clampi(int(data.get("rabbit_offer", 0)), 0, DebtSale.RabbitOffer.size() - 1) as DebtSale.RabbitOffer
	state.rabbit_cells = clampi(int(data.get("rabbit_cells", 0)), 0, RabbitCells.Stage.size() - 1) as RabbitCells.Stage
	state.rabbit_release_stamp = int(data.get("rabbit_release_stamp", -1))
	state.rabbit_medal_held = bool(data.get("rabbit_medal_held", false))
	state.leak_suspicion = clampi(int(data.get("leak_suspicion", 0)), 0, Ramos.LEAK_LIMIT)
	state.ramos_quiet_until = maxi(0, int(data.get("ramos_quiet_until", 0)))
	var saved_flags: Variant = data.get("story_flags", [])
	if saved_flags is Array:
		for flag: Variant in saved_flags:
			if not str(flag).is_empty() and not state.story_flags.has(str(flag)):
				state.story_flags.append(str(flag))
	state.armory = Armory.sanitize(data.get("armory"))
	var saved_lots := maxi(0, int(data.get("rook_lots", 0)))
	state.rook_orders = maxi(0, int(data.get("rook_orders", saved_lots)))
	state.rook_spent = maxi(0, int(data.get("rook_spent", Armory.spend_from_lots(saved_lots))))
	state.crate_streak = maxi(0, int(data.get("crate_streak", 0)))
	state.corners_held = Corners.sanitize(data.get("corners_held"))
	if data.has("turf"):
		Corners.migrate_turf(state, data.get("turf"))
	var saved_army: Variant = data.get("army") if data.has("army") else Army.from_legacy(int(data.get("men", 0)), state.story_flags.has(War.UNIT_HIRED))
	state.army = Army.sanitize(saved_army)
	state.fallen = Army.sanitize_counts(data.get("fallen"))
	state.army_level = clampi(int(data.get("army_level", 0)), 0, Army.EXPANSIONS.size() - 1)
	state.hospital_level = clampi(int(data.get("hospital_size", 0)), 0, Hospital.LEVELS.size() - 1)
	state.corner_defenders = War.sanitize_defenders(data.get("corner_defenders"))
	state.player_garrisons = Corners.sanitize_garrisons(state, data.get("player_garrisons"))
	Corners.sync(state)
	state.rivals = Rivals.sanitize(data.get("rivals"))
	var last_ambush_day := maxi(0, int(data.get("last_ambush_day", 0)))
	if not data.has("rivals") and last_ambush_day > 0:
		Rivals.note_strike(state, Content.gang(Gangs.LEGACY_GANG), last_ambush_day)
	state.scouted = Scouting.sanitize(data.get("scouted"))
	var saved_scale := maxi(1, int(data.get("war_scale", 1)))
	if saved_scale < Army.WAR_SCALE:
		Army.rescale(state, Army.WAR_SCALE / saved_scale)
	Gym.deliver_legacy_training(state, data.get("training"))
	for entry in _dictionaries(data.get("journal")):
		var clean := Journal.sanitize(entry)
		if not clean.is_empty() and state.journal.size() < Journal.MAX_ENTRIES:
			state.journal.append(clean)

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
	if state.career and not data.has("story_flags"):
		Campaign.skip_act_one(state)
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


static func _lessons(source: Variant) -> Array[String]:
	var result: Array[String] = []
	if source is Array:
		for entry: Variant in source:
			var lesson := str(entry)
			if Tutorial.LINES.has(lesson) and not result.has(lesson):
				result.append(lesson)
	return result


static func _positive_counts(source: Variant, minimum: int = 1) -> Dictionary:
	var result := {}
	if source is Dictionary:
		for key: Variant in source:
			var value := int(source[key])
			if value >= minimum:
				result[StringName(str(key))] = value
	return result


static func _item_counts(source: Variant, minimum: int = 1) -> Dictionary:
	var result := {}
	if source is Dictionary:
		for key: Variant in source:
			var id := StringName(str(key))
			if Content.item(id) == null:
				continue
			var value := int(source[key])
			if value >= minimum:
				result[id] = value
	return result
