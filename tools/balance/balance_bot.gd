extends RefCounted

## Plays one run through GameState with a fixed strategy and records where the money went.
## Net worth counts cash, plus carried goods at base price, minus debt.
## Every strategy pays the Shark's weekly minimum when it falls due and puts cash above a trading float into the debt.
## The broker fills customer orders from the best known source and runs the Shark's errands, without speculating.

const IDLE: StringName = &"idle"
const LOCAL: StringName = &"local"
const ROUTE: StringName = &"route"
const BROKER: StringName = &"broker"

const CHECKPOINT_DAYS: Array[int] = [7, 14, 30, 60]
const BUY_BELOW_BASE := 0.92
const SELL_ABOVE_COST := 1.05
const ROUTE_MIN_MARGIN := 0.15
const CASH_RESERVE := 150
const TRADING_FLOAT := 4000
const BRIBE_SHARE_OF_CASH := 0.25
const VEX_BRIBE_SHARE_OF_CASH := 0.2
## The broker keeps more cash on hand, since orders are paid for up front.
const BROKER_FLOAT := 12000
## Least profit, as a share of the goods cost, for the broker to take an order.
const BROKER_MIN_MARGIN := 0.08
## Least margin left when buying an order's goods from whoever is here.
const STOCK_MIN_MARGIN := 0.03
const SPARE_SELL_FLOOR := 0.95
const HOLD_FIRM_FROM := 0.6
## Bags the broker buys once its cash reaches this many times the price.
const BAG_IDS: Array[StringName] = [&"messenger_bag", &"duffel_bag"]
const BAG_CASH_MULTIPLE := 4

var _game_state: Node
var _content: Node
var _ledger: Dictionary = {}
var _counts: Dictionary = {}
var _realized := 0
var _order_results: Dictionary = {}
var _errands_taken: Dictionary = {}


func _init(game_state: Node, content: Node) -> void:
	_game_state = game_state
	_content = content


func play(strategy: StringName, seed_value: int, days: int) -> Dictionary:
	_game_state.start_new_run()
	var run: RunState = _game_state.run
	run.price_seed = seed_value
	_game_state.get("_rng").seed = seed_value
	_ledger = {}
	_counts = {}
	_realized = 0
	_order_results = {}
	_errands_taken = {}
	var start_worth := _worth(run)
	var checkpoints := {}
	var phases_left := days * RunState.Phase.size()
	var cleared_day := 0
	var missed_weeks := 0
	var worst_streak := 0

	while phases_left > 0 and not Campaign.is_over(run):
		phases_left -= 1
		_resolve_pending(run)
		var day_before := run.day
		var streak_before := run.missed_weeks
		match strategy:
			LOCAL:
				_trade_here(run)
				_pass_phase(run, &"")
			ROUTE:
				_trade_here(run)
				_pass_phase(run, _best_destination(run))
			BROKER:
				_broker_turn(run)
				_pass_phase(run, _broker_destination(run))
				_track_errands(run)
			_:
				_pay_shark(run)
				_pass_phase(run, &"")
		if run.missed_weeks > streak_before:
			missed_weeks += 1
		worst_streak = maxi(worst_streak, run.missed_weeks)
		if run.career and cleared_day == 0:
			cleared_day = run.day
		if run.day != day_before and CHECKPOINT_DAYS.has(day_before):
			checkpoints[day_before] = _worth(run) - start_worth
	_resolve_pending(run)
	checkpoints[days] = _worth(run) - start_worth

	return {
		"checkpoints": checkpoints,
		"ledger": _ledger,
		"counts": _counts,
		"orders": _order_results,
		"lost": run.outcome == RunState.Outcome.LOST,
		"lost_day": run.day if run.outcome == RunState.Outcome.LOST else 0,
		"cleared_day": cleared_day,
		"missed_weeks": missed_weeks,
		"worst_streak": worst_streak,
		"busts": run.busts,
		"realized_profit": _realized,
		"cred": run.street_cred,
		"final_cash": run.cash,
		"final_debt": run.debt,
	}


## Covers the weekly minimum on its last day, and pays down the debt with anything above the float.
func _pay_shark(run: RunState, cash_float := TRADING_FLOAT) -> void:
	if run.debt <= 0 or Encounters.has_pending(run):
		return
	var amount := maxi(0, mini(run.cash - cash_float, run.debt))
	if run.next_due_day - run.day <= 1:
		amount = maxi(amount, mini(Loan.amount_due(run), Loan.max_repay(run)))
	if amount > 0 and _game_state.repay_debt(amount):
		_count(&"loan payments")


