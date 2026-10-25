class_name JobPings

## Bar orders, family deliveries and Voronin's crates that reach the player by phone instead of a board.
## A ping is stored as { id, source, offer, twist, expires_stamp } where offer is the board entry with the twist
## already applied, so accepting it takes exactly what the phone showed. id matches the board entry's id.

enum Twist { NONE, RUSH, HOT, FRAGILE, BIG_CLIENT }
enum Result { OK, GONE, BUSY, TOO_BIG, BANNED }

const ORDER := "order"
const FAVOUR := "favour"
const CRATE := "crate"
const SOURCES: Array[String] = [ORDER, FAVOUR, CRATE]

const POST_CHANCE := 0.45
## In Act 1 the phone rings less, and only with the best paying job on offer.
const ACT_ONE_POST_CHANCE := 0.25
const MAX_OPEN := 2
## Phases a ping can be answered in, counting the one it arrived in.
const OFFER_PHASES := 2
const TWIST_CHANCE := 0.45
const RUSH_PAY := 1.25
## A rush job is due by the end of the next phase.
const RUSH_PHASES := 1
const HOT_PAY := 1.3
## Heat the player takes on by accepting a hot job.
const HOT_HEAT := 12
const FRAGILE_PAY := 1.3
const BIG_CLIENT_QUANTITY := 2
const BIG_CLIENT_PAY := 1.15

const TWIST_NAMES := {
	Twist.RUSH: "Rush",
	Twist.HOT: "Hot",
	Twist.FRAGILE: "Fragile",
	Twist.BIG_CLIENT: "Big client",
}
const TWIST_HINTS := {
	Twist.RUSH: "Rush job: due by the end of next phase, pays more.",
	Twist.HOT: "Hot job: pays more, but taking it raises your heat.",
	Twist.FRAGILE: "Fragile crate: pays more, ambushes take twice as much.",
	Twist.BIG_CLIENT: "Big client: twice the goods, better money.",
}


## Posts this phase's ping when one comes in and the phone has room. Returns the new pings.
static func post(run: RunState) -> Array[Dictionary]:
	var posted: Array[Dictionary] = []
	if Campaign.is_over(run) or not run.tutorial_completed or run.job_pings.size() >= MAX_OPEN:
		return posted
	var rng := Odds.rng_for(run, &"job_ping")
	var act_two := Campaign.is_act_two(run)
	if rng.randf() >= (POST_CHANCE if act_two else ACT_ONE_POST_CHANCE):
		return posted
	var choices := candidates(run)
	if choices.is_empty():
		return posted
	var pick: Dictionary = choices[rng.randi_range(0, choices.size() - 1)] if act_two else _best_paying(choices)
	var ping := {
		"id": str(pick.offer.id),
		"source": str(pick.source),
		"offer": pick.offer,
		"twist": Twist.NONE,
		"expires_stamp": Calendar.stamp(run) + OFFER_PHASES - 1,
	}
	if rng.randf() < TWIST_CHANCE:
		var twists := twists_for(ping)
		apply_twist(run, ping, twists[rng.randi_range(0, twists.size() - 1)])
	run.job_pings.append(ping)
	run.seen_pings.append(str(ping.id))
	posted.append(ping)
	return posted


## Open board entries the player could take right now, as { source, offer }.
static func candidates(run: RunState) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	if run.orders.size() < Orders.MAX_ACTIVE:
		for venue_id in _reachable_bars(run):
			for offer in Orders.board(run, venue_id):
				list.append({ "source": ORDER, "offer": offer })
	for family in Content.families():
		if Families.tier(run, family.id) == Families.Tier.HOSTILE or not Favours.active_for(run, family.id).is_empty():
			continue
		for offer in Favours.board(run, family):
			if int(offer.kind) == Favours.Kind.DELIVERY:
				list.append({ "source": FAVOUR, "offer": offer })
	if not Smuggling.is_banned(run) and not Smuggling.is_carrying(run):
		for offer in Smuggling.board(run):
			if StringName(str(offer.destination)) != run.district_id:
				list.append({ "source": CRATE, "offer": offer })
	return list.filter(func(entry: Dictionary) -> bool:
		return not run.seen_pings.has(str(entry.offer.id)) and find(run, str(entry.offer.id)).is_empty())


