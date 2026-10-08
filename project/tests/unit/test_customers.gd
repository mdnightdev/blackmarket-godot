extends GutTest

const QUOTE_ITEM: StringName = &"street_meds"
const QUOTE_CUSTOMER := "rosa_delgado"
const QUOTE_DISTRICT: StringName = &"old_market"
const QUOTE_QUANTITY := 5
const QUOTE_PRICE := 300
const POLICE_ACTIVE_DAY := Police.GRACE_DAYS + 2
## Least a fair or generous order pays per unit over the city average source, and least a usual order clears over it.
const MIN_FAIR_MARGIN := 0.04
const MIN_GENEROUS_MARGIN := 0.14
const MIN_MEDIAN_ORDER_MARGIN := 500

var _run: RunState
var _taken := 0


func before_each() -> void:
	_run = RunState.new()
	_run.price_seed = 1357
	_run.cash = 100000
	_taken = 0


func _go_to_stamp(stamp: int) -> void:
	_run.day = floori(float(stamp) / RunState.Phase.size()) + 1
	_run.phase = (stamp % RunState.Phase.size()) as RunState.Phase


func _customer_with(temperament: CustomerDef.Temperament) -> CustomerDef:
	for customer in Content.customers():
		if customer.temperament == temperament:
			return customer
	return null


func _offer(temperament: CustomerDef.Temperament) -> Dictionary:
	var offer := CustomerOffers.generate(_run, _customer_with(temperament))
	offer.id = "customer:test:%d" % _taken
	_taken += 1
	_run.customer_offers.append(offer)
	return offer


func _take(temperament: CustomerDef.Temperament) -> Dictionary:
	var offer := _offer(temperament)
	assert_true(Customers.accept(_run, str(offer.id)))
	return Customers.find(_run, str(offer.id))


func _stand_ready(order: Dictionary) -> void:
	Inventory.add_units(_run, StringName(str(order.item)), int(order.quantity))
	_run.district_id = StringName(str(order.district))


func _quote_order() -> Dictionary:
	return Customers.sanitize({
		"id": "customer:quote",
		"customer": QUOTE_CUSTOMER,
		"item": String(QUOTE_ITEM),
		"quantity": QUOTE_QUANTITY,
		"unit_price": QUOTE_PRICE,
		"district": String(QUOTE_DISTRICT),
		"temperament": CustomerDef.Temperament.FAIR,
		"due_stamp": 10,
	})


func _quote_from(quotes: Array[Dictionary], source: String) -> Dictionary:
	for quote in quotes:
		if str(quote.source) == source:
			return quote
	return {}


func _test_buyer(temperament: CustomerDef.Temperament) -> CustomerDef:
	var buyer := CustomerDef.new()
	buyer.id = &"test_buyer"
	buyer.display_name = "Test Buyer"
	buyer.district_id = QUOTE_DISTRICT
	buyer.wants = [&"luxury"]
	buyer.temperament = temperament
	return buyer


func test_pool_loads_and_every_customer_is_valid() -> void:
	var customers := Content.customers()
	assert_between(customers.size(), 36, 48)
	var categories: Array[StringName] = []
	for item in Content.items(ItemDef.Kind.TRADE_GOOD):
		categories.append(item.category)
	var districts: Array[StringName] = []
	var temperaments: Array[int] = []
	var names: Array[String] = []
	for customer in customers:
		assert_eq(Content.customer(customer.id), customer)
		assert_false(customer.display_name.is_empty())
		assert_false(names.has(customer.display_name), "%s is unique" % customer.display_name)
		names.append(customer.display_name)
		assert_false(customer.line.is_empty())
		assert_false(customer.line.contains("\u2014"), "%s line has no em dash" % customer.id)
		assert_not_null(Content.district(customer.district_id), "%s lives in a real district" % customer.id)
		assert_false(customer.wants.is_empty())
		for category in customer.wants:
			assert_true(categories.has(category), "%s wants a real category" % customer.id)
		assert_false(customer.active_phases.is_empty())
		for phase in customer.active_phases:
			assert_between(phase, 0, RunState.Phase.size() - 1)
		assert_between(customer.min_rank, 1, StreetCred.max_rank())
		if not districts.has(customer.district_id):
			districts.append(customer.district_id)
		if not temperaments.has(customer.temperament):
			temperaments.append(customer.temperament)
	assert_eq(districts.size(), Content.districts().size(), "every district has customers")
	assert_eq(temperaments.size(), CustomerDef.Temperament.size(), "every temperament is in the pool")


