class_name Customers

## Street customers post orders to the player's phone. Offers wait in run.customer_offers until answered,
## accepted ones move to run.customer_orders. Every entry has the same keys:
## { id, customer, item, quantity, unit_price, street_price, district, temperament, rush, lead, posted_stamp,
##   expires_stamp, due_stamp, counter_price, countered }
## unit_price is what the customer pays per unit and street_price the average asking price of the dealers stocking
## the goods when it was posted.
## temperament is the customer's CustomerDef.Temperament at posting. expires_stamp is the last phase stamp an offer can
## be accepted in, lead the phases allowed once accepted and due_stamp the last phase stamp to hand over in (-1 until
## accepted). counter_price is a haggler's lower price per unit (0 for everyone else) and countered turns true once he
## has asked for it at the handover. CustomerOffers posts and prices the offers.

const MAX_OPEN_OFFERS := 3
const MAX_ACTIVE := 3
const HAGGLE_TRY_CHANCE := 0.8
## Strength lead when holding firm against a haggler, before street cred.
const HOLD_FIRM_EDGE := 0.0
## Chance per phase that a flaky customer calls off an accepted order.
const FLAKE_CHANCE := 0.15
## Shown with every order so the player can read the customer before saying yes.
const TELLS := {
	CustomerDef.Temperament.LOWBALLER: "Knows the street price and pays under it.",
	CustomerDef.Temperament.FAIR: "Pays a fair price. No games.",
	CustomerDef.Temperament.GENEROUS: "Pays well and does not like to wait.",
	CustomerDef.Temperament.BULK: "Big order, thin margin on every unit.",
	CustomerDef.Temperament.HAGGLER: "Likes to renegotiate at the handover.",
	CustomerDef.Temperament.FLAKY: "Has called off deals before.",
	CustomerDef.Temperament.STING: "Pays too well. Asks too many questions.",
}


static func can_accept(run: RunState) -> bool:
	return run.customer_orders.size() < MAX_ACTIVE


## Moves an offer to the accepted orders and starts its deadline. False when it is gone, expired or the hands are full.
static func accept(run: RunState, id: String) -> bool:
	var offer := find_offer(run, id)
	if offer.is_empty() or not can_accept(run) or int(offer.expires_stamp) < Calendar.stamp(run):
		return false
	run.customer_offers.erase(offer)
	var order := offer.duplicate()
	order.due_stamp = Calendar.stamp(run) + int(offer.lead)
	run.customer_orders.append(order)
	return true


static func decline(run: RunState, id: String) -> bool:
	var offer := find_offer(run, id)
	if offer.is_empty():
		return false
	run.customer_offers.erase(offer)
	return true


static func find_offer(run: RunState, id: String) -> Dictionary:
	for offer in run.customer_offers:
		if str(offer.id) == id:
			return offer
	return {}


static func find(run: RunState, id: String) -> Dictionary:
	for order in run.customer_orders:
		if str(order.id) == id:
			return order
	return {}


## Phases an offer can still be accepted in, counting this one. 0 once it has expired.
static func phases_left(run: RunState, offer: Dictionary) -> int:
	return maxi(0, int(offer.get("expires_stamp", -1)) - Calendar.stamp(run) + 1)


## An accepted order can be handed over in the customer's district, before the deadline, with every unit in the bag.
static func can_hand_over(run: RunState, order: Dictionary) -> bool:
	if find(run, str(order.get("id", ""))).is_empty() or int(order.due_stamp) < Calendar.stamp(run):
		return false
	return StringName(str(order.district)) == run.district_id and is_stocked(run, order)


## Every unit of the order is in the bag.
static func is_stocked(run: RunState, order: Dictionary) -> bool:
	return Inventory.count(run, StringName(str(order.get("item", "")))) >= int(order.get("quantity", 0))