## Sells what pays above cost here, pays the Shark, then buys the cheapest goods if they are clearly under base price.
func _trade_here(run: RunState) -> void:
	var dealers := _open_dealers(run, run.district_id, Calendar.stamp(run))
	_sell_here(run, dealers)
	_pay_shark(run)
	_buy_here(run, dealers)


func _sell_here(run: RunState, dealers: Array[DealerDef]) -> void:
	for item_id: StringName in run.inventory.keys():
		var item: ItemDef = _content.item(item_id)
		var best := _best_buyer(run, dealers, item)
		if best.is_empty():
			continue
		var cost := int(run.cost_basis.get(item_id, item.base_price))
		if int(best.price) >= cost * SELL_ABOVE_COST:
			var quantity := Inventory.count(run, item_id)
			var before := run.profit
			if _game_state.sell(item, quantity, int(best.price)) == Trade.Result.OK:
				_add(&"trading", (int(best.price) - item.base_price) * quantity)
				_realized += run.profit - before
				_count(&"sales")


func _buy_here(run: RunState, dealers: Array[DealerDef]) -> void:
	var pick := _cheapest_offer(run, dealers)
	if pick.is_empty() or float(pick.price) / pick.item.base_price > BUY_BELOW_BASE:
		return
	var spendable := maxi(0, run.cash - CASH_RESERVE)
	var quantity := mini(floori(float(spendable) / int(pick.price)), floori(float(Inventory.free_space(run)) / pick.item.slots))
	if quantity > 0 and _game_state.buy(pick.item, quantity, int(pick.price)) == Trade.Result.OK:
		_add(&"trading", (pick.item.base_price - int(pick.price)) * quantity)
		_count(&"buys")


## Goes where the carried goods sell best next phase, net of the fare. Stays put when nothing beats home.
func _best_destination(run: RunState) -> StringName:
	if run.inventory.is_empty():
		return &""
	var next_stamp := Calendar.stamp(run) + 1
	var best_id: StringName = &""
	var best_value := _carried_sale_value(run, run.district_id, next_stamp)
	for district: DistrictDef in _content.districts():
		if district.id == run.district_id or Travel.check(run, district) != Travel.Check.OK:
			continue
		var value := _carried_sale_value(run, district.id, next_stamp) - Travel.fare(run, district)
		if value > best_value * (1.0 + ROUTE_MIN_MARGIN):
			best_value = value
			best_id = district.id
	return best_id


func _carried_sale_value(run: RunState, district_id: StringName, stamp: int) -> int:
	var dealers := _open_dealers(run, district_id, stamp)
	var total := 0
	for item_id: StringName in run.inventory:
		var item: ItemDef = _content.item(item_id)
		var best := 0
		for dealer in dealers:
			var price := floori(Market.asking_price_at(run, dealer, item, stamp) * Market.SELL_SPREAD * Turf.sell_factor(run, district_id) * Families.sell_factor(run, dealer))
			best = maxi(best, price)
		total += best * Inventory.count(run, item_id)
	return total


func _broker_turn(run: RunState) -> void:
	var dealers := _open_dealers(run, run.district_id, Calendar.stamp(run))
	for dealer in dealers:
		_game_state.remember_prices(dealer)
	for order in run.customer_orders.duplicate():
		if Customers.can_hand_over(run, order):
			_hand_over(run, str(order.id))
	_resolve_pending(run)
	_sell_spare(run, dealers)
	_buy_bags(run)
	_pay_shark(run, BROKER_FLOAT + _reserved_cash(run))
	for offer in run.errand_offers.duplicate():
		if Errands.can_accept(run) and _game_state.accept_offer(str(offer.id)):
			_errands_taken[str(offer.id)] = Errands.find(run, str(offer.id))
			_count(&"errands taken")
	for offer in run.customer_offers.duplicate():
		if Customers.can_accept(run) and _worth_taking(run, offer) and _game_state.accept_customer_offer(str(offer.id)):
			_count(StringName("orders taken: %s" % _temperament_name(int(offer.temperament))))
	_resolve_pending(run)
	_stock_orders(run, dealers)