func test_generated_offers_stay_in_bounds() -> void:
	for customer in Content.customers():
		for run_seed in 12:
			_run.price_seed = run_seed
			var offer := CustomerOffers.generate(_run, customer)
			var item := Content.item(StringName(str(offer.item)))
			var profile: Dictionary = CustomerOffers.PROFILES[customer.temperament]
			var rush_factor := CustomerOffers.RUSH_BONUS if bool(offer.rush) else 1.0
			var ratio := float(offer.unit_price) / int(offer.street_price)
			assert_eq(Customers.sanitize(offer), offer, "generated offers are valid")
			assert_true(customer.wants.has(item.category))
			assert_between(int(offer.quantity), CustomerOffers.MIN_QUANTITY, floori(float(CustomerOffers.max_slots(_run)) / item.slots))
			assert_between(ratio, float(profile.price[0]) * rush_factor - 0.01, float(profile.price[2]) * rush_factor + 0.01)
			assert_eq(int(offer.expires_stamp), Calendar.stamp(_run) + CustomerOffers.OFFER_PHASES - 1)
			assert_eq(int(offer.due_stamp), -1)
			if bool(offer.rush):
				assert_between(int(offer.lead), CustomerOffers.MIN_RUSH_PHASES, CustomerOffers.MAX_RUSH_PHASES)
			else:
				assert_between(int(offer.lead), CustomerOffers.MIN_LEAD_PHASES, CustomerOffers.MAX_LEAD_PHASES)
			if customer.temperament == CustomerDef.Temperament.HAGGLER:
				assert_between(int(offer.counter_price), 1, int(offer.unit_price) - 1)
			else:
				assert_eq(int(offer.counter_price), 0)
	var customer := Content.customers()[0]
	assert_eq(CustomerOffers.generate(_run, customer), CustomerOffers.generate(_run, customer), "same seed and phase give the same offer")


func test_price_factors_follow_the_temperament() -> void:
	for run_seed in 30:
		_run.price_seed = run_seed
		var low := CustomerOffers.generate(_run, _test_buyer(CustomerDef.Temperament.LOWBALLER))
		assert_true(int(low.unit_price) <= int(low.street_price), "lowballers pay at or under the street price")
		assert_false(bool(low.rush), "lowballers never rush")
		var generous := CustomerOffers.generate(_run, _test_buyer(CustomerDef.Temperament.GENEROUS))
		assert_gt(int(generous.unit_price), int(generous.street_price), "generous buyers pay over the street price")
		var sting := CustomerOffers.generate(_run, _test_buyer(CustomerDef.Temperament.STING))
		assert_gt(float(sting.unit_price) / int(sting.street_price), float(CustomerOffers.PROFILES[CustomerDef.Temperament.GENEROUS].price[1]))


func test_fair_and_generous_orders_beat_the_average_source() -> void:
	var margins: Array[int] = []
	for customer in Content.customers():
		if customer.temperament != CustomerDef.Temperament.FAIR and customer.temperament != CustomerDef.Temperament.GENEROUS:
			continue
		var least := MIN_FAIR_MARGIN if customer.temperament == CustomerDef.Temperament.FAIR else MIN_GENEROUS_MARGIN
		for run_seed in 10:
			_run.price_seed = run_seed
			var offer := CustomerOffers.generate(_run, customer)
			var average := _average_source_price(Content.item(StringName(str(offer.item))))
			assert_gt(float(offer.unit_price) / average - 1.0, least, "%s pays over the city average" % customer.id)
			margins.append(Customers.total(offer) - roundi(average * int(offer.quantity)))
	margins.sort()
	assert_gt(margins[margins.size() / 2], MIN_MEDIAN_ORDER_MARGIN, "a usual order clears more than pocket change")


func _average_source_price(item: ItemDef) -> float:
	var total := 0
	var sellers := 0
	for dealer in Content.dealers():
		if dealer.sells(item) and not Roster.dealer_location(_run, dealer, Calendar.stamp(_run)).is_empty():
			total += Market.buy_price(_run, dealer, item)
			sellers += 1
	return float(total) / sellers


