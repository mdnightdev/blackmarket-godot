class_name Errands

## Jobs the Shark sends to the player's phone. After he sells the debt, Vex sends them instead and pays nothing. Offers wait in run.errand_offers until answered, accepted ones
## move to run.errands. Every entry has the same keys:
## { id, kind, flavor, sender, district, pickup_district, drop_district, debtor, owed, pay, lead, posted_stamp,
##   expires_stamp, due_stamp, picked_up }
## flavor dresses up a Shark delivery: a package, an envelope for Ramos, or Voronin's crate picked up at the docks.
## A collection sends the player to district to get owed from debtor; pay is the player's cut when all of it comes in.
## A delivery is picked up on arriving in pickup_district and dropped on arriving in drop_district.
## expires_stamp is the last phase stamp an offer can be accepted in. lead is the phases allowed once accepted and
## due_stamp the last phase stamp to finish in (-1 until accepted). Unused keys stay empty.

const COLLECTION := "collection"
const DELIVERY := "delivery"
const PACKAGE := "package"
const ENVELOPE := "envelope"
const PIER := "pier"
const PIER_DISTRICT: StringName = &"docks"
const ENVELOPE_CHANCE := 0.3
const RAMOS: StringName = &"officer"
const VORONIN: StringName = &"voronin"
const SENDER: StringName = Loan.LENDER
## Phases that start with a new offer from the Shark.
const POSTING_PHASES: Array[RunState.Phase] = [RunState.Phase.MORNING]
const MAX_OPEN_OFFERS := 3
const MAX_ACTIVE := 2
const OFFER_PHASES := 4
const MIN_LEAD_PHASES := 3
const MAX_LEAD_PHASES := 5
const COLLECTION_CHANCE := 0.5
const PAY_ROUNDING := 100
## The player's cut of what a debtor hands over. The rest goes to the Shark.
const COLLECTION_CUT := 0.4
## While the Shark is owed, this share of every errand's pay goes straight onto the debt.
const DEBT_SHARE := 0.6
const DEBTORS: Array[String] = [
	"Benny Tsai", "Marco Silva", "Dex Tavares", "Ivy Kowalczyk", "Sal Kwan", "Nico Petrakis", "Old Bashir", "Teddy Ng",
]


