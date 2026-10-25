extends GutTest

var _run: RunState
var _shop: BusinessDef
var _car_wash: BusinessDef
var _nightclub: BusinessDef
var _restaurant: BusinessDef
var _watches: ItemDef
var _sims: ItemDef
var _pistol: ItemDef


func before_each() -> void:
	_run = RunState.new()
	_run.price_seed = 4711
	_run.district_id = &"old_market"
	_run.career = true
	Story.mark(_run, War.VEX_FELL)
	_run.cash = 10000000
	_shop = Content.business(&"corner_shop")
	_car_wash = Content.business(&"car_wash")
	_nightclub = Content.business(&"nightclub")
	_restaurant = Content.business(&"restaurant")
	_watches = Content.item(&"rare_watches")
	_sims = Content.item(&"burner_sims")
	_pistol = Content.item(&"ghost_pistol")
	_set_rank(_shop.min_rank)
	_hold(&"old_market")


func _set_rank(rank_number: int) -> void:
	_run.street_cred = int(StreetCred.RANKS[rank_number - 1].cred)


func _hold(district_id: StringName) -> void:
	Corners.take_all(_run, district_id)


func _lose_hold(district_id: StringName) -> void:
	for corner in Corners.of(district_id).slice(1):
		Corners.lose(_run, corner.id)


func _open(business: BusinessDef, district_id: StringName = &"old_market") -> Dictionary:
	assert_eq(Businesses.buy(_run, business, district_id), Businesses.Result.OK, String(business.id))
	return _run.businesses.back()


func _stock(entry: Dictionary, item: ItemDef, units: int, paid: int) -> void:
	Inventory.add_units(_run, item.id, units)
	_run.cost_basis[item.id] = paid
	assert_eq(Businesses.load_stock(_run, entry, item, units), Businesses.Result.OK)


func test_sanitize_keeps_a_valid_entry_and_cleans_its_stock() -> void:
	var clean := Businesses.sanitize({
		"business": "corner_shop",
		"district": "old_market",
		"stock": { "rare_watches": 3.0, "burner_sims": 0, "no_such_item": 4 },
		"closed_until": 5.0,
	})
	assert_eq(clean, {
		"business": "corner_shop",
		"district": "old_market",
		"stock": { "rare_watches": 3 },
		"closed_until": 5,
	})


func test_sanitize_drops_unknown_businesses_and_districts() -> void:
	assert_true(Businesses.sanitize({ "business": "casino_boat", "district": "old_market" }).is_empty())
	assert_true(Businesses.sanitize({ "business": "corner_shop", "district": "moon_base" }).is_empty())
	assert_true(Businesses.sanitize({}).is_empty())


func test_sanitize_fills_missing_fields() -> void:
	var clean := Businesses.sanitize({ "business": "car_wash", "district": "docks", "stock": "junk", "closed_until": -3 })
	assert_eq(clean.stock, {})
	assert_eq(clean.closed_until, 0)


func test_sanitize_drops_disallowed_businesses_in_district() -> void:
	assert_true(Businesses.sanitize({ "business": "boutique", "district": "slums" }).is_empty())
	assert_false(Businesses.sanitize({ "business": "corner_shop", "district": "slums" }).is_empty())


func test_from_dict_deduplicates_businesses_and_preserves_higher_level() -> void:
	var raw_data := {
		"businesses": [
			{ "business": "corner_shop", "district": "old_market", "level": 1 },
			{ "business": "corner_shop", "district": "old_market", "level": 4 },
			{ "business": "corner_shop", "district": "old_market", "level": 2 },
			{ "business": "bakery", "district": "old_market", "level": 3 },
			{ "business": "boutique", "district": "slums", "level": 1 },
			{ "business": "deleted_biz", "district": "old_market", "level": 1 },
		]
	}
	var loaded := RunState.from_dict(raw_data)
	assert_eq(loaded.businesses.size(), 2)
	assert_eq(loaded.businesses[0].business, "corner_shop")
	assert_eq(loaded.businesses[0].level, 4)
	assert_eq(loaded.businesses[1].business, "bakery")
	assert_eq(loaded.businesses[1].level, 3)


func test_from_dict_drops_deleted_crew_roles() -> void:
	var raw_data := {
		"crew": [
			{ "role": "lookout" },
			{ "role": "deleted_sniper_role" }
		]
	}
	var loaded := RunState.from_dict(raw_data)
	assert_eq(loaded.crew.size(), 1)
	assert_eq(loaded.crew[0].role, "lookout")