func test_order_value_grows_with_rank_and_bulk() -> void:
	var fair_low := 0
	var fair_high := 0
	var bulk := 0
	for run_seed in 20:
		_run.price_seed = run_seed
		_run.street_cred = 0
		fair_low += Customers.total(CustomerOffers.generate(_run, _test_buyer(CustomerDef.Temperament.FAIR)))
		bulk += Customers.total(CustomerOffers.generate(_run, _test_buyer(CustomerDef.Temperament.BULK)))
		_run.street_cred = StreetCred.MAX
		fair_high += Customers.total(CustomerOffers.generate(_run, _test_buyer(CustomerDef.Temperament.FAIR)))
	assert_gt(fair_high, fair_low)
	assert_gt(bulk, fair_low)
	var band: Array = PayScale.BANDS[Tiers.STREET]
	assert_between(fair_low, roundi(band[0] * CustomerOffers.ORDER_VALUE_PER_PAY) * 10, roundi(band[2] * CustomerOffers.ORDER_VALUE_PER_PAY) * 20)


func test_rank_and_phase_gate_customers() -> void:
	var marek := Content.customer(&"marek_hollis")
	var rosa := Content.customer(&"rosa_delgado")
	_go_to_stamp(RunState.Phase.NOON)
	assert_false(CustomerOffers.eligible(_run).has(marek), "needs a higher rank")
	assert_true(CustomerOffers.eligible(_run).has(rosa))
	_run.street_cred = int(StreetCred.RANKS[marek.min_rank - 1].cred)
	assert_true(CustomerOffers.eligible(_run).has(marek))
	_go_to_stamp(RunState.Phase.NIGHT)
	assert_false(CustomerOffers.eligible(_run).has(rosa), "Rosa does not post at night")
	_run.street_cred = StreetCred.MAX
	for customer in CustomerOffers.eligible(_run):
		assert_false(Travel.is_locked(_run, Content.district(customer.district_id)), "locked districts stay quiet")


func test_stings_need_heat_or_a_hot_district() -> void:
	var kell := Content.customer(&"mr_kell")
	var daniel := Content.customer(&"daniel_price")
	_go_to_stamp((POLICE_ACTIVE_DAY - 1) * RunState.Phase.size() + RunState.Phase.EVENING)
	assert_false(CustomerOffers.eligible(_run).has(kell), "the docks are not hot enough without heat")
	_run.heat = CustomerOffers.STING_MIN_HEAT
	assert_true(CustomerOffers.eligible(_run).has(kell))
	_go_to_stamp((POLICE_ACTIVE_DAY - 1) * RunState.Phase.size() + RunState.Phase.NOON)
	_run.heat = 0
	assert_true(CustomerOffers.eligible(_run).has(daniel), "downtown is hot enough on its own")
	_go_to_stamp(RunState.Phase.NOON)
	assert_false(CustomerOffers.eligible(_run).has(daniel), "no stings while the police are quiet")


func test_posting_is_one_per_phase_up_to_the_cap() -> void:
	var stamp := 0
	while CustomerOffers.post(_run).is_empty():
		stamp += 1
		_go_to_stamp(stamp)
	assert_eq(_run.customer_offers.size(), 1)
	assert_true(CustomerOffers.post(_run).is_empty(), "one offer per phase")
	var poster := str(_run.customer_offers[0].customer)
	assert_false(CustomerOffers.eligible(_run).any(func(customer: CustomerDef) -> bool: return String(customer.id) == poster), "one open order per customer")
	while _run.customer_offers.size() < Customers.MAX_OPEN_OFFERS:
		_offer(CustomerDef.Temperament.FAIR)
	for later in 8:
		_go_to_stamp(stamp + 1 + later)
		assert_true(CustomerOffers.post(_run).is_empty(), "the phone is full")


func test_offers_arrive_regularly_across_days() -> void:
	var posted := 0
	for stamp in 40:
		_go_to_stamp(stamp)
		_run.customer_offers.clear()
		posted += CustomerOffers.post(_run).size()
	assert_between(posted, 12, 38)


