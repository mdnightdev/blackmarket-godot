extends GutTest

var _run: RunState
var _rng: RandomNumberGenerator


func before_each() -> void:
	_run = RunState.new()
	_rng = RandomNumberGenerator.new()
	_rng.seed = 7


func _event(id: StringName) -> EventDef:
	for event in Content.events():
		if event.id == id:
			return event
	return null


func _shift(district: String, category: String, multiplier: float, from: int, until: int) -> Dictionary:
	return { "district": district, "category": category, "multiplier": multiplier, "from": from, "until": until }


func test_events_load() -> void:
	assert_eq(Content.events().size(), 7)


func test_shift_changes_prices_only_where_and_when_it_applies() -> void:
	var dealer := Content.dealer_in(&"old_market")
	var phones := Content.item(&"burner_phones")
	var papers := Content.item(&"fake_ids")
	var before := Market.asking_price_at(_run, dealer, phones, 0)
	var untouched := Market.asking_price_at(_run, dealer, papers, 0)
	var later := Market.asking_price_at(_run, dealer, phones, 2)
	_run.market_shifts.append(_shift("old_market", "comms", 1.6, 0, 1))
	assert_almost_eq(float(Market.asking_price_at(_run, dealer, phones, 0)), before * 1.6, 1.0)
	assert_eq(Market.asking_price_at(_run, dealer, papers, 0), untouched)
	assert_eq(Market.asking_price_at(_run, dealer, phones, 2), later)


func test_expired_shifts_are_pruned() -> void:
	_run.day = 3
	_run.market_shifts.append(_shift("old_market", "comms", 1.6, 0, 4))
	_run.market_shifts.append(_shift("docks", "arms", 0.6, 6, 12))
	StreetEvents.prune(_run)
	assert_eq(_run.market_shifts.size(), 1)
	assert_eq(_run.market_shifts[0].district, "docks")


func test_headline() -> void:
	assert_eq(StreetEvents.headline(_shift("docks", "tech", 1.6, 0, 1)), "Tech prices up 60%")
	assert_eq(StreetEvents.headline(_shift("docks", "arms", 0.7, 0, 1)), "Arms prices down 30%")


func test_elsewhere_events_target_another_market() -> void:
	var event := _event(&"shipment_seized")
	for attempt in 30:
		var encounter := StreetEvents.prepare(_run, event, _rng)
		assert_ne(encounter.district, String(_run.district_id))
		var dealer := Content.dealer_in(StringName(encounter.district))
		assert_true(dealer.stock_categories.has(StringName(encounter.category)))


func test_tip_starts_next_morning() -> void:
	_run.day = 4
	var encounter := StreetEvents.prepare(_run, _event(&"dealer_tip"), _rng)
	assert_eq(encounter.from, 4 * RunState.Phase.size())
	assert_eq(encounter.until, encounter.from + _event(&"dealer_tip").duration_phases - 1)
	assert_string_contains(encounter.body, "tomorrow")


func test_rival_crew_needs_goods_the_local_dealer_buys() -> void:
	var event := _event(&"rival_crew")
	assert_true(StreetEvents.prepare(_run, event, _rng).is_empty())
	Inventory.add_units(_run, &"burner_phones", 2)
	var encounter := StreetEvents.prepare(_run, event, _rng)
	assert_eq(encounter.district, "old_market")
	assert_eq(encounter.category, "comms")


func test_fixed_category_needs_a_dealer_that_stocks_it() -> void:
	var amnesty := _event(&"gun_amnesty")
	assert_true(StreetEvents.prepare(_run, amnesty, _rng).is_empty())
	_run.district_id = &"slums"
	assert_eq(StreetEvents.prepare(_run, amnesty, _rng).category, "arms")


func test_mugging_takes_a_share_of_cash() -> void:
	var mugging := _event(&"mugging")
	var total := 0
	for attempt in 200:
		var encounter := StreetEvents.prepare(_run, mugging, _rng)
		if encounter.is_empty():
			continue
		var amount := int(encounter.amount)
		assert_between(amount, floori(_run.cash * StreetEvents.MUGGING_LOW), ceili(_run.cash * StreetEvents.MUGGING_HIGH))
		total += amount
	assert_gt(total, 0)
	_run.cash = 1_000_000
	var rich := StreetEvents.prepare(_run, mugging, _rng)
	assert_lte(int(rich.amount), StreetEvents.MAX_MUGGING, "a dollar cap protects big savings")
	_run.cash = StreetEvents.MIN_MUGGING_CASH - 1
	assert_true(StreetEvents.prepare(_run, mugging, _rng).is_empty())


func test_lucky_find_needs_bag_space() -> void:
	var find := _event(&"abandoned_stash")
	var encounter := StreetEvents.prepare(_run, find, _rng)
	assert_between(int(encounter.quantity), find.min_quantity, find.max_quantity)
	assert_lte(Content.item(StringName(encounter.item)).base_price, StreetEvents.LUCKY_FIND_MAX_PRICE)
	Inventory.add_units(_run, &"burner_sims", Inventory.capacity(_run))
	assert_true(StreetEvents.prepare(_run, find, _rng).is_empty())


func test_roll_respects_minimum_day() -> void:
	for attempt in 40:
		var encounter := StreetEvents.roll_event(_run, Content.events(), _rng)
		assert_false(encounter.is_empty())
		assert_false(encounter.event in ["mugging", "rival_crew", "gun_amnesty"])