static func twists_for(ping: Dictionary) -> Array[Twist]:
	var twists: Array[Twist] = [Twist.RUSH, Twist.HOT]
	match str(ping.source):
		CRATE:
			twists.append(Twist.FRAGILE)
		ORDER:
			var dealer := Content.dealer(StringName(str(ping.offer.dealer)))
			if dealer != null and dealer.tier >= Tiers.MIDDLE:
				twists.append(Twist.BIG_CLIENT)
	return twists


static func find(run: RunState, id: String) -> Dictionary:
	for ping in run.job_pings:
		if str(ping.id) == id:
			return ping
	return {}


## Takes the job the ping offers. A crate is handed over where the player stands.
static func accept(run: RunState, id: String) -> Result:
	var ping := find(run, id)
	if ping.is_empty() or int(ping.expires_stamp) < Calendar.stamp(run):
		return Result.GONE
	var offer: Dictionary = ping.offer
	var result := Result.OK
	match str(ping.source):
		ORDER:
			result = _from_order(Orders.accept(run, offer))
		FAVOUR:
			result = _from_favour(Favours.accept(run, offer))
		CRATE:
			result = _from_crate(Smuggling.accept(run, offer, [], false, run.district_id))
	if result != Result.OK:
		return result
	run.job_pings.erase(ping)
	if int(ping.twist) == Twist.HOT:
		Heat.add(run, HOT_HEAT)
	return Result.OK


static func decline(run: RunState, id: String) -> bool:
	var ping := find(run, id)
	if ping.is_empty():
		return false
	run.job_pings.erase(ping)
	return true


## Drops pings nobody answered in time and forgets yesterday's board entries.
static func expire(run: RunState) -> void:
	var stamp := Calendar.stamp(run)
	run.job_pings = run.job_pings.filter(func(ping: Dictionary) -> bool: return int(ping.expires_stamp) >= stamp)
	var today := "%d" % (run.day - 1)
	run.seen_pings = run.seen_pings.filter(func(id: String) -> bool: return id.get_slice(":", 1) == today)


## Who sends the ping: the client dealer, the family lieutenant or Voronin.
static func sender(ping: Dictionary) -> SpeakerDef:
	match str(ping.source):
		ORDER:
			return Content.dealer(StringName(str(ping.offer.dealer)))
		FAVOUR:
			var family := Content.family(StringName(str(ping.offer.family)))
			return Content.character(family.lieutenant) if family != null else null
	var docks := Content.venue(Smuggling.VENUE)
	return Content.character(docks.host) if docks != null else null


static func phases_left(run: RunState, ping: Dictionary) -> int:
	return maxi(0, int(ping.get("expires_stamp", -1)) - Calendar.stamp(run) + 1)


static func total_pay(ping: Dictionary) -> int:
	var offer: Dictionary = ping.offer
	if str(ping.source) == CRATE:
		return int(offer.pay)
	return int(offer.price) * int(offer.quantity)


## Where the player has to go next to finish the job.
static func destination(ping: Dictionary) -> DistrictDef:
	var offer: Dictionary = ping.offer
	match str(ping.source):
		ORDER:
			var dealer := Content.dealer(StringName(str(offer.dealer)))
			return Content.district(dealer.district_id) if dealer != null else null
		FAVOUR:
			return Content.district(Favours.lieutenant_district(StringName(str(offer.family))))
	return Content.district(StringName(str(offer.destination)))


## The banner line, for example "Mama Lin has a job. Wanna check it out?"
static func headline(ping: Dictionary) -> String:
	var speaker := sender(ping)
	var who := speaker.display_name if speaker != null else "Someone"
	var twist := int(ping.twist)
	if twist == Twist.NONE:
		return "%s has a job. Wanna check it out?" % who
	return "%s has a %s job. Wanna check it out?" % [who, String(TWIST_NAMES[twist]).to_lower()]