## Takes an order when its best known source clears the margin after fares and the cash and bag can carry it.
## Lowballers are only served from goods already in the bag, and undercover buyers are left alone.
func _worth_taking(run: RunState, offer: Dictionary) -> bool:
	var temperament := int(offer.temperament)
	var item: ItemDef = _content.item(StringName(str(offer.item)))
	var quantity := int(offer.quantity)
	if temperament == CustomerDef.Temperament.STING or item == null or item.slots * quantity > Inventory.capacity(run):
		return false
	var pay := _expected_unit_pay(offer) * quantity
	for quote in CustomerQuotes.quotes(run, offer):
		if not bool(quote.known) or bool(quote.locked):
			continue
		if str(quote.source) == CustomerQuotes.BAG:
			if int(quote.basis_profit) > 0:
				return true
			continue
		if temperament == CustomerDef.Temperament.LOWBALLER:
			continue
		var cost := int(quote.unit_cost) * quantity
		var room := Inventory.free_space(run) - _reserved_slots(run)
		if pay - cost - int(quote.fares) < cost * BROKER_MIN_MARGIN or item.slots * quantity > room:
			continue
		if cost + int(quote.fares) <= run.cash - CASH_RESERVE - _reserved_cash(run):
			return true
	return false


## A haggler is counted at his lower price, since he usually asks for it.
func _expected_unit_pay(order: Dictionary) -> int:
	if int(order.temperament) == CustomerDef.Temperament.HAGGLER:
		return int(order.counter_price)
	return int(order.unit_price)


## Buys what the accepted orders still miss from the cheapest dealer here, all at once and only while the order pays.
func _stock_orders(run: RunState, dealers: Array[DealerDef]) -> void:
	for order in run.customer_orders:
		var item: ItemDef = _content.item(StringName(str(order.item)))
		var missing := int(order.quantity) - Inventory.count(run, item.id)
		var price := _cheapest_price(run, dealers, item)
		if missing <= 0 or price <= 0 or price * (1.0 + STOCK_MIN_MARGIN) > _expected_unit_pay(order):
			continue
		if price * missing > run.cash - CASH_RESERVE or item.slots * missing > Inventory.free_space(run):
			continue
		if _game_state.buy(item, missing, price) == Trade.Result.OK:
			_add(&"customer orders", (item.base_price - price) * missing)
			_count(&"order buys")


func _cheapest_price(run: RunState, dealers: Array[DealerDef], item: ItemDef) -> int:
	var best := 0
	for dealer in dealers:
		if dealer.sells(item):
			var price := Market.buy_price(run, dealer, item)
			if best == 0 or price < best:
				best = price
	return best


## Hands the order over, holding firm against a haggler when the odds are good. False when it could not happen.
func _hand_over(run: RunState, order_id: String) -> bool:
	var order := Customers.find(run, order_id)
	if order.is_empty():
		CustomerHandover.dismiss(run, order_id)
		return false
	var temperament := int(order.temperament)
	var cost := int(run.cost_basis.get(StringName(str(order.item)), 0)) * int(order.quantity)
	var worth_before := run.cash + _goods_value(run)
	var result: Dictionary = _game_state.hand_over_customer_order(order_id)
	if bool(result.get("haggled", false)):
		result = _game_state.answer_haggle(order_id, Customers.hold_firm_chance(run) < HOLD_FIRM_FROM)
	if result.is_empty():
		CustomerHandover.dismiss(run, order_id)
		return false
	_add(&"customer orders", run.cash + _goods_value(run) - worth_before)
	var entry: Dictionary = _order_results.get(_temperament_name(temperament), { "count": 0, "profit": 0, "cost": 0, "walked": 0 })
	entry.count += 1
	if int(result.get("paid", 0)) > 0:
		entry.profit += int(result.paid) - cost
		entry.cost += cost
	elif bool(result.get("walked", false)):
		entry.walked += 1
	_order_results[_temperament_name(temperament)] = entry
	return true


## Sells goods no accepted order needs, unless they would go well under what they cost.
func _sell_spare(run: RunState, dealers: Array[DealerDef]) -> void:
	for item_id: StringName in run.inventory.keys():
		var item: ItemDef = _content.item(item_id)
		var spare := Inventory.count(run, item_id) - _units_promised(run, item_id)
		var best := _best_buyer(run, dealers, item)
		if spare <= 0 or best.is_empty():
			continue
		if int(best.price) < int(run.cost_basis.get(item_id, item.base_price)) * SPARE_SELL_FLOOR:
			continue
		if _game_state.sell(item, spare, int(best.price)) == Trade.Result.OK:
			_add(&"spare goods", (int(best.price) - item.base_price) * spare)


