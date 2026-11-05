class_name Corners

## Street corners. Every district a gang fights over is split into corners, and the gang holds each one until the
## player takes it by force, see War. In Act 1 the fight is only for Old Market: Vex holds all four corners until the
## player buys Mama Lin's and takes the rest. run.corners_held lists the corner ids the player holds.
## Mama Lin's corner goes on sale once the debt is off the player's back, or once Vex holds it. Auntie Tran tips the
## player off by phone, buying it brings Rabbit in, and the next morning Vex smashes the stall.

enum Result { OK, NOT_FOR_SALE, NOT_ENOUGH_CASH }

const HOME: StringName = &"old_market"
const MAMA_LIN: StringName = &"mama_lin_corner"
const MAMA_LIN_PRICE := 10000
const TRAN: StringName = &"tran"
const VEX: StringName = &"rival"
const FRIEND: StringName = &"midnight_rabbit"
const RABBIT_ROLE: StringName = &"muscle"

const TIP := "corner_tip"
const STALL_SMASHED := "stall_smashed"
const TIP_SENT := "tran_tip_sent"
const SALE_HEARD := "mama_lin_sale_heard"
const RABBIT_JOINED := "rabbit_joined"
const STALL_DONE := "vex_smashed_stall"
## Share of each stack of stock the smashed stall costs.
const STALL_STOCK_LOSS := 0.25
## Saves from before every district had corners kept a share per district. A held district comes back with this
## many corners, all of them from MIGRATED_ALL_AT.
const MIGRATED_HOLD_SHARE := 60
const MIGRATED_HELD_CORNERS := 3
const MIGRATED_ALL_AT := 90


static func of(district_id: StringName) -> Array[CornerDef]:
	var district := Content.district(district_id)
	return district.corners if district != null else ([] as Array[CornerDef])


static func has_corners(district_id: StringName) -> bool:
	return not of(district_id).is_empty()


static func find(corner_id: StringName) -> CornerDef:
	for district in Content.districts():
		for corner in district.corners:
			if corner.id == corner_id:
				return corner
	return null


static func district_of(corner_id: StringName) -> StringName:
	for district in Content.districts():
		for corner in district.corners:
			if corner.id == corner_id:
				return district.id
	return &""


## The gang fighting for the corner, or null.
static func gang_of(corner_id: StringName) -> GangDef:
	var corner := find(corner_id)
	if corner != null and not corner.gang.is_empty():
		return Content.gang(corner.gang)
	return Gangs.owner(district_of(corner_id))


static func holds(run: RunState, corner_id: StringName) -> bool:
	return run.corners_held.has(String(corner_id))


static func held_count(run: RunState, district_id: StringName) -> int:
	return of(district_id).filter(func(corner: CornerDef) -> bool: return holds(run, corner.id)).size()


## The player's share of a district with corners, from 0 to 100.
static func share(run: RunState, district_id: StringName) -> int:
	var total := of(district_id).size()
	return roundi(100.0 * held_count(run, district_id) / total) if total > 0 else 0


const GARRISON_FACTOR := 1.5
const STRONGHOLD_GARRISON_FACTOR := 2.5
const CORNER_GARRISON_CAP := 50000


static func take(run: RunState, corner_id: StringName) -> void:
	if find(corner_id) != null and not holds(run, corner_id):
		run.corners_held.append(String(corner_id))
		run.player_garrisons.erase(String(corner_id))
		DailyTasks.record_corner_taken(run)


static func take_all(run: RunState, district_id: StringName) -> void:
	for corner in of(district_id):
		take(run, corner.id)


static func lose(run: RunState, corner_id: StringName) -> void:
	run.corners_held.erase(String(corner_id))
	run.player_garrisons.erase(String(corner_id))


## Men from the player's army posted on a held corner. Unmanned corners have 0 posted men and 0 defense power (BATTLE.md Section 12B).
static func garrison(run: RunState, corner_id: StringName) -> int:
	if not holds(run, corner_id):
		return 0
	return maxi(0, int(run.player_garrisons.get(String(corner_id), 0)))


static func corner_capacity(_run: RunState = null, _corner: CornerDef = null) -> int:
	return CORNER_GARRISON_CAP


## Validates a proposed garrison allocation against corner capacity and free reserve (BATTLE.md Section 12B).
## Returns { "ok": bool, "clamped": int, "room": int, "reserve": int, "warning": String }.
static func validate_garrison_dispatch(run: RunState, corner_id: StringName, desired_total: int) -> Dictionary:
	var corner := find(corner_id)
	if corner == null or not holds(run, corner_id):
		return { "ok": false, "clamped": 0, "room": 0, "reserve": 0, "warning": "Corner not held" }
	var current := garrison(run, corner_id)
	var available_reserve := Army.reserve(run)
	var cap := corner_capacity(run, corner)
	var available_room := maxi(0, cap - current)
	var max_allowed := mini(current + available_reserve, cap)
	var clamped := clampi(desired_total, 0, max_allowed)
	if desired_total > cap:
		return {
			"ok": false,
			"clamped": clamped,
			"room": available_room,
			"reserve": available_reserve,
			"warning": "Cannot exceed corner capacity of %s" % Format.count(cap),
		}
	if desired_total - current > available_reserve:
		return {
			"ok": false,
			"clamped": clamped,
			"room": available_room,
			"reserve": available_reserve,
			"warning": "Insufficient free reserve troops",
		}
	return {
		"ok": true,
		"clamped": clamped,
		"room": available_room,
		"reserve": available_reserve,
		"warning": "",
	}


