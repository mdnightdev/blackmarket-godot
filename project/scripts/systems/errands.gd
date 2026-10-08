class_name Errands

## Jobs the Shark sends to the player's phone. Offers wait in run.errand_offers until answered, accepted ones
## move to run.errands. Every entry has the same keys:
## { id, kind, sender, district, pickup_district, drop_district, debtor, owed, pay, lead, posted_stamp,
##   expires_stamp, due_stamp, picked_up }
## A collection sends the player to district to get owed from debtor; pay is the player's cut when all of it comes in.
## A delivery is picked up on arriving in pickup_district and dropped on arriving in drop_district.
## expires_stamp is the last phase stamp an offer can be accepted in. lead is the phases allowed once accepted and
## due_stamp the last phase stamp to finish in (-1 until accepted). Unused keys stay empty.

const COLLECTION := "collection"
const DELIVERY := "delivery"
const SENDER: StringName = Loan.LENDER
## Phases that start with a new offer from the Shark.
const POSTING_PHASES: Array[RunState.Phase] = [RunState.Phase.MORNING]
const MAX_OPEN_OFFERS := 3
const MAX_ACTIVE := 2
const OFFER_PHASES := 4
const MIN_LEAD_PHASES := 3
const MAX_LEAD_PHASES := 5
const COLLECTION_CHANCE := 0.5
## Pay for a finished errand at the lower ranks: the floor, the usual and the rare big job.
const PAY_LOW := 2000
const PAY_USUAL := 3500
const PAY_HIGH := 9000
## Pay grows by this share for every street cred rank above FLAT_PAY_RANKS.
const RANK_PAY_GROWTH := 0.25
const FLAT_PAY_RANKS := 2
const PAY_ROUNDING := 100
## The player's cut of what a debtor hands over. The rest goes to the Shark.
const COLLECTION_CUT := 0.4
## While the Shark is owed, this share of every errand's pay goes straight onto the debt.
const DEBT_SHARE := 0.6
const DEBTORS: Array[String] = [
	"Benny Tsai", "Marco Lin", "Dex Okafor", "Ivy Moreau", "Sal Kwan", "Nico Reyes", "Old Pao", "Teddy Ng",
]


## Posts the Shark's offer for this phase when it is a posting phase and the phone has room. Returns the new offers.
static func post(run: RunState) -> Array[Dictionary]:
	var posted: Array[Dictionary] = []
	if Campaign.is_over(run) or not POSTING_PHASES.has(run.phase) or run.errand_offers.size() >= MAX_OPEN_OFFERS:
		return posted
	var id := _id_for(Calendar.stamp(run))
	if not find_offer(run, id).is_empty() or not find(run, id).is_empty():
		return posted
	var offer := generate(run)
	if offer.is_empty():
		return posted
	run.errand_offers.append(offer)
	posted.append(offer)
	return posted


## The offer for this phase. It comes from the run seed, so a reload cannot reroll it. Empty when no districts fit.
static func generate(run: RunState) -> Dictionary:
	var rng := Odds.rng_for(run, &"errand")
	var places := _open_districts(run)
	if places.size() < 2:
		return {}
	var stamp := Calendar.stamp(run)
	var pay := _round_pay(Odds.bell(rng, PAY_LOW, PAY_USUAL, PAY_HIGH) * pay_scale(StreetCred.rank(run)))
	var offer := {
		"id": _id_for(stamp),
		"kind": COLLECTION,
		"sender": String(SENDER),
		"district": "",
		"pickup_district": "",
		"drop_district": "",
		"debtor": "",
		"owed": 0,
		"pay": pay,
		"lead": rng.randi_range(MIN_LEAD_PHASES, MAX_LEAD_PHASES),
		"posted_stamp": stamp,
		"expires_stamp": stamp + OFFER_PHASES - 1,
		"due_stamp": -1,
		"picked_up": false,
	}
	if rng.randf() < COLLECTION_CHANCE:
		offer.district = String(_pick(rng, places))
		offer.debtor = DEBTORS[rng.randi_range(0, DEBTORS.size() - 1)]
		offer.owed = _round_pay(pay / COLLECTION_CUT)
	else:
		var pickup := _pick(rng, places)
		places.erase(pickup)
		places.append(run.district_id)
		offer.kind = DELIVERY
		offer.pickup_district = String(pickup)
		offer.drop_district = String(_pick(rng, places))
	return offer