func test_entries_survive_a_save() -> void:
	var entry := _open(_shop)
	_stock(entry, _watches, 3, 400)
	entry.closed_until = 4
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(_run.to_dict())))
	assert_eq(Businesses.sanitize(restored.businesses[0]), entry)


func test_buying_takes_cash_and_adds_an_empty_business() -> void:
	var entry := _open(_shop)
	assert_eq(_run.cash, 10000000 - _shop.price)
	assert_eq(entry, { "business": "corner_shop", "district": "old_market", "stock": {}, "closed_until": 0 })
	assert_eq(Businesses.in_district(_run, &"old_market"), [entry] as Array[Dictionary])
	assert_true(Businesses.in_district(_run, &"docks").is_empty())


func test_businesses_wait_for_act_two() -> void:
	_run.story_flags.clear()
	assert_eq(Businesses.buy(_run, _shop, &"old_market"), Businesses.Result.NOT_CAREER)
	assert_true(_run.businesses.is_empty())
	assert_eq(_run.cash, 10000000)


func test_unknown_business_is_refused() -> void:
	assert_eq(Businesses.check_buy(_run, null, &"old_market"), Businesses.Result.UNKNOWN)


func test_businesses_need_a_held_district_and_the_rank() -> void:
	assert_eq(Businesses.check_buy(_run, _shop, &"docks"), Businesses.Result.NOT_HELD, "district not held")
	assert_eq(Businesses.check_buy(_run, _nightclub, &"old_market"), Businesses.Result.RANK_TOO_LOW, "nightclub needs a higher rank")
	_hold(&"docks")
	_lose_hold(&"docks")
	assert_eq(Businesses.check_buy(_run, _shop, &"docks"), Businesses.Result.NOT_HELD, "hold lost")


func test_businesses_respect_district_restrictions() -> void:
	_hold(&"slums")
	_set_rank(7)
	var nightclub := Content.business(&"nightclub")
	assert_not_null(nightclub)
	assert_eq(Businesses.check_buy(_run, nightclub, &"slums"), Businesses.Result.NOT_ALLOWED, "nightclub not allowed in slums")


func test_an_unheld_district_has_no_slots() -> void:
	assert_eq(Businesses.slots_free(_run, &"docks"), 0)
	_hold(&"docks")
	assert_eq(Businesses.slots_free(_run, &"docks"), 1)


func test_a_second_slot_opens_with_the_rank() -> void:
	_run.cash = 2000000
	assert_eq(Businesses.slots_free(_run, &"old_market"), 1)
	_open(_shop)
	assert_eq(Businesses.slots_free(_run, &"old_market"), 0)
	assert_eq(Businesses.buy(_run, _car_wash, &"old_market"), Businesses.Result.NO_SLOT)
	_set_rank(Turf.SECOND_BUSINESS_RANK)
	assert_eq(Businesses.slots_free(_run, &"old_market"), 1)
	_open(_restaurant)
	assert_eq(Businesses.slots_free(_run, &"old_market"), 0)
	assert_eq(_run.businesses.size(), 2)


func test_buying_needs_the_price_in_cash() -> void:
	_run.cash = _shop.price - 1
	assert_eq(Businesses.buy(_run, _shop, &"old_market"), Businesses.Result.NOT_ENOUGH_CASH)
	assert_true(_run.businesses.is_empty())
	_run.cash = _shop.price
	assert_eq(Businesses.buy(_run, _shop, &"old_market"), Businesses.Result.OK)
	assert_eq(_run.cash, 0)


func test_loading_moves_units_from_the_bag_and_keeps_the_price_paid() -> void:
	var entry := _open(_shop)
	Inventory.add_units(_run, _watches.id, 5)
	_run.cost_basis[_watches.id] = 400
	assert_eq(Businesses.load_stock(_run, entry, _watches, 5), Businesses.Result.OK)
	assert_eq(Inventory.count(_run, _watches.id), 0)
	assert_eq(Businesses.stocked(entry, _watches.id), 5)
	assert_eq(Businesses.stock_used(entry), 5)
	assert_eq(Businesses.total_stocked(_run, _watches.id), 5)
	assert_eq(_run.cost_basis[_watches.id], 400)


func test_loading_needs_carried_units() -> void:
	var entry := _open(_shop)
	Inventory.add_units(_run, _watches.id, 2)
	assert_eq(Businesses.load_stock(_run, entry, _watches, 3), Businesses.Result.NO_STOCK)
	assert_eq(Businesses.load_stock(_run, entry, _watches, 0), Businesses.Result.NO_STOCK)
	assert_eq(Businesses.load_stock(_run, entry, _watches, -1), Businesses.Result.NO_STOCK)
	assert_eq(Inventory.count(_run, _watches.id), 2)
	assert_eq(Businesses.stock_used(entry), 0)