static func total_garrisoned(run: RunState) -> int:
	var sum := 0
	for corner_id in run.corners_held:
		sum += garrison(run, StringName(corner_id))
	return sum


## Posts men from the player's reserve onto a held corner, or recalls them back to reserve when men < current.
static func post_garrison(run: RunState, corner_id: StringName, men: int) -> bool:
	var corner := find(corner_id)
	if corner == null or not holds(run, corner_id):
		return false
	var current := garrison(run, corner_id)
	var available := Army.reserve(run) + current
	var cap := corner_capacity(run, corner)
	var clamped := clampi(men, 0, mini(available, cap))
	if clamped > 0:
		run.player_garrisons[String(corner_id)] = clamped
		if clamped > current:
			DailyTasks.record_garrison(run)
	else:
		run.player_garrisons.erase(String(corner_id))
	return true


## Recalls a stationed garrison with physical transit delay back to reserve (BATTLE.md Section 12A).
## Troops in transit cannot defend the corner or join new marches until their return march completes.
static func recall_garrison_with_transit(run: RunState, corner_id: StringName, transit_seconds: float = 15.0) -> bool:
	var posted := garrison(run, corner_id)
	if posted <= 0:
		return false
	var deploy := Army.garrison_deployment(run, posted)
	run.player_garrisons.erase(String(corner_id))
	if transit_seconds > 0.0:
		run.active_marches.append({
			"id": "recall_%s_%d" % [String(corner_id), run.day],
			"origin": String(district_of(corner_id)),
			"target_corner": String(corner_id),
			"deployment": deploy,
			"commander": "",
			"state": "returning",
			"status": "returning",
			"eta_seconds": transit_seconds,
			"total_transit_seconds": transit_seconds,
			"reinforcements_added": 0,
			"morale": 1.0,
		})
	return true


## Defensive combat power of a held corner: posted men with home/stronghold cover multiplier.
## Unmanned corners have 0 defense power (zero phantom lookouts, BATTLE.md Section 12B).
static func garrison_power(run: RunState, corner: CornerDef) -> float:
	if corner == null or not holds(run, corner.id):
		return 0.0
	var posted := garrison(run, corner.id)
	var factor := STRONGHOLD_GARRISON_FACTOR if corner.stronghold else GARRISON_FACTOR
	if posted <= 0:
		return 0.0
	var garrison_deploy := Army.garrison_deployment(run, posted)
	return Army.power(run, garrison_deploy) * factor


## Hands out corners for a save that kept a share per district. Districts of a gang already driven out are the
## player's whole. A held district keeps its plain corners before its stronghold.
static func migrate_turf(run: RunState, shares: Variant) -> void:
	var saved: Dictionary = shares if shares is Dictionary else {}
	for gang in Content.gangs():
		for district_id in gang.turf:
			if district_id == HOME:
				continue
			var share := int(saved.get(String(district_id), saved.get(district_id, 0)))
			if Gangs.is_gone(run, gang):
				for corner in of(district_id):
					if gang_of(corner.id) == gang:
						take(run, corner.id)
			elif share >= MIGRATED_ALL_AT:
				take_all(run, district_id)
			elif share >= MIGRATED_HOLD_SHARE:
				var plain_first := of(district_id).filter(func(corner: CornerDef) -> bool: return not corner.stronghold)
				for corner: CornerDef in plain_first.slice(0, MIGRATED_HELD_CORNERS):
					take(run, corner.id)


## Everyone working the district this phase, as corner id to an Array of SpeakerDef. Sellers stand at their own
## corner. Visitors, roamers and the police pick a corner each phase from the run seed, so a reload shows the same street.
static func people_at(run: RunState, district_id: StringName) -> Dictionary:
	var corners := of(district_id)
	var people := {}
	if corners.is_empty():
		return people
	var seller_corners := {}
	for corner in corners:
		people[corner.id] = []
		if not corner.seller.is_empty():
			seller_corners[corner.seller] = corner.id
	var stamp := Calendar.stamp(run)
	var everyone: Array[SpeakerDef] = []
	everyone.append_array(Roster.dealers_at(run, district_id, stamp))
	everyone.append_array(Roster.characters_at(run, district_id, stamp))
	for person in everyone:
		var drifting: StringName = corners[posmod(hash([run.price_seed, stamp, person.id]), corners.size())].id
		people[seller_corners.get(person.id, drifting)].append(person)
	return people