func test_ignored_offers_expire_quietly() -> void:
	var offer := _offer(CustomerDef.Temperament.FAIR)
	assert_eq(Customers.phases_left(_run, offer), CustomerOffers.OFFER_PHASES)
	_go_to_stamp(int(offer.expires_stamp))
	Customers.expire(_run)
	assert_eq(_run.customer_offers.size(), 1, "still open in its last phase")
	_go_to_stamp(int(offer.expires_stamp) + 1)
	assert_true(Customers.expire(_run).is_empty(), "no notice for an ignored offer")
	assert_true(_run.customer_offers.is_empty())
	assert_false(Customers.accept(_run, str(offer.id)))


func test_accept_starts_the_clock_and_decline_removes_the_offer() -> void:
	var offer := _offer(CustomerDef.Temperament.FAIR)
	assert_true(Customers.accept(_run, str(offer.id)))
	assert_true(_run.customer_offers.is_empty())
	assert_eq(int(_run.customer_orders[0].due_stamp), Calendar.stamp(_run) + int(offer.lead))
	assert_false(Customers.accept(_run, str(offer.id)), "cannot take it twice")
	var second := _offer(CustomerDef.Temperament.BULK)
	assert_true(Customers.decline(_run, str(second.id)))
	assert_true(_run.customer_offers.is_empty())
	assert_eq(_run.customer_orders.size(), 1)


func test_hands_full_refuses_more_orders() -> void:
	for index in Customers.MAX_ACTIVE:
		_take(CustomerDef.Temperament.FAIR)
	var offer := _offer(CustomerDef.Temperament.FAIR)
	assert_false(Customers.can_accept(_run))
	assert_false(Customers.accept(_run, str(offer.id)))
	assert_eq(_run.customer_offers.size(), 1)


func test_trip_fare_is_free_when_staying_put() -> void:
	var docks := Content.district(&"docks")
	assert_eq(Travel.trip_fare(_run, &"docks", docks), 0)
	assert_eq(Travel.trip_fare(_run, &"slums", docks), Travel.fare(_run, docks))


func test_bag_quote_counts_fares_and_cost_basis() -> void:
	var order := _quote_order()
	_run.district_id = &"slums"
	Inventory.add_units(_run, QUOTE_ITEM, QUOTE_QUANTITY)
	_run.cost_basis[QUOTE_ITEM] = 100
	var bag := _quote_from(CustomerQuotes.quotes(_run, order), CustomerQuotes.BAG)
	var fare := Travel.fare(_run, Content.district(QUOTE_DISTRICT))
	var pay := QUOTE_QUANTITY * QUOTE_PRICE
	assert_true(bool(bag.known))
	assert_true(bool(bag.fits_bag))
	assert_eq(int(bag.unit_cost), 0)
	assert_eq(int(bag.fares), fare)
	assert_eq(int(bag.profit), pay - fare)
	assert_eq(int(bag.basis_profit), pay - fare - 100 * QUOTE_QUANTITY)
	Inventory.discard(_run, QUOTE_ITEM, 1)
	assert_true(_quote_from(CustomerQuotes.quotes(_run, order), CustomerQuotes.BAG).is_empty(), "no bag option without every unit")


func test_dealer_quotes_are_unknown_until_seen() -> void:
	var order := _quote_order()
	_run.district_id = &"warehouse_row"
	var quotes := CustomerQuotes.quotes(_run, order)
	var item := Content.item(QUOTE_ITEM)
	var stockists := Content.dealers().filter(func(dealer: DealerDef) -> bool: return dealer.sells(item))
	assert_eq(quotes.size(), stockists.size())
	for quote in quotes:
		assert_false(bool(quote.known))
		assert_eq(int(quote.unit_cost), 0)
		assert_eq(int(quote.profit), 0)
		assert_eq(int(quote.seen_stamp), -1)
	var nadia := Content.dealer(&"nadia")
	var goods: Array[ItemDef] = [item]
	PriceIntel.record(_run, nadia, goods)
	quotes = CustomerQuotes.quotes(_run, order)
	var seen := _quote_from(quotes, "nadia")
	var cost := Market.buy_price(_run, nadia, item)
	var fares := Travel.fare(_run, Content.district(nadia.district_id))
	assert_eq(quotes[0], seen, "known prices sort first")
	assert_true(bool(seen.known))
	assert_eq(int(seen.unit_cost), cost)
	assert_eq(int(seen.seen_stamp), Calendar.stamp(_run))
	assert_eq(int(seen.fares), fares, "the customer is in the same district as the dealer")
	assert_eq(int(seen.profit), QUOTE_QUANTITY * QUOTE_PRICE - cost * QUOTE_QUANTITY - fares)
	_go_to_stamp(Calendar.stamp(_run) + PriceIntel.MAX_AGE_PHASES + 1)
	assert_false(bool(_quote_from(CustomerQuotes.quotes(_run, order), "nadia").known), "stale sightings are forgotten")


