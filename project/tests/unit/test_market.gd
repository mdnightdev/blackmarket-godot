extends GutTest

var _run: RunState
var _dealer: DealerDef
var _item: ItemDef


func before_each() -> void:
	_run = RunState.new()
	_run.price_seed = 1234
	_dealer = DealerDef.new()
	_dealer.id = &"test_dealer"
	_dealer.district_id = &"old_market"
	_dealer.price_bias = {&"comms": 0.5}
	_item = ItemDef.new()
	_item.id = &"test_phone"
	_item.category = &"comms"
	_item.base_price = 1000


func test_prices_are_stable_for_the_same_phase() -> void:
	var first := Market.buy_price(_run, _dealer, _item)
	assert_eq(Market.buy_price(RunState.from_dict(_run.to_dict()), _dealer, _item), first)


func test_prices_stay_inside_swing_and_bias() -> void:
	for day in range(1, 30):
		_run.day = day
		var price := Market.buy_price(_run, _dealer, _item)
		assert_between(price, floori(500 * 0.7 * 0.94), ceili(500 * 1.3 * 1.06))


func test_dealer_buys_back_below_asking() -> void:
	assert_lt(Market.sell_price(_run, _dealer, _item), Market.buy_price(_run, _dealer, _item))


func test_prices_move_between_days() -> void:
	var seen := {}
	for day in range(1, 11):
		_run.day = day
		seen[Market.buy_price(_run, _dealer, _item)] = true
	assert_gt(seen.size(), 5)


func test_no_price_change_on_first_phase() -> void:
	assert_eq(Market.price_change(_run, _dealer, _item), 0.0)


func test_price_change_compares_with_previous_phase() -> void:
	_run.phase = RunState.Phase.NOON
	var previous := Market.asking_price_at(_run, _dealer, _item, 0)
	var expected := float(Market.buy_price(_run, _dealer, _item) - previous) / previous
	assert_almost_eq(Market.price_change(_run, _dealer, _item), expected, 0.0001)


func test_dealer_closed_for_the_phase_they_walked_out() -> void:
	assert_true(Market.is_open(_run, _dealer))
	_run.walked_out[_dealer.id] = Calendar.stamp(_run)
	assert_false(Market.is_open(_run, _dealer))
	assert_true(Market.is_open(_run, Content.dealer_in(&"old_market")), "other dealers in the district still trade")
	Calendar.advance_phase(_run)
	assert_true(Market.is_open(_run, _dealer))