## Posts the Shark's offer for this phase when it is a posting phase and the phone has room. Returns the new offers.
static func post(run: RunState) -> Array[Dictionary]:
	var posted: Array[Dictionary] = []
	if Campaign.is_over(run) or not POSTING_PHASES.has(run.phase) or run.errand_offers.size() >= MAX_OPEN_OFFERS:
		return posted
	if run.shark_bought:
		return posted
	if Loan.is_with_vex(run) and run.career:
		return posted
	if PayScale.outgrown(run, Tiers.STREET):
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
## The Shark only works the street, so errands stay in street districts.
static func generate(run: RunState) -> Dictionary:
	var rng := Odds.rng_for(run, &"errand")
	var places := _open_districts(run)
	if places.size() < 2:
		return {}
	var stamp := Calendar.stamp(run)
	var pay := _round_pay(PayScale.roll(rng, run, Tiers.STREET))
	var sender := run.lender if not run.career else SENDER
	var offer := {
		"id": _id_for(stamp),
		"kind": COLLECTION,
		"flavor": PACKAGE,
		"sender": String(sender),
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
		if sender == SENDER:
			offer.flavor = _flavor(rng, pickup)
	if sender == Loan.VEX_LENDER:
		offer.pay = 0
	return offer


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
	_let_down(run, offer, SharkTrust.ERRAND_DECLINED)
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
		_let_down(run, errand, SharkTrust.ERRAND_FAILED)
		var notice := {
			"line": "Missed the deadline on %s." % job_title(errand),
			"hint": "Errand failed. %+d cred" % StreetCred.JOB_MISSED,
		}
		if is_from_shark(errand):
			notice.merge({ "speaker": String(SENDER), "line": "Late is a kind of no." }, true)
			notice.hint = "Missed the deadline on %s. %s" % [job_title(errand), notice.hint]
		notices.append(notice)
	return notices


## What happens on being in a district: packages are picked up or dropped, and a debtor waiting here is queued
## as an encounter when nothing else is. Returns notices for packages.
static func visit(run: RunState) -> Array[Dictionary]:
	var notices: Array[Dictionary] = []
	for errand in run.errands.duplicate():
		if str(errand.kind) != DELIVERY:
			continue
		var place := _place_name(target_district(errand))
		var flavor := str(errand.get("flavor", PACKAGE))
		if not bool(errand.picked_up) and StringName(str(errand.pickup_district)) == run.district_id:
			errand.picked_up = true
			place = _place_name(target_district(errand))
			var picked_up := {
				"line": "Picked up %s %s." % [possessive(errand), noun(errand)],
				"hint": "Drop it in %s by %s." % [place, Calendar.describe(int(errand.due_stamp)).to_lower()],
			}
			if flavor == PIER:
				picked_up.merge({ "speaker": String(VORONIN), "line": "Do not open it. The Shark knows what is inside, and so do I. You do not." }, true)
			notices.append(picked_up)
		elif bool(errand.picked_up) and StringName(str(errand.drop_district)) == run.district_id:
			var dropped := {
				"line": "Dropped %s %s in %s." % [possessive(errand), noun(errand), place],
				"hint": describe_payout(complete(run, errand)),
			}
			if flavor == ENVELOPE:
				dropped.merge({ "speaker": String(RAMOS), "line": "Tell the old man the docks are quiet this week. Now keep walking, amigo." }, true)
			notices.append(dropped)
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
	if is_from_shark(errand):
		SharkTrust.add(run, SharkTrust.ERRAND_DONE)
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
			SharkTrust.check_promise(run)
		else:
			to_debt = 0
	return { "cash": amount - to_debt, "debt": to_debt }


static func describe_payout(paid: Dictionary) -> String:
	if int(paid.get("cash", 0)) <= 0 and int(paid.get("debt", 0)) <= 0:
		return "No pay. It only keeps Vex off your back."
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
		return "Drop the %s in %s" % [noun(errand), place]
	return "Pick up the %s in %s" % [noun(errand), place]


## Name used in deadline reminders.
static func job_title(errand: Dictionary) -> String:
	if str(errand.get("kind", "")) == COLLECTION:
		return "%s money from %s" % [possessive(errand), str(errand.get("debtor", ""))]
	return "%s %s" % [possessive(errand), noun(errand)]


## "package", "envelope" or "crate".
static func noun(errand: Dictionary) -> String:
	match str(errand.get("flavor", PACKAGE)):
		ENVELOPE:
			return "envelope"
		PIER:
			return "crate"
	return "package"


## What the errand pays, as shown on the phone.
static func pay_label(errand: Dictionary) -> String:
	var pay := int(errand.get("pay", 0))
	return Format.money(pay) if pay > 0 else "Unpaid"


static func is_from_shark(errand: Dictionary) -> bool:
	return StringName(str(errand.get("sender", SENDER))) == SENDER


## "the Shark's" or "Vex's", for lines about the errand.
static func possessive(errand: Dictionary) -> String:
	return "the Shark's" if is_from_shark(errand) else "Vex's"


## The one the debtor owes, for the collection scene.
static func creditor(errand: Dictionary) -> String:
	return "the Shark" if is_from_shark(errand) else "Vex"


## Returns an empty dictionary for entries that cannot be played.
static func sanitize(source: Dictionary) -> Dictionary:
	var id := str(source.get("id", ""))
	var kind := str(source.get("kind", ""))
	var pay := int(source.get("pay", 0))
	var sender := str(source.get("sender", SENDER))
	if sender != String(Loan.VEX_LENDER):
		sender = String(SENDER)
	var unpaid := sender == String(Loan.VEX_LENDER)
	if id.is_empty() or pay < 0 or (pay == 0 and not unpaid) or not [COLLECTION, DELIVERY].has(kind):
		return {}
	var clean := {
		"id": id,
		"kind": kind,
		"flavor": PACKAGE,
		"sender": sender,
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
		var flavor := str(source.get("flavor", PACKAGE))
		if not [PACKAGE, ENVELOPE, PIER].has(flavor) or unpaid:
			flavor = PACKAGE
		clean.merge({
			"pickup_district": pickup, "drop_district": drop, "flavor": flavor, "picked_up": bool(source.get("picked_up", false)),
		}, true)
	return clean


## The Shark loses trust when let down. Vex sends her crew instead.
static func _let_down(run: RunState, errand: Dictionary, trust_loss: int) -> void:
	if is_from_shark(errand):
		SharkTrust.add(run, trust_loss)
	else:
		DebtSale.send_crew(run)


static func _flavor(rng: RandomNumberGenerator, pickup: StringName) -> String:
	if pickup == PIER_DISTRICT:
		return PIER
	return ENVELOPE if rng.randf() < ENVELOPE_CHANCE else PACKAGE


static func _id_for(stamp: int) -> String:
	return "errand:%d" % stamp


## Open districts other than the one the player stands in, sorted so the seed always picks the same one.
static func _open_districts(run: RunState) -> Array[StringName]:
	var list: Array[StringName] = []
	for district in Content.districts():
		if district.id != run.district_id and district.tier == Tiers.STREET and not Travel.is_locked(run, district):
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
