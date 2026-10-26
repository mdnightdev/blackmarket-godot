class_name Orders

## Delivery work posted on bar boards. An order is stored as
## { id, venue, dealer, item, quantity, price, due, meet } where price is per unit, due is the last phase stamp to deliver
## in and meet the district the dealer agreed to come out to, empty for none. See Meetings.

enum Result { OK, FULL, TAKEN, EXPIRED, TOO_BIG }

const MAX_ACTIVE := 2
const POSTED_PER_DAY := 3
const ACT_ONE_POSTED_PER_DAY := 2
const PREMIUM_MIN := 1.35
const PREMIUM_MAX := 1.6
const LEAD_MIN_PHASES := 2
const LEAD_MAX_PHASES := 5
const MIN_QUANTITY := 1
const MAX_QUANTITY := 12
## Order value as a multiple of the client's district job pay. The player keeps the premium.
const ORDER_VALUE_PER_PAY := 1.75


## Today's open offers at a bar. Offers come from the run seed, so a reload cannot reroll them.
## Only dealers in districts the player can reach place orders.
static func board(run: RunState, venue_id: StringName) -> Array[Dictionary]:
	var day_index := run.day - 1
	var stamp := Calendar.stamp(run)
	var clients := _clients(run)
	var goods: Array[ItemDef] = []
	for item in Content.items(ItemDef.Kind.TRADE_GOOD):
		if not item.is_restricted():
			goods.append(item)
	var offers: Array[Dictionary] = []
	if clients.is_empty() or goods.is_empty():
		return offers
	for index in POSTED_PER_DAY if Campaign.is_act_two(run) else ACT_ONE_POSTED_PER_DAY:
		var offer := _post(run, venue_id, day_index, index, clients, goods)
		if int(offer.due) > stamp and not run.taken_orders.has(offer.id):
			offers.append(offer)
	return offers


static func check_accept(run: RunState, offer: Dictionary) -> Result:
	if run.orders.size() >= MAX_ACTIVE:
		return Result.FULL
	if run.taken_orders.has(offer.id):
		return Result.TAKEN
	if int(offer.due) < Calendar.stamp(run):
		return Result.EXPIRED
	if not fits_in_bag(run, offer):
		return Result.TOO_BIG
	return Result.OK


static func accept(run: RunState, offer: Dictionary) -> Result:
	var result := check_accept(run, offer)
	if result != Result.OK:
		return result
	run.orders.append(offer.duplicate())
	run.taken_orders.append(str(offer.id))
	return Result.OK


static func for_dealer(run: RunState, dealer: DealerDef) -> Array[Dictionary]:
	var dealer_id := String(dealer.id)
	var list: Array[Dictionary] = []
	for order in run.orders:
		if order.dealer == dealer_id:
			list.append(order)
	return list


static func can_deliver(run: RunState, order: Dictionary) -> bool:
	return int(order.due) >= Calendar.stamp(run) and Inventory.count(run, StringName(order.item)) >= int(order.quantity)


## Pays for the order as a sale at the agreed price and closes it. Returns false when it cannot be delivered.
static func deliver(run: RunState, order: Dictionary) -> bool:
	var item := Content.item(StringName(order.item))
	if item == null or not can_deliver(run, order):
		return false
	if Trade.sell(run, item, int(order.quantity), int(order.price)) != Trade.Result.OK:
		return false
	run.orders.erase(order)
	StreetCred.add(run, StreetCred.ORDER_DELIVERED)
	return true


static func client_district(order: Dictionary) -> StringName:
	var dealer := Content.dealer(StringName(str(order.get("dealer", ""))))
	return dealer.district_id if dealer != null else &""


## The dealer came out to the agreed spot and the goods are in the bag.
static func can_meet(run: RunState, order: Dictionary) -> bool:
	return Meetings.is_here(run, order) and run.district_id != client_district(order) and can_deliver(run, order)


## Sells the order to the dealer at the meeting price and closes it. Returns the cash taken, 0 when there is no meeting.
static func meet(run: RunState, order: Dictionary) -> int:
	var item := Content.item(StringName(order.item))
	if item == null or not can_meet(run, order):
		return 0
	var price := Meetings.unit_price(run, order, int(order.price))
	if Trade.sell(run, item, int(order.quantity), price) != Trade.Result.OK:
		return 0
	run.orders.erase(order)
	StreetCred.add(run, StreetCred.ORDER_DELIVERED)
	return price * int(order.quantity)


