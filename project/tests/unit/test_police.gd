extends GutTest

var _run: RunState
var _phones: ItemDef
var _papers: ItemDef


func before_each() -> void:
	_run = RunState.new()
	_phones = Content.item(&"burner_phones")
	_papers = Content.item(&"forged_papers")


func test_no_stops_with_an_empty_bag() -> void:
	_run.heat = 90
	assert_eq(Police.stop_chance(_run), 0.0)


func test_stop_chance_grows_with_heat_and_is_capped() -> void:
	Inventory.add_units(_run, _phones.id, 5)
	var calm := Police.stop_chance(_run)
	_run.heat = 80
	assert_gt(Police.stop_chance(_run), calm)
	_run.heat = 100
	_run.district_id = &"north_port"
	Inventory.add_units(_run, _papers.id, 15)
	assert_eq(Police.stop_chance(_run), Police.MAX_STOP_CHANCE)


func test_bribe_scales_with_carried_value() -> void:
	Inventory.add_units(_run, _phones.id, 4)
	assert_eq(Police.bribe_cost(_run), Police.MIN_BRIBE)
	Inventory.add_units(_run, _phones.id, 16)
	assert_eq(Police.bribe_cost(_run), roundi(20 * _phones.base_price * Police.BRIBE_FRACTION))


func test_escape_keeps_goods_and_adds_heat() -> void:
	Inventory.add_units(_run, _phones.id, 3)
	assert_true(Police.run_for_it(_run, 0.0))
	assert_eq(Inventory.count(_run, _phones.id), 3)
	assert_eq(_run.heat, Police.ESCAPED_HEAT)


func test_getting_caught_empties_the_bag() -> void:
	Trade.buy(_run, _phones, 3, 100)
	assert_false(Police.run_for_it(_run, 0.99))
	assert_eq(Inventory.used(_run), 0)
	assert_false(_run.cost_basis.has(_phones.id))
	assert_eq(_run.heat, Police.CAUGHT_HEAT)
	assert_eq(_run.busts, 1)


func test_vehicle_improves_escape_odds() -> void:
	var on_foot := Police.escape_chance(_run)
	_run.gear.append(&"scooter")
	assert_almost_eq(Police.escape_chance(_run), on_foot + Police.VEHICLE_ESCAPE_BONUS, 0.0001)


func test_complying_hands_over_half_the_riskiest_stack() -> void:
	_run.heat = 40
	Inventory.add_units(_run, _phones.id, 2)
	Inventory.add_units(_run, _papers.id, 3)
	var taken := Police.comply(_run)
	assert_eq(taken.item, _papers)
	assert_eq(taken.quantity, 2)
	assert_eq(Inventory.count(_run, _papers.id), 1)
	assert_eq(Inventory.count(_run, _phones.id), 2)
	assert_eq(_run.heat, 40 - Police.COMPLY_HEAT_DROP)


func test_no_stop_right_after_a_stop() -> void:
	Inventory.add_units(_run, _phones.id, 5)
	_run.heat = 50
	assert_gt(Police.stop_chance(_run), 0.0)
	Encounters.police_stop(_run)
	assert_eq(Police.stop_chance(_run), 0.0)
	Calendar.advance_phase(_run)
	assert_eq(Police.stop_chance(_run), 0.0, "the phase after a stop is quiet")
	Calendar.advance_phase(_run)
	assert_gt(Police.stop_chance(_run), 0.0)


func test_held_turf_sees_fewer_stops() -> void:
	Inventory.add_units(_run, _phones.id, 5)
	_run.heat = 30
	var contested := Police.stop_chance(_run)
	_run.turf[_run.district_id] = Turf.HOLD_SHARE
	assert_almost_eq(Police.stop_chance(_run), contested * Turf.HELD_STOP_FACTOR, 0.0001)


func test_escape_odds_never_drop_below_the_floor() -> void:
	_run.heat = Heat.MAX
	assert_eq(Police.escape_chance(_run), Police.MIN_ESCAPE_CHANCE)


func test_raid_takes_the_bag_but_not_the_stash() -> void:
	_run.heat = Heat.MAX
	Inventory.add_units(_run, _phones.id, 5)
	_run.stash[_papers.id] = 2
	Police.raid(_run)
	assert_eq(Inventory.used(_run), 0)
	assert_eq(Inventory.stashed(_run, _papers.id), 2)
	assert_eq(_run.heat, Police.RAID_HEAT_AFTER)
	assert_eq(_run.busts, 1)