func test_dealers_in_the_current_district_quote_live_prices() -> void:
	var order := _quote_order()
	_run.district_id = &"slums"
	var sapo := Content.dealer(&"sapo")
	var item := Content.item(QUOTE_ITEM)
	var live := _quote_from(CustomerQuotes.quotes(_run, order), "sapo")
	var fares := Travel.fare(_run, Content.district(QUOTE_DISTRICT))
	assert_true(bool(live.known))
	assert_true(bool(live.open))
	assert_false(bool(live.locked))
	assert_eq(int(live.unit_cost), Market.buy_price(_run, sapo, item))
	assert_eq(int(live.fares), fares, "no fare to reach a dealer already here")


func test_quotes_sort_by_profit_and_flag_a_full_bag() -> void:
	var order := _quote_order()
	_run.district_id = &"slums"
	Inventory.add_units(_run, QUOTE_ITEM, QUOTE_QUANTITY)
	var item := Content.item(QUOTE_ITEM)
	var goods: Array[ItemDef] = [item]
	for dealer in Content.dealers():
		if dealer.sells(item):
			PriceIntel.record(_run, dealer, goods)
	var quotes := CustomerQuotes.quotes(_run, order)
	var known := quotes.filter(func(quote: Dictionary) -> bool: return bool(quote.known))
	for index in range(1, known.size()):
		assert_true(int(known[index - 1].profit) >= int(known[index].profit), "best profit first")
	assert_eq(str(quotes[0].source), CustomerQuotes.BAG, "goods already carried cost nothing more")
	Inventory.add_units(_run, &"burner_sims", Inventory.free_space(_run))
	for quote in CustomerQuotes.quotes(_run, order):
		assert_eq(bool(quote.fits_bag), str(quote.source) == CustomerQuotes.BAG)


func test_quotes_flag_locked_districts() -> void:
	var order := _quote_order()
	order.item = "rare_watches"
	for quote in CustomerQuotes.quotes(_run, order):
		var district := Content.district(StringName(str(quote.district)))
		assert_eq(bool(quote.locked), Travel.is_locked(_run, district))
	assert_true(CustomerQuotes.quotes(_run, {}).is_empty())


func test_quote_text_names_the_source_price_and_profit() -> void:
	_go_to_stamp(5)
	var nadia := Content.dealer(&"nadia")
	var bag := { "source": CustomerQuotes.BAG, "known": true, "unit_cost": 0, "seen_stamp": 5, "profit": 900 }
	var fresh := { "source": "nadia", "known": true, "unit_cost": 150, "seen_stamp": 5, "profit": -300 }
	var stale := { "source": "nadia", "known": true, "unit_cost": 150, "seen_stamp": 3, "profit": 0 }
	var unknown := { "source": "nadia", "known": false, "unit_cost": 0, "seen_stamp": -1, "profit": 0 }
	assert_eq(CustomerQuotes.source_name(bag), "Your bag")
	assert_eq(CustomerQuotes.source_name(fresh), nadia.display_name)
	assert_eq(CustomerQuotes.price_text(_run, bag), "Already in your bag")
	assert_eq(CustomerQuotes.price_text(_run, fresh), "$150 each")
	assert_eq(CustomerQuotes.price_text(_run, stale), "$150 each, seen 2 phases ago")
	assert_eq(CustomerQuotes.price_text(_run, unknown), "Price unknown")
	assert_eq(CustomerQuotes.profit_text(bag), "+$900")
	assert_eq(CustomerQuotes.profit_text(fresh), "-$300")
	assert_eq(CustomerQuotes.profit_text(unknown), "?")