## Giving up an order costs the same as missing it: the dealer refuses to trade for the rest of the phase.
static func drop(run: RunState, order: Dictionary) -> void:
	run.orders.erase(order)
	Journal.mark_failed(run, str(order.id))
	run.walked_out[StringName(order.dealer)] = Calendar.stamp(run)
	StreetCred.add(run, StreetCred.JOB_MISSED)


## Closes orders whose deadline has passed and returns them.
static func expire(run: RunState) -> Array[Dictionary]:
	var stamp := Calendar.stamp(run)
	var missed: Array[Dictionary] = []
	for order in run.orders:
		if int(order.due) < stamp:
			missed.append(order)
	for order in missed:
		drop(run, order)
	var today := "%d" % (run.day - 1)
	run.taken_orders = run.taken_orders.filter(func(id: String) -> bool: return id.get_slice(":", 1) == today)
	return missed


## Whether the whole order could ever be carried at once with the current bag.
static func fits_in_bag(run: RunState, order: Dictionary) -> bool:
	var item := Content.item(StringName(order.item))
	return item != null and item.slots * int(order.quantity) <= Inventory.capacity(run)


static func slots_needed(order: Dictionary) -> int:
	var item := Content.item(StringName(order.item))
	return (item.slots if item != null else 1) * int(order.quantity)


static func total(order: Dictionary) -> int:
	return int(order.price) * int(order.quantity)


## What the order pays when the dealer comes out to meet the player.
static func meeting_total(order: Dictionary) -> int:
	return Meetings.offered_price(int(order.price)) * int(order.quantity)


static func sanitize(source: Dictionary) -> Dictionary:
	var clean := {
		"id": str(source.get("id", "")),
		"venue": str(source.get("venue", "")),
		"dealer": str(source.get("dealer", "")),
		"item": str(source.get("item", "")),
		"quantity": maxi(1, int(source.get("quantity", 1))),
		"price": maxi(1, int(source.get("price", 1))),
		"due": int(source.get("due", -1)),
	}
	Meetings.copy_spot(source, clean)
	return clean


## Resident dealers place orders, since they can always be found at home.
static func _clients(run: RunState) -> Array[DealerDef]:
	var list: Array[DealerDef] = []
	for dealer in Content.dealers():
		var home := Content.district(dealer.district_id)
		if dealer.is_resident() and home != null and not Travel.is_locked(run, home):
			list.append(dealer)
	list.sort_custom(func(a: DealerDef, b: DealerDef) -> bool: return String(a.id) < String(b.id))
	return list


static func _post(run: RunState, venue_id: StringName, day_index: int, index: int, clients: Array[DealerDef], goods: Array[ItemDef]) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run.price_seed, &"order", venue_id, day_index, index])
	var dealer := clients[rng.randi_range(0, clients.size() - 1)]
	var wanted := goods.filter(func(item: ItemDef) -> bool: return dealer.deals_in(item) and not dealer.sells(item))
	if wanted.is_empty():
		wanted = goods.filter(dealer.deals_in)
	var item: ItemDef = wanted[rng.randi_range(0, wanted.size() - 1)]
	var price := roundi(item.base_price * dealer.bias_for(item.category) * rng.randf_range(PREMIUM_MIN, PREMIUM_MAX))
	var most := MAX_QUANTITY if Campaign.is_act_two(run) else clampi(floori(float(Inventory.capacity(run)) / item.slots), MIN_QUANTITY, MAX_QUANTITY)
	var quantity := lot_size(PayScale.roll(rng, run, dealer.tier) * ORDER_VALUE_PER_PAY, price, MIN_QUANTITY, most)
	return {
		"id": "%s:%d:%d" % [venue_id, day_index, index],
		"venue": String(venue_id),
		"dealer": String(dealer.id),
		"item": String(item.id),
		"quantity": quantity,
		"price": maxi(1, roundi(price * Edges.order_pay_factor(run))),
		"due": day_index * RunState.Phase.size() + rng.randi_range(LEAD_MIN_PHASES, LEAD_MAX_PHASES),
	}


## How many units a job of this value asks for at the unit price.
static func lot_size(value: float, unit_price: int, least: int, most: int) -> int:
	return clampi(roundi(value / maxi(1, unit_price)), least, most)