func test_loading_is_capped_by_stock_capacity() -> void:
	var entry := _open(_shop)
	Inventory.add_units(_run, _sims.id, _shop.stock_capacity + 5)
	assert_eq(Businesses.max_load(_run, entry, _sims), _shop.stock_capacity)
	assert_eq(Businesses.load_stock(_run, entry, _sims, _shop.stock_capacity + 1), Businesses.Result.NO_ROOM)
	assert_eq(Businesses.load_stock(_run, entry, _sims, _shop.stock_capacity), Businesses.Result.OK)
	assert_eq(Businesses.max_load(_run, entry, _sims), 0)
	assert_eq(Businesses.load_stock(_run, entry, _sims, 1), Businesses.Result.NO_ROOM)
	assert_eq(Inventory.count(_run, _sims.id), 5)


func test_loading_waits_while_closed() -> void:
	var entry := _open(_shop)
	Inventory.add_units(_run, _watches.id, 2)
	entry.closed_until = _run.day + 1
	assert_eq(Businesses.load_stock(_run, entry, _watches, 2), Businesses.Result.CLOSED)
	assert_eq(Inventory.count(_run, _watches.id), 2)


func test_unloading_returns_units_to_the_bag() -> void:
	var entry := _open(_shop)
	_stock(entry, _watches, 4, 400)
	assert_eq(Businesses.unload_stock(_run, entry, _watches, 3), Businesses.Result.OK)
	assert_eq(Inventory.count(_run, _watches.id), 3)
	assert_eq(Businesses.stocked(entry, _watches.id), 1)
	assert_eq(_run.cost_basis[_watches.id], 400)
	assert_eq(Businesses.unload_stock(_run, entry, _watches, 2), Businesses.Result.NO_STOCK)
	assert_eq(Businesses.unload_stock(_run, entry, _watches, 0), Businesses.Result.NO_STOCK)


func test_unloading_respects_bag_space_and_item_slots() -> void:
	var entry := _open(_shop)
	_stock(entry, _pistol, 3, 300)
	Inventory.add_units(_run, _sims.id, Inventory.capacity(_run) - 3)
	assert_eq(Businesses.max_unload(_run, entry, _pistol), 1)
	assert_eq(Businesses.unload_stock(_run, entry, _pistol, 2), Businesses.Result.NO_ROOM)
	assert_eq(Businesses.unload_stock(_run, entry, _pistol, 1), Businesses.Result.OK)
	assert_eq(Inventory.count(_run, _pistol.id), 1)
	assert_eq(Businesses.stocked(entry, _pistol.id), 2)


func test_unloading_works_while_closed() -> void:
	_hold(&"docks")
	var entry := _open(_car_wash, &"docks")
	_stock(entry, _watches, 2, 400)
	_lose_hold(&"docks")
	assert_false(Businesses.is_open(_run, entry))
	assert_eq(Businesses.unload_stock(_run, entry, _watches, 2), Businesses.Result.OK)
	assert_eq(Inventory.count(_run, _watches.id), 2)


func test_open_needs_the_day_and_the_district() -> void:
	_hold(&"docks")
	var entry := _open(_car_wash, &"docks")
	assert_true(Businesses.is_open(_run, entry))
	entry.closed_until = _run.day + 1
	assert_false(Businesses.is_open(_run, entry))
	_run.day += 1
	assert_true(Businesses.is_open(_run, entry))
	_lose_hold(&"docks")
	assert_false(Businesses.is_open(_run, entry))


func test_sale_price_follows_the_resident_dealer() -> void:
	var entry := _open(_shop)
	var dealer := Content.dealer_in(&"old_market")
	assert_not_null(dealer)
	var expected := floori(Market.sell_price(_run, dealer, _sims) * Businesses.SALE_FACTOR)
	assert_eq(Businesses.sale_price(_run, entry, _sims), expected)


func test_sale_price_falls_back_to_base_price_without_a_dealer() -> void:
	assert_null(Content.dealer_in(&"downtown"))
	_set_rank(_restaurant.min_rank)
	_hold(&"downtown")
	var entry := _open(_restaurant, &"downtown")
	assert_eq(Businesses.sale_price(_run, entry, _sims), floori(_sims.base_price * Businesses.SALE_FACTOR))