func test_quote_warning_shows_the_worst_problem() -> void:
	var quote := { "locked": true, "open": false, "fits_bag": false }
	assert_eq(CustomerQuotes.warning(quote), "Locked")
	quote.locked = false
	assert_eq(CustomerQuotes.warning(quote), "Closed now")
	quote.open = true
	assert_eq(CustomerQuotes.warning(quote), "Bag too small")
	quote.fits_bag = true
	assert_eq(CustomerQuotes.warning(quote), "")


func test_order_labels_and_stock_check() -> void:
	var order := _quote_order()
	var item := Content.item(QUOTE_ITEM)
	assert_eq(Customers.headline(order), "%d %s for %s" % [QUOTE_QUANTITY, item.display_name, Format.money(QUOTE_QUANTITY * QUOTE_PRICE)])
	assert_eq(Customers.district_name(order), Content.district(QUOTE_DISTRICT).display_name)
	Inventory.add_units(_run, QUOTE_ITEM, QUOTE_QUANTITY - 1)
	assert_false(Customers.is_stocked(_run, order))
	Inventory.add_units(_run, QUOTE_ITEM, 1)
	assert_true(Customers.is_stocked(_run, order))


func test_hand_over_pays_and_removes_the_goods() -> void:
	var order := _take(CustomerDef.Temperament.FAIR)
	var item := StringName(str(order.item))
	assert_false(Customers.can_hand_over(_run, order), "nothing in the bag yet")
	_stand_ready(order)
	_run.district_id = &"warehouse_row" if order.district != "warehouse_row" else &"slums"
	assert_false(Customers.can_hand_over(_run, order), "wrong district")
	_run.district_id = StringName(str(order.district))
	assert_true(Customers.can_hand_over(_run, order))
	var cash := _run.cash
	var trades := _run.trades
	var cred := _run.street_cred
	var result := Customers.hand_over(_run, order, 0.5)
	assert_eq(int(result.paid), Customers.total(order))
	assert_false(bool(result.haggled))
	assert_false(bool(result.sting))
	assert_eq(_run.cash, cash + Customers.total(order))
	assert_eq(Inventory.count(_run, item), 0)
	assert_eq(_run.trades, trades + 1)
	assert_true(_run.street_cred >= cred + StreetCred.ORDER_DELIVERED)
	assert_true(_run.customer_orders.is_empty())
	assert_true(Customers.hand_over(_run, order, 0.5).is_empty(), "cannot hand over twice")


func test_late_orders_cannot_be_handed_over() -> void:
	var order := _take(CustomerDef.Temperament.FAIR)
	_stand_ready(order)
	_go_to_stamp(int(order.due_stamp) + 1)
	assert_false(Customers.can_hand_over(_run, order))


func test_haggler_counters_and_the_lower_price_can_be_taken() -> void:
	var order := _take(CustomerDef.Temperament.HAGGLER)
	_stand_ready(order)
	var cash := _run.cash
	var result := Customers.hand_over(_run, order, 0.0)
	assert_true(bool(result.haggled))
	assert_eq(int(result.paid), 0)
	assert_eq(_run.cash, cash)
	assert_true(bool(order.countered))
	assert_eq(_run.customer_orders.size(), 1, "the order waits for an answer")
	assert_true(bool(Customers.hand_over(_run, order, 0.999).haggled), "asking again gets the same counter")
	var taken := Customers.answer_haggle(_run, order, true, 0.999)
	assert_eq(int(taken.paid), int(order.counter_price) * int(order.quantity))
	assert_eq(_run.cash, cash + int(taken.paid))
	assert_true(_run.customer_orders.is_empty())


func test_holding_firm_wins_the_full_price_or_loses_the_deal() -> void:
	var order := _take(CustomerDef.Temperament.HAGGLER)
	_stand_ready(order)
	Customers.hand_over(_run, order, 0.0)
	var cash := _run.cash
	var won := Customers.answer_haggle(_run, order, false, 0.0)
	assert_eq(int(won.paid), Customers.total(order))
	assert_eq(_run.cash, cash + Customers.total(order))
	var second := _take(CustomerDef.Temperament.HAGGLER)
	_stand_ready(second)
	Customers.hand_over(_run, second, 0.0)
	cash = _run.cash
	var cred := _run.street_cred
	var lost := Customers.answer_haggle(_run, second, false, 0.999)
	assert_true(bool(lost.walked))
	assert_eq(int(lost.paid), 0)
	assert_eq(_run.cash, cash)
	assert_eq(_run.street_cred, cred, "a walkout costs no cred")
	assert_eq(Inventory.count(_run, StringName(str(second.item))), int(second.quantity), "the goods stay in the bag")
	assert_true(_run.customer_orders.is_empty())