## What the sender asks for when the player opens the ping.
static func pitch(ping: Dictionary) -> String:
	var offer: Dictionary = ping.offer
	var pay := Format.money(total_pay(ping))
	var place := destination(ping)
	var place_name := place.display_name if place != null else "town"
	if str(ping.source) == CRATE:
		return "A sealed crate, %d slots, has to reach %s. My runner can meet you where you are. %s on delivery." % [
			int(offer.slots), place_name, pay,
		]
	var item := Content.item(StringName(str(offer.item)))
	var goods := item.display_name if item != null else str(offer.item)
	var terms := TierVoice.pick(TierVoice.PAY_TERMS, place.tier if place != null else Tiers.STREET) % pay
	return "I need %d %s in %s, %s. %s" % [
		int(offer.quantity), goods, place_name, Calendar.describe(int(offer.due)).to_lower(), terms,
	]


static func sanitize(source: Dictionary) -> Dictionary:
	var kind := str(source.get("source", ""))
	var saved_offer: Variant = source.get("offer", {})
	if not SOURCES.has(kind) or not saved_offer is Dictionary:
		return {}
	var offer: Dictionary = {}
	match kind:
		ORDER:
			offer = Orders.sanitize(saved_offer)
		FAVOUR:
			offer = Favours.sanitize(saved_offer)
			if not offer.is_empty():
				offer.kind = Favours.Kind.DELIVERY
		CRATE:
			offer = Smuggling.sanitize(saved_offer)
	if offer.is_empty():
		return {}
	return {
		"id": str(offer.id),
		"source": kind,
		"offer": offer,
		"twist": clampi(int(source.get("twist", Twist.NONE)), 0, Twist.size() - 1),
		"expires_stamp": int(source.get("expires_stamp", -1)),
	}


static func apply_twist(run: RunState, ping: Dictionary, twist: Twist) -> void:
	var offer: Dictionary = ping.offer
	var is_crate := str(ping.source) == CRATE
	ping.twist = twist
	match twist:
		Twist.RUSH:
			if is_crate:
				offer.lead = Smuggling.MIN_LEAD_PHASES
			else:
				offer.due = mini(int(offer.due), Calendar.stamp(run) + RUSH_PHASES)
			_raise_pay(offer, is_crate, RUSH_PAY)
		Twist.HOT:
			_raise_pay(offer, is_crate, HOT_PAY)
		Twist.FRAGILE:
			offer.fragile = true
			_raise_pay(offer, is_crate, FRAGILE_PAY)
		Twist.BIG_CLIENT:
			offer.quantity = int(offer.quantity) * BIG_CLIENT_QUANTITY
			_raise_pay(offer, is_crate, BIG_CLIENT_PAY)


static func _raise_pay(offer: Dictionary, is_crate: bool, factor: float) -> void:
	if is_crate:
		offer.pay = roundi(int(offer.pay) * factor / Smuggling.PAY_ROUNDING) * Smuggling.PAY_ROUNDING
	else:
		offer.price = maxi(1, roundi(int(offer.price) * factor))


static func _best_paying(choices: Array[Dictionary]) -> Dictionary:
	var best := choices[0]
	for choice in choices:
		if total_pay(choice) > total_pay(best):
			best = choice
	return best


static func _reachable_bars(run: RunState) -> Array[StringName]:
	var bars: Array[StringName] = []
	for district in Content.districts():
		if Travel.is_locked(run, district):
			continue
		for venue_id in district.venues:
			var venue := Content.venue(venue_id)
			var host := Content.character(venue.host) if venue != null else null
			if host != null and host.role == CharacterDef.Role.BARTENDER and not bars.has(venue_id):
				bars.append(venue_id)
	return bars


static func _from_order(result: Orders.Result) -> Result:
	match result:
		Orders.Result.OK:
			return Result.OK
		Orders.Result.FULL:
			return Result.BUSY
		Orders.Result.TOO_BIG:
			return Result.TOO_BIG
	return Result.GONE


static func _from_favour(result: Favours.Result) -> Result:
	match result:
		Favours.Result.OK:
			return Result.OK
		Favours.Result.BUSY:
			return Result.BUSY
		Favours.Result.TOO_BIG:
			return Result.TOO_BIG
	return Result.GONE


static func _from_crate(result: Smuggling.Result) -> Result:
	match result:
		Smuggling.Result.OK:
			return Result.OK
		Smuggling.Result.CARRYING:
			return Result.BUSY
		Smuggling.Result.NO_ROOM:
			return Result.TOO_BIG
		Smuggling.Result.BANNED:
			return Result.BANNED
	return Result.GONE