## Returns { paid, haggled, sting, walked, line, tasks }, empty when the handover cannot happen. paid is the cash taken
## in and tasks the daily tasks the sale finished. A haggler who asks for less sets haggled and keeps the order open
## until answer_haggle. An undercover buyer closes the order and queues a police stop.
## The roll decides whether a haggler tries it on and must be in the range [0, 1).
static func hand_over(run: RunState, order: Dictionary, roll: float) -> Dictionary:
	if not can_hand_over(run, order):
		return {}
	var name := customer_name(order)
	match int(order.temperament):
		CustomerDef.Temperament.STING:
			run.customer_orders.erase(order)
			run.pending_encounter = Encounters.police_stop(run)
			var sting := _result("%s takes one look at the goods and flashes a badge. It was a setup." % name)
			sting.sting = true
			return sting
		CustomerDef.Temperament.HAGGLER:
			if bool(order.countered) or roll < HAGGLE_TRY_CHANCE:
				order.countered = true
				var haggled := _result("%s turns the goods over and frowns. \"%s a unit. Not a dollar more.\"" % [name, Format.money(int(order.counter_price))])
				haggled.haggled = true
				return haggled
	return _complete(run, order, int(order.unit_price), "%s counts out %s and takes the goods." % [name, Format.money(total(order))])


## Settles a haggler's counter offer: take the lower price, or hold firm and either get the full price or watch
## the customer walk. Returns the same layout as hand_over, empty when there is no counter offer to answer.
static func answer_haggle(run: RunState, order: Dictionary, accept_counter: bool, roll: float) -> Dictionary:
	if not bool(order.get("countered", false)) or not can_hand_over(run, order):
		return {}
	var name := customer_name(order)
	if accept_counter:
		var lower := int(order.counter_price) * int(order.quantity)
		return _complete(run, order, int(order.counter_price), "You take %s. %s pockets the goods, pleased with the deal." % [Format.money(lower), name])
	if roll < hold_firm_chance(run):
		return _complete(run, order, int(order.unit_price), "%s holds your stare, then pays the full %s." % [name, Format.money(total(order))])
	run.customer_orders.erase(order)
	var walked := _result("%s shrugs and walks off. The deal is dead and the goods stay in your bag." % name)
	walked.walked = true
	return walked


static func hold_firm_chance(run: RunState) -> float:
	return Odds.contest(HOLD_FIRM_EDGE + Talk.cred_edge(run))


## Drops offers nobody answered, fails orders past their deadline and lets flaky customers back out.
## Returns a notice for each order that closed.
static func expire(run: RunState) -> Array[Dictionary]:
	var stamp := Calendar.stamp(run)
	run.customer_offers = run.customer_offers.filter(func(offer: Dictionary) -> bool: return int(offer.expires_stamp) >= stamp)
	var notices: Array[Dictionary] = []
	for order in run.customer_orders.duplicate():
		if int(order.due_stamp) < stamp:
			run.customer_orders.erase(order)
			StreetCred.add(run, StreetCred.CUSTOMER_MISSED)
			notices.append({
				"line": "Missed the handover of %s." % job_title(order),
				"hint": "Order failed. %+d cred" % StreetCred.CUSTOMER_MISSED,
			})
		elif flakes(run, order):
			run.customer_orders.erase(order)
			notices.append({
				"line": "%s called off the order for %s." % [customer_name(order), goods_label(order)],
				"hint": "Nothing to deliver. No cred lost.",
			})
	return notices


## Rolled once per phase after the order was accepted, so a reload cannot change the answer.
static func flakes(run: RunState, order: Dictionary) -> bool:
	if int(order.temperament) != CustomerDef.Temperament.FLAKY:
		return false
	var accepted_stamp := int(order.due_stamp) - int(order.lead)
	if Calendar.stamp(run) <= accepted_stamp:
		return false
	return Odds.rng_for(run, StringName("flake:%s" % order.id)).randf() < FLAKE_CHANCE


## Queues the handover prompt when a customer waiting here can be served and nothing else is pending.
static func visit(run: RunState) -> void:
	if Encounters.has_pending(run):
		return
	for order in run.customer_orders:
		if can_hand_over(run, order):
			run.pending_encounter = CustomerHandover.start(run, order)
			return