func test_luxury_bonus_only_lifts_luxury_goods() -> void:
	_set_rank(Turf.SECOND_BUSINESS_RANK)
	_hold(&"west_end")
	var shop := _open(_restaurant, &"west_end")
	var club := _open(_nightclub, &"west_end")
	var local := Market.sell_price(_run, Content.dealer_in(&"west_end"), _watches)
	assert_eq(_watches.category, Businesses.LUXURY)
	assert_eq(Businesses.sale_price(_run, club, _watches), floori(local * Businesses.SALE_FACTOR * (1.0 + _nightclub.luxury_bonus)))
	assert_eq(Businesses.sale_price(_run, shop, _watches), floori(local * Businesses.SALE_FACTOR))
	assert_eq(Businesses.sale_price(_run, club, _sims), Businesses.sale_price(_run, shop, _sims))


func test_selling_moves_the_most_valuable_goods_first() -> void:
	var entry := _open(_shop)
	_stock(entry, _watches, 2, 400)
	_stock(entry, _sims, 5, 50)
	var watch_price := Businesses.sale_price(_run, entry, _watches)
	var sim_price := Businesses.sale_price(_run, entry, _sims)
	assert_gt(watch_price, sim_price)
	var gross := watch_price * 2 + sim_price * (_shop.sales_per_phase - 2)
	var cash_before := _run.cash

	assert_eq(Businesses.sell_phase(_run), gross)
	assert_eq(_run.cash, cash_before + gross)
	assert_eq(_run.profit, gross - 400 * 2 - 50 * (_shop.sales_per_phase - 2))
	assert_eq(Businesses.stocked(entry, _watches.id), 0)
	assert_eq(Businesses.stocked(entry, _sims.id), 5 - (_shop.sales_per_phase - 2))


func test_trusted_families_take_no_protection_cut() -> void:
	_hold(&"downtown")
	var entry := _open(_shop, &"downtown")
	_stock(entry, _sims, 5, 50)
	Families.shift(_run, Turf.home_family(&"downtown").id, Families.TRUSTED_AT)
	assert_false(Businesses.pays_protection(_run, &"downtown"))
	var expected := Businesses.sale_price(_run, entry, _sims) * _shop.sales_per_phase
	assert_eq(Businesses.sell_phase(_run), expected)


func test_neutral_families_take_a_protection_cut() -> void:
	assert_true(Businesses.pays_protection(_run, &"downtown"))
	assert_false(Businesses.pays_protection(_run, &"warehouse_row"), "no family runs it")


func test_selling_has_no_side_effects_beyond_cash_and_profit() -> void:
	var entry := _open(_shop)
	_stock(entry, _watches, 5, 400)
	_run.heat = 30
	var share_before := Turf.share(_run, &"old_market")
	var cred_before := _run.street_cred
	Businesses.sell_phase(_run)
	assert_eq(_run.heat, 30)
	assert_eq(_run.trades, 0)
	assert_eq(_run.street_cred, cred_before)
	assert_eq(Turf.share(_run, &"old_market"), share_before)


func test_closed_and_empty_businesses_sell_nothing() -> void:
	var entry := _open(_shop)
	assert_eq(Businesses.sell_phase(_run), 0)
	_stock(entry, _watches, 3, 400)
	entry.closed_until = _run.day + 1
	var cash_before := _run.cash
	assert_eq(Businesses.sell_phase(_run), 0)
	assert_eq(_run.cash, cash_before)
	assert_eq(Businesses.stocked(entry, _watches.id), 3)


func test_price_paid_is_forgotten_once_nothing_is_left() -> void:
	var entry := _open(_shop)
	_stock(entry, _watches, 2, 400)
	Inventory.add_units(_run, _sims.id, 3)
	_stock(entry, _sims, 1, 50)
	Businesses.sell_phase(_run)
	assert_false(_run.cost_basis.has(_watches.id))
	assert_eq(_run.cost_basis[_sims.id], 50, "still carried")


func test_raid_chance_rises_with_heat_and_falls_on_held_turf() -> void:
	var entry := _open(_shop)
	assert_almost_eq(Businesses.raid_chance(_run, entry), Businesses.BASE_RAID_CHANCE - Businesses.RAID_HELD_REDUCTION, 0.0001)
	_run.heat = 100
	assert_almost_eq(Businesses.raid_chance(_run, entry), Businesses.BASE_RAID_CHANCE + 100 * Businesses.RAID_PER_HEAT - Businesses.RAID_HELD_REDUCTION, 0.0001)


func test_hostile_home_family_doubles_the_raid_chance() -> void:
	_hold(&"downtown")
	var entry := _open(_shop, &"downtown")
	var calm := Businesses.raid_chance(_run, entry)
	Families.shift(_run, Turf.home_family(&"downtown").id, Families.HOSTILE_AT)
	assert_almost_eq(Businesses.raid_chance(_run, entry), calm * Businesses.HOSTILE_RAID_FACTOR, 0.0001)


