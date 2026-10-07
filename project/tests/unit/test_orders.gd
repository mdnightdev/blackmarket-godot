extends GutTest

const BAR: StringName = &"tran_bar"

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	_run.price_seed = 777
	_run.cash = 100000


func test_board_posts_offers_from_resident_dealers() -> void:
	var offers := Orders.board(_run, BAR)
	assert_between(offers.size(), 1, Orders.POSTED_PER_DAY)
	for offer in offers:
		var dealer := Content.dealer(StringName(offer.dealer))
		var item := Content.item(StringName(offer.item))
		assert_not_null(dealer)
		assert_not_null(item)
		assert_true(dealer.is_resident(), offer.id)
		assert_eq(item.kind, ItemDef.Kind.TRADE_GOOD)
		assert_gt(int(offer.due), Calendar.stamp(_run))


func test_board_is_stable_after_reload() -> void:
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(_run.to_dict())))
	assert_eq(Orders.board(restored, BAR), Orders.board(_run, BAR))


func test_order_pays_a_premium() -> void:
	for day in range(1, 15):
		_run.day = day
		for offer in Orders.board(_run, BAR):
			var item := Content.item(StringName(offer.item))
			var dealer := Content.dealer(StringName(offer.dealer))
			var normal := item.base_price * dealer.bias_for(item.category)
			assert_between(float(offer.price), normal * Orders.PREMIUM_MIN - 1.0, normal * Orders.PREMIUM_MAX + 1.0, offer.id)


func test_accepting_moves_an_offer_off_the_board() -> void:
	var offer: Dictionary = Orders.board(_run, BAR)[0]
	assert_eq(Orders.accept(_run, offer), Orders.Result.OK)
	assert_eq(_run.orders.size(), 1)
	assert_false(Orders.board(_run, BAR).any(func(entry: Dictionary) -> bool: return entry.id == offer.id))
	assert_eq(Orders.accept(_run, offer), Orders.Result.TAKEN)


func test_cannot_hold_more_than_the_limit() -> void:
	var taken := 0
	for day in range(1, 5):
		_run.day = day
		for offer in Orders.board(_run, BAR):
			if Orders.accept(_run, offer) == Orders.Result.OK:
				taken += 1
	assert_eq(taken, Orders.MAX_ACTIVE)
	assert_eq(_run.orders.size(), Orders.MAX_ACTIVE)


func test_delivery_pays_the_agreed_price() -> void:
	var order := _take_first_order()
	var item := Content.item(StringName(order.item))
	assert_false(Orders.can_deliver(_run, order), "nothing carried yet")
	Inventory.add_units(_run, item.id, int(order.quantity))
	var cash_before := _run.cash
	assert_true(Orders.deliver(_run, order))
	assert_eq(_run.cash, cash_before + Orders.total(order))
	assert_eq(Inventory.count(_run, item.id), 0)
	assert_true(_run.orders.is_empty())


func test_short_delivery_fails() -> void:
	var order := _take_first_order()
	Inventory.add_units(_run, StringName(order.item), int(order.quantity) - 1)
	assert_false(Orders.deliver(_run, order))
	assert_eq(_run.orders.size(), 1)


func test_missed_deadline_closes_the_order_and_the_dealer() -> void:
	var order := _take_first_order()
	var dealer := Content.dealer(StringName(order.dealer))
	while Calendar.stamp(_run) <= int(order.due):
		Calendar.advance_phase(_run)
	var missed := Orders.expire(_run)
	assert_eq(missed.size(), 1)
	assert_true(_run.orders.is_empty())
	assert_false(Market.is_open(_run, dealer), "dealer refuses for the phase")
	Calendar.advance_phase(_run)
	assert_true(Market.is_open(_run, dealer))


func test_expire_keeps_orders_still_on_time() -> void:
	_take_first_order()
	assert_true(Orders.expire(_run).is_empty())
	assert_eq(_run.orders.size(), 1)


func test_dropping_an_order_closes_the_dealer_this_phase() -> void:
	var order := _take_first_order()
	Orders.drop(_run, order)
	assert_true(_run.orders.is_empty())
	assert_false(Market.is_open(_run, Content.dealer(StringName(order.dealer))))


func test_taken_ids_from_old_days_are_pruned() -> void:
	_take_first_order()
	_run.orders.clear()
	_run.day += 1
	Orders.expire(_run)
	assert_true(_run.taken_orders.is_empty())


func test_orders_survive_save_and_load() -> void:
	var order := _take_first_order()
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(_run.to_dict())))
	assert_eq(restored.orders, [order] as Array[Dictionary])
	assert_eq(restored.taken_orders, _run.taken_orders)


func test_sanitize_fixes_bad_entries() -> void:
	var clean := Orders.sanitize({"quantity": -3, "price": "0"})
	assert_eq(clean.quantity, 1)
	assert_eq(clean.price, 1)
	assert_lt(int(clean.due), 0)


func _take_first_order() -> Dictionary:
	var offer: Dictionary = Orders.board(_run, BAR)[0]
	Orders.accept(_run, offer)
	return _run.orders[0]