static func pay_scale(rank: int) -> float:
	return 1.0 + RANK_PAY_GROWTH * maxi(0, rank - FLAT_PAY_RANKS)


static func can_accept(run: RunState) -> bool:
	return run.errands.size() < MAX_ACTIVE


## Moves an offer to the accepted errands and starts its deadline. False when it is gone, expired or the hands are full.
static func accept(run: RunState, id: String) -> bool:
	var offer := find_offer(run, id)
	if offer.is_empty() or not can_accept(run) or int(offer.expires_stamp) < Calendar.stamp(run):
		return false
	run.errand_offers.erase(offer)
	var errand := offer.duplicate()
	errand.due_stamp = Calendar.stamp(run) + int(offer.lead)
	run.errands.append(errand)
	return true


static func decline(run: RunState, id: String) -> bool:
	var offer := find_offer(run, id)
	if offer.is_empty():
		return false
	run.errand_offers.erase(offer)
	return true


static func find_offer(run: RunState, id: String) -> Dictionary:
	for offer in run.errand_offers:
		if str(offer.id) == id:
			return offer
	return {}


## Phases an offer can still be accepted in, counting this one. 0 once it has expired.
static func phases_left(run: RunState, offer: Dictionary) -> int:
	return maxi(0, int(offer.get("expires_stamp", -1)) - Calendar.stamp(run) + 1)


## The district the player still has to travel to for this errand, null when they are already there.
static func next_stop(run: RunState, errand: Dictionary) -> DistrictDef:
	var target := target_district(errand)
	if target == run.district_id:
		return null
	return Content.district(target)


static func find(run: RunState, id: String) -> Dictionary:
	for errand in run.errands:
		if str(errand.id) == id:
			return errand
	return {}


## Drops offers nobody answered and fails errands past their deadline. Returns a notice for each failed errand.
static func expire(run: RunState) -> Array[Dictionary]:
	var stamp := Calendar.stamp(run)
	run.errand_offers = run.errand_offers.filter(func(offer: Dictionary) -> bool: return int(offer.expires_stamp) >= stamp)
	var notices: Array[Dictionary] = []
	for errand in run.errands.duplicate():
		if int(errand.due_stamp) >= stamp:
			continue
		run.errands.erase(errand)
		StreetCred.add(run, StreetCred.JOB_MISSED)
		notices.append({
			"line": "Missed the deadline on %s." % job_title(errand),
			"hint": "Errand failed. %+d cred" % StreetCred.JOB_MISSED,
		})
	return notices


## What happens on being in a district: packages are picked up or dropped, and a debtor waiting here is queued
## as an encounter when nothing else is. Returns notices for packages.
static func visit(run: RunState) -> Array[Dictionary]:
	var notices: Array[Dictionary] = []
	for errand in run.errands.duplicate():
		if str(errand.kind) != DELIVERY:
			continue
		var place := _place_name(target_district(errand))
		if not bool(errand.picked_up) and StringName(str(errand.pickup_district)) == run.district_id:
			errand.picked_up = true
			place = _place_name(target_district(errand))
			notices.append({
				"line": "Picked up the Shark's package.",
				"hint": "Drop it in %s by %s." % [place, Calendar.describe(int(errand.due_stamp)).to_lower()],
			})
		elif bool(errand.picked_up) and StringName(str(errand.drop_district)) == run.district_id:
			notices.append({
				"line": "Dropped the Shark's package in %s." % place,
				"hint": describe_payout(complete(run, errand)),
			})
	if Encounters.has_pending(run):
		return notices
	for errand in run.errands:
		if str(errand.kind) == COLLECTION and StringName(str(errand.district)) == run.district_id:
			run.pending_encounter = Collections.start(run, errand)
			break
	return notices


## Closes the errand, adds cred and pays the share of its pay that came in. Returns the payout split.
static func complete(run: RunState, errand: Dictionary, share := 1.0) -> Dictionary:
	run.errands.erase(errand)
	StreetCred.add(run, StreetCred.ERRAND_DONE)
	return pay_out(run, roundi(int(errand.pay) * share))