func test_morning_pays_upkeep_and_cools_heat() -> void:
	_open(_car_wash)
	_run.cash = 10000
	_run.heat = 20
	var rolls: Array[float] = [0.99]
	var report := Businesses.morning(_run, rolls)
	assert_eq(report.upkeep, _car_wash.effective_upkeep(1))
	assert_true(report.raided.is_empty())
	assert_eq(_run.cash, 10000 - _car_wash.effective_upkeep(1))
	assert_eq(_run.heat, 20 - _car_wash.daily_heat_drop)


func test_heat_never_drops_below_zero() -> void:
	_open(_car_wash)
	_run.heat = 1
	var rolls: Array[float] = []
	Businesses.morning(_run, rolls)
	assert_eq(_run.heat, 0)


func test_unpaid_upkeep_closes_the_business_for_the_day() -> void:
	var entry := _open(_car_wash)
	_run.cash = _car_wash.effective_upkeep(1) - 1
	_run.heat = 20
	var rolls: Array[float] = []
	var report := Businesses.morning(_run, rolls)
	assert_eq(report.upkeep, 0)
	assert_eq(_run.cash, _car_wash.effective_upkeep(1) - 1)
	assert_eq(_run.heat, 20, "a closed business launders nothing")
	assert_false(Businesses.is_open(_run, entry))
	_run.day += 1
	assert_true(Businesses.is_open(_run, entry))


func test_a_raid_clears_the_stock_and_closes_the_business() -> void:
	var entry := _open(_shop)
	_stock(entry, _watches, 4, 400)
	var rolls: Array[float] = [0.0]
	var report := Businesses.morning(_run, rolls)
	assert_eq(report.raided, [_shop.display_name] as Array[String])
	assert_eq(Businesses.stock_used(entry), 0)
	assert_false(_run.cost_basis.has(_watches.id))
	assert_false(Businesses.is_open(_run, entry))
	assert_eq(entry.closed_until, _run.day + 1)


func test_missing_rolls_mean_no_raid() -> void:
	var entry := _open(_shop)
	_stock(entry, _watches, 4, 400)
	var rolls: Array[float] = []
	var report := Businesses.morning(_run, rolls)
	assert_true(report.raided.is_empty())
	assert_eq(Businesses.stocked(entry, _watches.id), 4)
	assert_true(Businesses.is_open(_run, entry))


func test_each_roll_belongs_to_its_business() -> void:
	_set_rank(Turf.SECOND_BUSINESS_RANK)
	_hold(&"old_market")
	var shop := _open(_shop)
	var wash := _open(_car_wash)
	_stock(shop, _watches, 2, 400)
	_stock(wash, _sims, 6, 50)
	_run.cash = 50000
	var rolls: Array[float] = [0.99, 0.0]
	var report := Businesses.morning(_run, rolls)
	assert_eq(report.upkeep, _shop.effective_upkeep(1) + _car_wash.effective_upkeep(1))
	assert_eq(report.raided, [_car_wash.display_name] as Array[String])
	assert_eq(Businesses.stocked(shop, _watches.id), 2)
	assert_eq(Businesses.stock_used(wash), 0)


func test_businesses_refuse_goods_outside_dealer_tier() -> void:
	var entry := _open(_shop)
	var high_tier := Content.item(&"gold_bars")
	assert_not_null(high_tier)
	assert_eq(high_tier.tier, 3)
	assert_false(Businesses.deals_in(entry, high_tier))
	assert_eq(Businesses.sale_price(_run, entry, high_tier), 0)
	Inventory.add_units(_run, high_tier.id, 5)
	assert_eq(Businesses.max_load(_run, entry, high_tier), 0)
	assert_eq(Businesses.load_stock(_run, entry, high_tier, 2), Businesses.Result.WRONG_TIER)


func test_selling_skips_goods_outside_dealer_tier() -> void:
	var entry := _open(_shop)
	var high_tier := Content.item(&"gold_bars")
	assert_not_null(high_tier)
	entry.stock[String(high_tier.id)] = 2
	_stock(entry, _sims, 2, 50)
	var gross := Businesses.sale_price(_run, entry, _sims) * 2
	var earned := Businesses.sell_phase(_run)
	assert_eq(earned, gross)
	assert_eq(Businesses.stocked(entry, high_tier.id), 2)
	assert_eq(Businesses.stocked(entry, _sims.id), 0)
