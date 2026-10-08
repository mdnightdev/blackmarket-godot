class_name Favours

## Work the triad lieutenants hand out. Each family posts a fresh board every day.
## Offers are { id, family, kind, item, quantity, price, due }: price is per unit for a delivery
## and the full amount for a tribute, due is the last phase stamp it can be done in.
## Tributes are paid on the spot. Accepted deliveries are stored without the kind.

enum Kind { DELIVERY, TRIBUTE }
enum Result { OK, BUSY, TAKEN, EXPIRED, NOT_ENOUGH_CASH, TOO_BIG }

const POSTED_PER_DAY := 2
const TRIBUTE_CHANCE := 0.35
const PREMIUM_MIN := 1.15
const PREMIUM_MAX := 1.35
const LEAD_MIN_PHASES := 2
const LEAD_MAX_PHASES := 4
const MIN_QUANTITY := 1
const MAX_QUANTITY := 10
const TRIBUTE_BASE := 300
const TRIBUTE_PER_DAY := 60

const DONE_GAIN := 15
const RIVAL_LOSS := 5
const MISSED_LOSS := 20


## Today's open offers from a family. Seeded by the run, so a reload cannot reroll them.
static func board(run: RunState, family: FamilyDef) -> Array[Dictionary]:
	var day_index := run.day - 1
	var stamp := Calendar.stamp(run)
	var goods := Tiers.goods(Tiers.STREET)
	var offers: Array[Dictionary] = []
	if goods.is_empty():
		return offers
	for index in POSTED_PER_DAY:
		var offer := _post(run, family, day_index, index, goods)
		if int(offer.due) >= stamp and not run.taken_favours.has(offer.id):
			offers.append(offer)
	return offers


static func accept(run: RunState, offer: Dictionary) -> Result:
	if run.taken_favours.has(offer.id):
		return Result.TAKEN
	if int(offer.due) < Calendar.stamp(run):
		return Result.EXPIRED
	var family_id := StringName(offer.family)
	if int(offer.kind) == Kind.TRIBUTE:
		if run.cash < int(offer.price):
			return Result.NOT_ENOUGH_CASH
		run.cash -= int(offer.price)
		_complete(run, family_id)
	else:
		if not active_for(run, family_id).is_empty():
			return Result.BUSY
		if not Orders.fits_in_bag(run, offer):
			return Result.TOO_BIG
		run.favours.append(sanitize(offer))
	run.taken_favours.append(str(offer.id))
	return Result.OK


## The delivery the player owes a family, empty when there is none.
static func active_for(run: RunState, family_id: StringName) -> Dictionary:
	for favour in run.favours:
		if favour.family == String(family_id):
			return favour
	return {}


static func can_deliver(run: RunState, favour: Dictionary) -> bool:
	return int(favour.due) >= Calendar.stamp(run) and Inventory.count(run, StringName(favour.item)) >= int(favour.quantity)


## Pays for the goods as a sale at the agreed price and raises standing. Returns false when it cannot be delivered.
static func deliver(run: RunState, favour: Dictionary) -> bool:
	var item := Content.item(StringName(favour.item))
	if item == null or not can_deliver(run, favour):
		return false
	if Trade.sell(run, item, int(favour.quantity), int(favour.price)) != Trade.Result.OK:
		return false
	run.favours.erase(favour)
	_complete(run, StringName(favour.family))
	return true


## Closes deliveries whose deadline has passed, costs standing for each, and returns them.
static func expire(run: RunState) -> Array[Dictionary]:
	var stamp := Calendar.stamp(run)
	var missed: Array[Dictionary] = []
	for favour in run.favours:
		if int(favour.due) < stamp:
			missed.append(favour)
	for favour in missed:
		run.favours.erase(favour)
		Families.shift(run, StringName(favour.family), -MISSED_LOSS)
		StreetCred.add(run, StreetCred.JOB_MISSED)
	var today := "%d" % (run.day - 1)
	run.taken_favours = run.taken_favours.filter(func(id: String) -> bool: return id.get_slice(":", 1) == today)
	return missed


static func total(favour: Dictionary) -> int:
	return int(favour.price) * int(favour.quantity)


## Returns an empty dictionary when the family or item no longer exists.
static func sanitize(source: Dictionary) -> Dictionary:
	var family_id := StringName(str(source.get("family", "")))
	var item_id := StringName(str(source.get("item", "")))
	if Content.family(family_id) == null or Content.item(item_id) == null:
		return {}
	return {
		"id": str(source.get("id", "")),
		"family": String(family_id),
		"item": String(item_id),
		"quantity": maxi(1, int(source.get("quantity", 1))),
		"price": maxi(1, int(source.get("price", 1))),
		"due": int(source.get("due", -1)),
	}


## Where the family's lieutenant takes deliveries. Empty when the family is gone.
static func lieutenant_district(family_id: StringName) -> StringName:
	var family := Content.family(family_id)
	if family == null:
		return &""
	var lieutenant := Content.character(family.lieutenant)
	if lieutenant != null and not lieutenant.district_id.is_empty():
		return lieutenant.district_id
	return family.home_districts[0] if not family.home_districts.is_empty() else &""


static func _complete(run: RunState, family_id: StringName) -> void:
	Families.shift(run, family_id, DONE_GAIN)
	StreetCred.add(run, StreetCred.FAVOUR_DONE)
	var family := Content.family(family_id)
	if family != null and not family.rival.is_empty():
		Families.shift(run, family.rival, -RIVAL_LOSS)


static func _post(run: RunState, family: FamilyDef, day_index: int, index: int, goods: Array[ItemDef]) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run.price_seed, &"favour", family.id, day_index, index])
	var offer := {
		"id": "%s:%d:%d" % [family.id, day_index, index],
		"family": String(family.id),
	}
	if rng.randf() < TRIBUTE_CHANCE:
		offer.merge({
			"kind": Kind.TRIBUTE,
			"item": "",
			"quantity": 0,
			"price": TRIBUTE_BASE + day_index * TRIBUTE_PER_DAY,
			"due": day_index * RunState.Phase.size() + RunState.Phase.NIGHT,
		})
		return offer
	var item: ItemDef = goods[rng.randi_range(0, goods.size() - 1)]
	var price := maxi(1, roundi(item.base_price * rng.randf_range(PREMIUM_MIN, PREMIUM_MAX)))
	offer.merge({
		"kind": Kind.DELIVERY,
		"item": String(item.id),
		"quantity": Orders.lot_size(PayScale.roll(rng, run, Tiers.STREET) * Orders.ORDER_VALUE_PER_PAY, price, MIN_QUANTITY, MAX_QUANTITY),
		"price": price,
		"due": day_index * RunState.Phase.size() + rng.randi_range(LEAD_MIN_PHASES, LEAD_MAX_PHASES),
	})
	return offer