func _buy_bags(run: RunState) -> void:
	for bag_id in BAG_IDS:
		var bag: ItemDef = _content.item(bag_id)
		if bag != null and not Gear.owns(run, bag_id) and run.cash >= bag.base_price * BAG_CASH_MULTIPLE:
			if _game_state.buy_gear(bag) == Trade.Result.OK:
				_add(&"bags", -bag.base_price)
				_count(&"bags bought")


## Heads for the most urgent stop: the customer once the goods are in the bag, otherwise the best known source,
## or the next stop of an errand. Work that is already here is skipped.
func _broker_destination(run: RunState) -> StringName:
	var stops: Array[Dictionary] = []
	for order in run.customer_orders:
		var target := StringName(str(order.district)) if Customers.is_stocked(run, order) else _source_district(run, order)
		stops.append({ "district": target, "due": int(order.due_stamp) })
	for errand in run.errands:
		stops.append({ "district": Errands.target_district(errand), "due": int(errand.due_stamp) })
	stops.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.due) < int(b.due))
	for stop in stops:
		var district: DistrictDef = _content.district(stop.district)
		if district != null and district.id != run.district_id and Travel.check(run, district) == Travel.Check.OK:
			return district.id
	return &""


## Where the best known dealer for the order trades now. Without a known price, the cheapest stockist on paper.
func _source_district(run: RunState, order: Dictionary) -> StringName:
	for quote in CustomerQuotes.quotes(run, order):
		if bool(quote.known) and not bool(quote.locked) and str(quote.source) != CustomerQuotes.BAG:
			return StringName(str(quote.district))
	var item: ItemDef = _content.item(StringName(str(order.item)))
	var stamp := Calendar.stamp(run)
	var best_id: StringName = &""
	var best_bias := 0.0
	for dealer: DealerDef in _content.dealers():
		var location := Roster.dealer_location(run, dealer, stamp)
		if not dealer.sells(item) or location.is_empty() or Travel.is_locked(run, _content.district(location)):
			continue
		if best_id.is_empty() or dealer.bias_for(item.category) < best_bias:
			best_id = location
			best_bias = dealer.bias_for(item.category)
	return best_id


## Counts errands as they close. One that left before its deadline, or while standing at its last stop, was finished.
func _track_errands(run: RunState) -> void:
	var stamp := Calendar.stamp(run)
	for id: String in _errands_taken.keys():
		if not Errands.find(run, id).is_empty():
			continue
		var errand: Dictionary = _errands_taken[id]
		var finished := errand.is_empty() or stamp <= int(errand.due_stamp) or Errands.target_district(errand) == run.district_id
		_count(&"errands done" if finished else &"errands missed")
		_errands_taken.erase(id)


func _reserved_cash(run: RunState) -> int:
	var total := 0
	for order in run.customer_orders:
		total += int(order.street_price) * maxi(0, int(order.quantity) - Inventory.count(run, StringName(str(order.item))))
	return total


func _reserved_slots(run: RunState) -> int:
	var total := 0
	for order in run.customer_orders:
		var item: ItemDef = _content.item(StringName(str(order.item)))
		total += item.slots * maxi(0, int(order.quantity) - Inventory.count(run, item.id))
	return total


func _units_promised(run: RunState, item_id: StringName) -> int:
	var total := 0
	for order in run.customer_orders:
		if StringName(str(order.item)) == item_id:
			total += int(order.quantity)
	return total


func _temperament_name(temperament: int) -> String:
	return String(CustomerDef.Temperament.find_key(temperament)).to_lower()


func _pass_phase(run: RunState, destination_id: StringName) -> void:
	var cash_before := run.cash
	var debt_before := run.debt
	var goods_before := _goods_value(run)
	var travelled := false
	if destination_id.is_empty() or destination_id == run.district_id:
		_game_state.advance_phase()
	else:
		var destination: DistrictDef = _content.district(destination_id)
		var fare := Travel.fare(run, destination)
		var stamp_before := Calendar.stamp(run)
		if _game_state.travel_to(destination) == Travel.Check.OK:
			travelled = true
			_add(&"travel fares", -fare)
			cash_before -= fare
			_count(&"trips")
			if Calendar.stamp(run) == stamp_before:
				_resolve_pending(run)
				_game_state.advance_phase()
		else:
			_game_state.advance_phase()
	_add(&"loan interest and late fees", debt_before - run.debt)
	var label := &"daily income"
	var type := str(run.pending_encounter.get("type", ""))
	if type in [Encounters.RAID, Encounters.ENFORCERS]:
		label = StringName(type)
	elif not run.pending_encounter.is_empty():
		_count(StringName("encounter: " + _encounter_label(run.pending_encounter)))
	_add(label, run.cash - cash_before + _goods_value(run) - goods_before)