func test_holding_firm_gets_easier_with_cred() -> void:
	var start := Customers.hold_firm_chance(_run)
	_run.street_cred = StreetCred.MAX
	assert_gt(Customers.hold_firm_chance(_run), start)


func test_a_haggler_sometimes_pays_in_full() -> void:
	var order := _take(CustomerDef.Temperament.HAGGLER)
	_stand_ready(order)
	var result := Customers.hand_over(_run, order, Customers.HAGGLE_TRY_CHANCE)
	assert_false(bool(result.haggled))
	assert_eq(int(result.paid), Customers.total(order))
	assert_true(Customers.answer_haggle(_run, order, true, 0.0).is_empty(), "nothing left to answer")


func test_flaky_customers_back_out_without_a_cred_loss() -> void:
	var cancelled := 0
	for run_seed in 40:
		_run = RunState.new()
		_run.price_seed = run_seed
		_run.street_cred = 100
		var order := _take(CustomerDef.Temperament.FLAKY)
		assert_false(Customers.flakes(_run, order), "never in the phase it was accepted")
		_go_to_stamp(Calendar.stamp(_run) + 1)
		if not Customers.flakes(_run, order):
			continue
		cancelled += 1
		var notices := Customers.expire(_run)
		assert_eq(notices.size(), 1)
		assert_string_contains(str(notices[0].line), "called off")
		assert_true(_run.customer_orders.is_empty())
		assert_eq(_run.street_cred, 100)
	assert_between(cancelled, 1, 20)
	var steady := _take(CustomerDef.Temperament.FAIR)
	_go_to_stamp(Calendar.stamp(_run) + 1)
	assert_false(Customers.flakes(_run, steady))


func test_a_sting_shows_its_tell_and_ends_in_a_police_stop() -> void:
	var order := _take(CustomerDef.Temperament.STING)
	assert_eq(Customers.tell(order), "Pays too well. Asks too many questions.")
	_stand_ready(order)
	var cash := _run.cash
	var result := Customers.hand_over(_run, order, 0.5)
	assert_true(bool(result.sting))
	assert_eq(int(result.paid), 0)
	assert_eq(_run.cash, cash)
	assert_eq(str(_run.pending_encounter.type), Encounters.POLICE)
	assert_eq(Inventory.count(_run, StringName(str(order.item))), int(order.quantity), "the goods are still on you")
	assert_true(_run.customer_orders.is_empty())


func test_every_temperament_has_a_tell() -> void:
	for temperament in CustomerDef.Temperament.values():
		assert_false(Customers.tell({ "temperament": temperament }).is_empty())


func test_an_overdue_order_fails_with_a_small_cred_loss() -> void:
	_run.street_cred = 100
	var order := _take(CustomerDef.Temperament.FAIR)
	_go_to_stamp(int(order.due_stamp))
	assert_true(Customers.expire(_run).is_empty(), "still due in its last phase")
	_go_to_stamp(int(order.due_stamp) + 1)
	var notices := Customers.expire(_run)
	assert_eq(notices.size(), 1)
	assert_string_contains(str(notices[0].line), Customers.customer_name(order))
	assert_true(_run.customer_orders.is_empty())
	assert_eq(_run.street_cred, 100 + StreetCred.CUSTOMER_MISSED)


