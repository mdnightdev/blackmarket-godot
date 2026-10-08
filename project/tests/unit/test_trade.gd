extends GutTest

var _run: RunState
var _phones: ItemDef
var _pistol: ItemDef


func before_each() -> void:
	_run = RunState.new()
	_phones = Content.item(&"burner_phones")
	_pistol = Content.item(&"ghost_pistol")


func test_buy_pays_and_adds_units() -> void:
	assert_eq(Trade.buy(_run, _phones, 5, 100), Trade.Result.OK)
	assert_eq(_run.cash, RunState.STARTING_CASH - 500)
	assert_eq(Inventory.count(_run, _phones.id), 5)
	assert_eq(_run.cost_basis[_phones.id], 100)


func test_cost_basis_is_weighted_average() -> void:
	Trade.buy(_run, _phones, 2, 100)
	Trade.buy(_run, _phones, 2, 200)
	assert_eq(_run.cost_basis[_phones.id], 150)


func test_buy_fails_without_cash() -> void:
	assert_eq(Trade.buy(_run, _phones, 3, 1000), Trade.Result.NOT_ENOUGH_CASH)
	assert_eq(_run.cash, RunState.STARTING_CASH)
	assert_eq(Inventory.count(_run, _phones.id), 0)


func test_buy_fails_without_space() -> void:
	_run.cash = 100_000
	assert_eq(Trade.buy(_run, _pistol, 11, 100), Trade.Result.NO_SPACE)
	assert_eq(Trade.buy(_run, _pistol, 10, 100), Trade.Result.OK)
	assert_eq(Inventory.free_space(_run), 0)


func test_buy_blocked_while_over_capacity() -> void:
	_run.inventory = {&"burner_phones": Inventory.BASE_CAPACITY + 2}
	assert_eq(Trade.check_buy(_run, _phones, 1, 100), Trade.Result.OVER_CAPACITY)
	assert_eq(Trade.buy(_run, _phones, 1, 100), Trade.Result.OVER_CAPACITY)
	assert_eq(Trade.max_buyable(_run, _phones, 100), 0)
	assert_eq(_run.cash, RunState.STARTING_CASH)
	assert_eq(Inventory.count(_run, _phones.id), Inventory.BASE_CAPACITY + 2)


func test_max_buyable_respects_cash_and_slots() -> void:
	assert_eq(Trade.max_buyable(_run, _phones, 300), 6)
	_run.cash = 100_000
	assert_eq(Trade.max_buyable(_run, _pistol, 100), 10)


func test_sell_pays_and_clears_cost_basis() -> void:
	Trade.buy(_run, _phones, 4, 100)
	assert_eq(Trade.sell(_run, _phones, 4, 150), Trade.Result.OK)
	assert_eq(_run.cash, RunState.STARTING_CASH + 200)
	assert_eq(Inventory.count(_run, _phones.id), 0)
	assert_false(_run.cost_basis.has(_phones.id))


func test_cannot_sell_more_than_carried() -> void:
	Trade.buy(_run, _phones, 2, 100)
	assert_eq(Trade.sell(_run, _phones, 3, 100), Trade.Result.NOT_ENOUGH_UNITS)
	assert_eq(Inventory.count(_run, _phones.id), 2)


func test_gear_is_bought_once() -> void:
	var bag := Content.item(&"messenger_bag")
	assert_eq(Trade.buy_gear(_run, bag), Trade.Result.OK)
	assert_eq(_run.cash, RunState.STARTING_CASH - bag.base_price)
	assert_eq(Trade.buy_gear(_run, bag), Trade.Result.ALREADY_OWNED)


func test_gear_needs_cash() -> void:
	assert_eq(Trade.buy_gear(_run, Content.item(&"smuggler_van")), Trade.Result.NOT_ENOUGH_CASH)
	assert_true(_run.gear.is_empty())


func test_restricted_goods_need_the_rank() -> void:
	var warhead := Content.item(&"nuclear_warhead")
	_run.cash = warhead.base_price
	assert_eq(Trade.buy(_run, warhead, 1, warhead.base_price), Trade.Result.RANK_TOO_LOW)
	_run.street_cred = int(StreetCred.RANKS[warhead.min_rank - 1].cred)
	assert_eq(Trade.buy(_run, warhead, 1, warhead.base_price), Trade.Result.OK)


func test_restricted_goods_have_a_seller_and_never_show_up_in_orders() -> void:
	var restricted := Content.items(ItemDef.Kind.TRADE_GOOD).filter(func(item: ItemDef) -> bool: return item.is_restricted())
	assert_gt(restricted.size(), 0)
	for item: ItemDef in restricted:
		assert_true(Content.dealers().any(func(dealer: DealerDef) -> bool: return dealer.sells(item)), String(item.id))
	_run.street_cred = int(StreetCred.RANKS[-1].cred)
	for day in range(1, 15):
		_run.day = day
		for offer in Orders.board(_run, &"tran_bar"):
			assert_false(Content.item(StringName(offer.item)).is_restricted(), offer.id)