## Pays the player. While the Shark is owed, DEBT_SHARE goes onto the debt as a normal repayment.
## Returns { cash, debt } with what landed in each.
static func pay_out(run: RunState, amount: int) -> Dictionary:
	run.cash += amount
	run.profit += amount
	var to_debt := 0
	if not run.career:
		to_debt = mini(roundi(amount * DEBT_SHARE), Loan.max_repay(run))
		if to_debt > 0 and Loan.repay(run, to_debt):
			Campaign.start_career_if_cleared(run)
		else:
			to_debt = 0
	return { "cash": amount - to_debt, "debt": to_debt }


static func describe_payout(paid: Dictionary) -> String:
	var text := "+%s cash" % Format.money(int(paid.get("cash", 0)))
	if int(paid.get("debt", 0)) > 0:
		text += ", %s off your debt" % Format.money(int(paid.debt))
	return text


## Where the player has to go next for this errand.
static func target_district(errand: Dictionary) -> StringName:
	if str(errand.get("kind", "")) == COLLECTION:
		return StringName(str(errand.get("district", "")))
	if bool(errand.get("picked_up", false)):
		return StringName(str(errand.get("drop_district", "")))
	return StringName(str(errand.get("pickup_district", "")))


## One short line for what the errand asks right now.
static func describe(errand: Dictionary) -> String:
	var place := _place_name(target_district(errand))
	if str(errand.get("kind", "")) == COLLECTION:
		return "Collect %s from %s in %s" % [Format.money(int(errand.get("owed", 0))), str(errand.get("debtor", "")), place]
	if bool(errand.get("picked_up", false)):
		return "Drop the package in %s" % place
	return "Pick up a package in %s" % place


## Name used in deadline reminders.
static func job_title(errand: Dictionary) -> String:
	if str(errand.get("kind", "")) == COLLECTION:
		return "the Shark's money from %s" % str(errand.get("debtor", ""))
	return "the Shark's package"


## Returns an empty dictionary for entries that cannot be played.
static func sanitize(source: Dictionary) -> Dictionary:
	var id := str(source.get("id", ""))
	var kind := str(source.get("kind", ""))
	var pay := int(source.get("pay", 0))
	if id.is_empty() or pay <= 0 or not [COLLECTION, DELIVERY].has(kind):
		return {}
	var clean := {
		"id": id,
		"kind": kind,
		"sender": str(source.get("sender", SENDER)),
		"district": "",
		"pickup_district": "",
		"drop_district": "",
		"debtor": "",
		"owed": 0,
		"pay": pay,
		"lead": clampi(int(source.get("lead", MIN_LEAD_PHASES)), MIN_LEAD_PHASES, MAX_LEAD_PHASES),
		"posted_stamp": maxi(0, int(source.get("posted_stamp", 0))),
		"expires_stamp": int(source.get("expires_stamp", -1)),
		"due_stamp": int(source.get("due_stamp", -1)),
		"picked_up": false,
	}
	if kind == COLLECTION:
		var district := str(source.get("district", ""))
		var debtor := str(source.get("debtor", ""))
		var owed := int(source.get("owed", 0))
		if Content.district(StringName(district)) == null or debtor.is_empty() or owed <= 0:
			return {}
		clean.merge({ "district": district, "debtor": debtor, "owed": owed }, true)
	else:
		var pickup := str(source.get("pickup_district", ""))
		var drop := str(source.get("drop_district", ""))
		if Content.district(StringName(pickup)) == null or Content.district(StringName(drop)) == null or pickup == drop:
			return {}
		clean.merge({ "pickup_district": pickup, "drop_district": drop, "picked_up": bool(source.get("picked_up", false)) }, true)
	return clean


static func _id_for(stamp: int) -> String:
	return "errand:%d" % stamp


## Open districts other than the one the player stands in, sorted so the seed always picks the same one.
static func _open_districts(run: RunState) -> Array[StringName]:
	var list: Array[StringName] = []
	for district in Content.districts():
		if district.id != run.district_id and not Travel.is_locked(run, district):
			list.append(district.id)
	list.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return list


static func _pick(rng: RandomNumberGenerator, places: Array[StringName]) -> StringName:
	return places[rng.randi_range(0, places.size() - 1)]


static func _round_pay(amount: float) -> int:
	return maxi(PAY_ROUNDING, roundi(amount / PAY_ROUNDING) * PAY_ROUNDING)


static func _place_name(district_id: StringName) -> String:
	var district := Content.district(district_id)
	return district.display_name if district != null else String(district_id)