func test_arriving_with_the_goods_queues_the_handover() -> void:
	var order := _take(CustomerDef.Temperament.FAIR)
	Customers.visit(_run)
	assert_false(Encounters.has_pending(_run), "no prompt without the goods")
	_stand_ready(order)
	Customers.visit(_run)
	assert_eq(str(_run.pending_encounter.type), CustomerHandover.TYPE)
	var ids := Encounters.choices(_run, _run.pending_encounter).map(func(choice: Encounters.Choice) -> StringName: return choice.id)
	assert_eq(ids, [CustomerHandover.HAND_OVER, CustomerHandover.NOT_NOW])
	assert_eq(Encounters.resolve(_run, CustomerHandover.NOT_NOW, 0.5), "")
	assert_eq(_run.customer_orders.size(), 1, "not now keeps the order")
	Customers.visit(_run)
	var cash := _run.cash
	assert_ne(Encounters.resolve(_run, CustomerHandover.HAND_OVER, 0.5), "")
	assert_eq(_run.cash, cash + Customers.total(order))
	assert_false(Encounters.has_pending(_run))


func test_a_waiting_encounter_holds_the_handover_back() -> void:
	var order := _take(CustomerDef.Temperament.FAIR)
	_stand_ready(order)
	_run.pending_encounter = Encounters.police_stop(_run)
	Customers.visit(_run)
	assert_eq(str(_run.pending_encounter.type), Encounters.POLICE)


func test_the_haggle_plays_out_as_a_second_card() -> void:
	var order := _take(CustomerDef.Temperament.HAGGLER)
	_stand_ready(order)
	Customers.visit(_run)
	Encounters.resolve(_run, CustomerHandover.HAND_OVER, 0.0)
	assert_eq(str(_run.pending_encounter.stage), CustomerHandover.COUNTER_STAGE)
	var ids := Encounters.choices(_run, _run.pending_encounter).map(func(choice: Encounters.Choice) -> StringName: return choice.id)
	assert_eq(ids, [CustomerHandover.TAKE_COUNTER, CustomerHandover.HOLD_FIRM])
	var cash := _run.cash
	assert_ne(Encounters.resolve(_run, CustomerHandover.TAKE_COUNTER, 0.5), "")
	assert_eq(_run.cash, cash + int(order.counter_price) * int(order.quantity))
	assert_false(Encounters.has_pending(_run))


func test_dismiss_only_clears_the_matching_card() -> void:
	var order := _take(CustomerDef.Temperament.FAIR)
	_stand_ready(order)
	Customers.visit(_run)
	CustomerHandover.dismiss(_run, "customer:other")
	assert_true(Encounters.has_pending(_run))
	CustomerHandover.dismiss(_run, str(order.id))
	assert_false(Encounters.has_pending(_run))


func test_customer_orders_show_up_in_job_deadlines() -> void:
	var order := _take(CustomerDef.Temperament.FAIR)
	var jobs := Jobs.deadlines(_run)
	assert_eq(jobs.size(), 1)
	assert_eq(int(jobs[0].due), int(order.due_stamp))
	assert_string_contains(str(jobs[0].title), Customers.customer_name(order))
	assert_eq(str(jobs[0].place), Content.district(StringName(str(order.district))).display_name)


func test_sanitize_rejects_junk() -> void:
	var valid := _quote_order()
	assert_false(valid.is_empty())
	assert_true(Customers.sanitize({}).is_empty())
	for broken: Dictionary in [
		{ "id": "" },
		{ "customer": "nobody" },
		{ "item": "scooter" },
		{ "item": "nothing" },
		{ "district": "nowhere" },
		{ "quantity": 0 },
		{ "unit_price": 0 },
		{ "temperament": 99 },
	]:
		var source := valid.duplicate()
		source.merge(broken, true)
		assert_true(Customers.sanitize(source).is_empty(), "rejects %s" % broken)
	var countered := valid.duplicate()
	countered.countered = true
	assert_false(bool(Customers.sanitize(countered).countered), "no counter without a counter price")


func test_saved_orders_survive_a_reload_and_junk_is_dropped() -> void:
	var order := _take(CustomerDef.Temperament.HAGGLER)
	order.countered = true
	var offer := _offer(CustomerDef.Temperament.BULK)
	var data := _run.to_dict()
	data.customer_orders.append({ "id": "junk" })
	data.customer_offers.append({ "id": "junk" })
	var loaded := RunState.from_dict(JSON.parse_string(JSON.stringify(data)))
	assert_eq(loaded.customer_orders.size(), 1)
	assert_eq(loaded.customer_orders[0], order)
	assert_eq(loaded.customer_offers.size(), 1)
	assert_eq(loaded.customer_offers[0], offer)