func _resolve_pending(run: RunState) -> void:
	var guard := 0
	while Encounters.has_pending(run) and guard < 5:
		guard += 1
		var encounter := run.pending_encounter
		if str(encounter.get("type", "")) == CustomerHandover.TYPE:
			_hand_over(run, str(encounter.get("order", "")))
			continue
		var label := _encounter_label(encounter)
		var choice := _choose(run, encounter)
		_count(StringName("%s -> %s" % [label, choice]))
		var cash_before := run.cash
		var goods_before := _goods_value(run)
		var debt_before := run.debt
		_game_state.resolve_encounter(choice)
		_add(StringName(label), run.cash - cash_before + _goods_value(run) - goods_before + debt_before - run.debt)


func _choose(run: RunState, encounter: Dictionary) -> StringName:
	var enabled: Array[StringName] = []
	for choice in Encounters.choices(run, encounter):
		if choice.enabled:
			enabled.append(choice.id)
	match str(encounter.get("type", "")):
		Encounters.POLICE:
			if enabled.has(Encounters.BRIBE) and int(encounter.bribe) <= run.cash * BRIBE_SHARE_OF_CASH:
				return Encounters.BRIBE
			return Encounters.COMPLY
		Vex.GATE:
			if enabled.has(Vex.THREATEN):
				return Vex.THREATEN
			if enabled.has(Vex.BRIBE) and int(encounter.bribe) <= run.cash * VEX_BRIBE_SHARE_OF_CASH:
				return Vex.BRIBE
			return Vex.IGNORE
		Vex.HUNT:
			return Vex.PAY if enabled.has(Vex.PAY) else Vex.FIGHT
		Families.SHAKEDOWN:
			return Families.PAY_UP if enabled.has(Families.PAY_UP) else Families.REFUSE
		Collections.TYPE:
			return Collections.LEAN
	if enabled.has(Encounters.PAY):
		return Encounters.PAY
	if enabled.has(Encounters.TAKE):
		return Encounters.TAKE
	return enabled[0] if not enabled.is_empty() else Encounters.CONTINUE


func _encounter_label(encounter: Dictionary) -> String:
	var type := str(encounter.get("type", ""))
	if type == Encounters.EVENT:
		return "event %s" % str(encounter.get("event", ""))
	return type


func _open_dealers(run: RunState, district_id: StringName, stamp: int) -> Array[DealerDef]:
	var open: Array[DealerDef] = []
	for dealer in Roster.dealers_at(run, district_id, stamp):
		if int(run.walked_out.get(dealer.id, -1)) != stamp and not Families.refuses(run, dealer):
			open.append(dealer)
	return open


func _best_buyer(run: RunState, dealers: Array[DealerDef], item: ItemDef) -> Dictionary:
	var best := {}
	for dealer in dealers:
		var price := Market.sell_price(run, dealer, item)
		if best.is_empty() or price > int(best.price):
			best = { "dealer": dealer, "price": price }
	return best


func _cheapest_offer(run: RunState, dealers: Array[DealerDef]) -> Dictionary:
	var best := {}
	for dealer in dealers:
		for item: ItemDef in _content.items(ItemDef.Kind.TRADE_GOOD):
			if not dealer.sells(item):
				continue
			var price := Market.buy_price(run, dealer, item)
			if price > run.cash - CASH_RESERVE:
				continue
			var ratio := float(price) / item.base_price
			if best.is_empty() or ratio < float(best.ratio):
				best = { "item": item, "price": price, "ratio": ratio }
	return best


func _worth(run: RunState) -> int:
	return run.cash + _goods_value(run) - run.debt


func _goods_value(run: RunState) -> int:
	var total := 0
	for item_id: StringName in run.inventory:
		var item: ItemDef = _content.item(item_id)
		if item != null:
			total += item.base_price * Inventory.count(run, item_id)
	return total


func _add(label: StringName, amount: int) -> void:
	if amount != 0:
		_ledger[label] = int(_ledger.get(label, 0)) + amount


func _count(label: StringName) -> void:
	_counts[label] = int(_counts.get(label, 0)) + 1