static func total(order: Dictionary) -> int:
	return int(order.get("unit_price", 0)) * int(order.get("quantity", 0))


static func customer_name(order: Dictionary) -> String:
	var customer := Content.customer(StringName(str(order.get("customer", ""))))
	return customer.display_name if customer != null else "The buyer"


## Name used in deadline reminders, for example "12 Burner Phones for Rosa Delgado".
static func job_title(order: Dictionary) -> String:
	return "%s for %s" % [goods_label(order), customer_name(order)]


## Goods and pay, for example "12 Burner Phones for $2,700".
static func headline(order: Dictionary) -> String:
	return "%s for %s" % [goods_label(order), Format.money(total(order))]


static func district_name(order: Dictionary) -> String:
	var district := Content.district(StringName(str(order.get("district", ""))))
	return district.display_name if district != null else str(order.get("district", ""))


## Quantity and goods, for example "12 Burner Phones".
static func goods_label(order: Dictionary) -> String:
	var item := Content.item(StringName(str(order.get("item", ""))))
	return "%d %s" % [int(order.get("quantity", 0)), item.display_name if item != null else "goods"]


## What the player can read about the customer before accepting.
static func tell(order: Dictionary) -> String:
	return str(TELLS.get(int(order.get("temperament", -1)), ""))


## Returns an empty dictionary for entries that cannot be played.
static func sanitize(source: Dictionary) -> Dictionary:
	var id := str(source.get("id", ""))
	var customer := Content.customer(StringName(str(source.get("customer", ""))))
	var item := Content.item(StringName(str(source.get("item", ""))))
	var district := str(source.get("district", ""))
	var temperament := int(source.get("temperament", -1))
	var quantity := int(source.get("quantity", 0))
	var unit_price := int(source.get("unit_price", 0))
	if id.is_empty() or customer == null or item == null or item.is_equipment() or Content.district(StringName(district)) == null:
		return {}
	if quantity <= 0 or unit_price <= 0 or not CustomerDef.Temperament.values().has(temperament):
		return {}
	var counter_price := clampi(int(source.get("counter_price", 0)), 0, unit_price)
	return {
		"id": id,
		"customer": String(customer.id),
		"item": String(item.id),
		"quantity": quantity,
		"unit_price": unit_price,
		"street_price": maxi(1, int(source.get("street_price", unit_price))),
		"district": district,
		"temperament": temperament,
		"rush": bool(source.get("rush", false)),
		"lead": clampi(int(source.get("lead", CustomerOffers.MIN_LEAD_PHASES)), CustomerOffers.MIN_RUSH_PHASES, CustomerOffers.MAX_LEAD_PHASES),
		"posted_stamp": maxi(0, int(source.get("posted_stamp", 0))),
		"expires_stamp": int(source.get("expires_stamp", -1)),
		"due_stamp": int(source.get("due_stamp", -1)),
		"counter_price": counter_price,
		"countered": bool(source.get("countered", false)) and counter_price > 0,
	}


static func _complete(run: RunState, order: Dictionary, unit_price: int, line: String) -> Dictionary:
	var item := Content.item(StringName(str(order.item)))
	var quantity := int(order.quantity)
	if item == null or Trade.sell(run, item, quantity, unit_price) != Trade.Result.OK:
		return {}
	run.customer_orders.erase(order)
	StreetCred.add(run, StreetCred.ORDER_DELIVERED)
	Heat.add(run, Heat.for_trade(run, item, quantity))
	var result := _result(line)
	result.paid = unit_price * quantity
	result.tasks = DailyTasks.record_sale(run, run.district_id, unit_price * quantity)
	return result


static func _result(line: String) -> Dictionary:
	var tasks: Array[Dictionary] = []
	return { "paid": 0, "haggled": false, "sting": false, "walked": false, "line": line, "tasks": tasks }
