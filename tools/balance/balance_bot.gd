extends RefCounted

## Plays one run through GameState with a fixed strategy and records where the money went.
## Net worth counts cash, plus carried goods at base price, minus debt.
## Every strategy pays the Shark's weekly minimum when it falls due and puts cash above a trading float into the debt.

const IDLE: StringName = &"idle"
const LOCAL: StringName = &"local"
const ROUTE: StringName = &"route"

const CHECKPOINT_DAYS: Array[int] = [7, 14, 30, 60]
const BUY_BELOW_BASE := 0.92
const SELL_ABOVE_COST := 1.05
const ROUTE_MIN_MARGIN := 0.15
const CASH_RESERVE := 150
const TRADING_FLOAT := 4000
const BRIBE_SHARE_OF_CASH := 0.25
const VEX_BRIBE_SHARE_OF_CASH := 0.2

var _game_state: Node
var _content: Node
var _ledger: Dictionary = {}
var _counts: Dictionary = {}
var _realized := 0


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


## Covers the weekly minimum on its last day, and pays down the debt with anything above the trading float.
func _pay_shark(run: RunState) -> void:
	if run.debt <= 0 or Encounters.has_pending(run):
		return
	var amount := maxi(0, mini(run.cash - TRADING_FLOAT, run.debt))
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