## Rent and protection from every corner the player holds, paid each morning.
static func daily_cut(run: RunState) -> int:
	var total := 0
	for corner_id in run.corners_held:
		var corner := find(StringName(corner_id))
		if corner != null:
			total += corner.daily_cut()
	return total


static func is_for_sale(run: RunState) -> bool:
	if holds(run, MAMA_LIN):
		return false
	return run.career or (Loan.is_with_vex(run) and run.rabbit_offer != DebtSale.RabbitOffer.NONE)


static func buy_mama_lin(run: RunState) -> Result:
	if not is_for_sale(run):
		return Result.NOT_FOR_SALE
	if run.cash < MAMA_LIN_PRICE:
		return Result.NOT_ENOUGH_CASH
	run.cash -= MAMA_LIN_PRICE
	take(run, MAMA_LIN)
	Story.mark(run, Armory.UNLOCK_FLAG)
	if Story.mark(run, RABBIT_JOINED):
		Crew.join_free(run, RABBIT_ROLE)
	return Result.OK


## Queues Tran's tip or Vex's answer to the purchase when a new day starts. Returns true when one was queued.
static func check(run: RunState, new_day_started: bool) -> bool:
	if not new_day_started or Encounters.has_pending(run):
		return false
	if is_for_sale(run) and Story.mark(run, TIP_SENT):
		run.pending_encounter = {
			"type": TIP,
			"speaker": String(TRAN),
			"title": "A message from Auntie Tran",
			"body": "Come by the bar tonight, child. There is talk you should hear before Vex does.",
		}
		return true
	if holds(run, MAMA_LIN) and Story.mark(run, STALL_DONE):
		run.pending_encounter = _smash_stall(run)
		return true
	return false


static func choices(_run: RunState, _encounter: Dictionary) -> Array[Encounters.Choice]:
	return [Encounters.Choice.new(Encounters.CONTINUE, "Continue")]


static func resolve(_run: RunState, encounter: Dictionary, _choice: StringName, _roll: float = 0.0) -> String:
	return str(encounter.get("losses", ""))


## The stall loses part of the player's stock, the stash first, and one paid hand quits.
static func _smash_stall(run: RunState) -> Dictionary:
	var stock := run.stash if not run.stash.is_empty() else run.inventory
	var lost_units := 0
	for item_id in stock.keys():
		var lost := ceili(int(stock[item_id]) * STALL_STOCK_LOSS)
		lost_units += lost
		stock[item_id] = int(stock[item_id]) - lost
		if int(stock[item_id]) <= 0:
			stock.erase(item_id)
	var summary := "The corner stall is smashed. A blade is stuck in the counter."
	if lost_units > 0:
		summary += " %d units of stock are gone." % lost_units
	var quitter := _paid_hand(run)
	if not quitter.is_empty():
		run.crew.erase(quitter)
		var role := Content.crew_role(StringName(str(quitter.role)))
		summary += " Your %s quit." % (role.display_name.to_lower() if role != null else "hired hand")
	return {
		"type": STALL_SMASHED,
		"speaker": String(VEX),
		"title": "A blade in the counter",
		"body": "Nice corner. Sell it back, or I take it back. You have a week.",
		"losses": summary,
	}


static func _paid_hand(run: RunState) -> Dictionary:
	for member in run.crew:
		if not Crew.is_free(member):
			return member
	return {}


static func sanitize(source: Variant) -> Array[String]:
	var clean: Array[String] = []
	if source is Array:
		for corner_id: Variant in source:
			if find(StringName(str(corner_id))) != null and not clean.has(str(corner_id)):
				clean.append(str(corner_id))
	return clean


static func sanitize_garrisons(run: RunState, source: Variant) -> Dictionary:
	var clean := {}
	if not source is Dictionary:
		return clean
	var total_active := Army.active(run)
	var allocated := 0
	for key: Variant in source:
		var corner_id := StringName(str(key))
		var corner := find(corner_id)
		if corner != null and holds(run, corner_id):
			var amount := clampi(int(source[key]), 0, CORNER_GARRISON_CAP)
			if total_active > 0 and allocated + amount > total_active:
				amount = maxi(0, total_active - allocated)
			if amount > 0:
				clean[String(corner_id)] = amount
				allocated += amount
	return clean


## Synchronizes territory ownership and garrisons to prevent state desync.
## Purges orphaned garrisons for unheld corners and clamps posted men to army limits.
static func sync(run: RunState) -> void:
	if run == null:
		return
	var valid_held: Array[String] = []
	for corner_id_str in run.corners_held:
		var corner := find(StringName(corner_id_str))
		if corner != null and not valid_held.has(corner_id_str):
			valid_held.append(corner_id_str)
	run.corners_held = valid_held
	run.player_garrisons = sanitize_garrisons(run, run.player_garrisons)
