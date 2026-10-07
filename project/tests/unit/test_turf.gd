extends GutTest

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	_run.price_seed = 4711
	_run.district_id = &"old_market"
	_run.cash = 10000


func _set_all_shares(value: int) -> void:
	for district_id in Turf.CONTESTED:
		_run.turf[district_id] = value


func _move_to_vex() -> void:
	for attempt in 40:
		var location := Roster.rival_location(_run, Calendar.stamp(_run))
		if not location.is_empty():
			_run.district_id = location
			return
		Calendar.advance_phase(_run)
	fail_test("Vex never showed up")


func test_starting_shares() -> void:
	assert_eq(Turf.share(_run, &"old_market"), Turf.STARTING_SHARE)
	assert_eq(Turf.share(_run, &"slums"), 25)
	assert_eq(Turf.holder(_run, &"old_market"), Turf.Holder.NOBODY)
	assert_eq(Turf.holder(_run, &"slums"), Turf.Holder.VEX)
	assert_eq(Turf.holder(_run, &"warehouse_row"), Turf.Holder.NOBODY)
	assert_eq(Turf.held_count(_run), 0)


func test_holders_follow_the_share_thresholds() -> void:
	_run.turf[&"docks"] = Turf.HOLD_SHARE
	_run.turf[&"downtown"] = Turf.VEX_HOLD_SHARE
	assert_eq(Turf.holder(_run, &"docks"), Turf.Holder.PLAYER)
	assert_eq(Turf.holder(_run, &"downtown"), Turf.Holder.VEX)
	assert_eq(Turf.held_count(_run), 1)


func test_sell_factor_depends_on_who_holds_the_district() -> void:
	_run.turf[&"docks"] = 80
	assert_eq(Turf.sell_factor(_run, &"docks"), Turf.HELD_SELL_FACTOR)
	assert_eq(Turf.sell_factor(_run, &"slums"), Turf.VEX_SELL_FACTOR)
	assert_eq(Turf.sell_factor(_run, &"old_market"), 1.0)
	assert_eq(Turf.sell_factor(_run, &"warehouse_row"), 1.0)


func test_sales_gain_a_little_ground() -> void:
	Turf.record_sale(_run, 100)
	assert_eq(Turf.share(_run, &"old_market"), Turf.STARTING_SHARE + 1)
	Turf.record_sale(_run, 1000000)
	assert_eq(Turf.share(_run, &"old_market"), Turf.STARTING_SHARE + 1 + Turf.MAX_SALE_GAIN)


func test_neutral_districts_have_no_turf() -> void:
	_run.district_id = &"warehouse_row"
	Turf.record_sale(_run, 5000)
	assert_true(_run.turf.is_empty())
	assert_false(Turf.can_send_muscle(_run))


func test_shares_stay_between_zero_and_a_hundred() -> void:
	assert_eq(Turf.shift(_run, &"docks", 500), 50)
	assert_eq(Turf.share(_run, &"docks"), 100)
	assert_eq(Turf.shift(_run, &"docks", -500), -100)
	assert_eq(Turf.share(_run, &"docks"), 0)


func test_muscle_costs_cash_and_heat_once_per_phase() -> void:
	var cost := Turf.muscle_cost(_run)
	assert_eq(cost, Turf.MUSCLE_BASE_COST + Turf.STARTING_SHARE * Turf.MUSCLE_COST_PER_SHARE)
	assert_true(Turf.send_muscle(_run))
	assert_eq(_run.cash, 10000 - cost)
	assert_eq(_run.heat, Turf.MUSCLE_HEAT)
	assert_eq(Turf.share(_run, &"old_market"), Turf.STARTING_SHARE + Turf.MUSCLE_GAIN)
	assert_false(Turf.send_muscle(_run), "only once per phase")
	Calendar.advance_phase(_run)
	assert_true(Turf.can_send_muscle(_run))


func test_muscle_needs_the_cash() -> void:
	_run.cash = Turf.muscle_cost(_run) - 1
	assert_false(Turf.send_muscle(_run))
	assert_eq(Turf.share(_run, &"old_market"), Turf.STARTING_SHARE)


func test_vex_pushes_where_she_is() -> void:
	_move_to_vex()
	var before := Turf.share(_run, _run.district_id)
	Turf.vex_pushes(_run)
	assert_eq(Turf.share(_run, _run.district_id), before - Turf.VEX_PUSH_PER_PHASE)


func test_clash_only_where_vex_is_and_does_not_already_hold() -> void:
	_move_to_vex()
	_run.turf[_run.district_id] = 50
	assert_true(Turf.clash_due(_run, 0.0))
	assert_false(Turf.clash_due(_run, 0.99))
	_run.turf[_run.district_id] = Turf.VEX_HOLD_SHARE
	assert_false(Turf.clash_due(_run, 0.0), "no clash on her own turf")
	_run.turf[_run.district_id] = 50
	_run.district_id = &"warehouse_row"
	assert_false(Turf.clash_due(_run, 0.0))


func test_clash_offers_tribute_fight_and_back_off() -> void:
	_run.pending_encounter = Turf.clash(_run)
	var ids := Encounters.choices(_run, _run.pending_encounter).map(func(choice: Encounters.Choice) -> StringName: return choice.id)
	assert_eq(ids, [Turf.TRIBUTE, Turf.FIGHT, Turf.BACK_OFF])
	_run.cash = 0
	assert_false(Encounters.choices(_run, _run.pending_encounter)[0].enabled, "tribute needs cash")


func test_tribute_costs_cash_and_keeps_the_share() -> void:
	_run.pending_encounter = Turf.clash(_run)
	var tribute := Turf.tribute_cost(_run)
	Encounters.resolve(_run, Turf.TRIBUTE, 0.0)
	assert_eq(_run.cash, 10000 - tribute)
	assert_eq(Turf.share(_run, &"old_market"), Turf.STARTING_SHARE)
	assert_false(Encounters.has_pending(_run))


func test_winning_a_fight_gains_ground() -> void:
	_run.pending_encounter = Turf.clash(_run)
	Encounters.resolve(_run, Turf.FIGHT, 0.0)
	assert_eq(Turf.share(_run, &"old_market"), Turf.STARTING_SHARE + Turf.FIGHT_GAIN)
	assert_eq(_run.cash, 10000)


func test_losing_a_fight_costs_ground_and_cash() -> void:
	_run.pending_encounter = Turf.clash(_run)
	Encounters.resolve(_run, Turf.FIGHT, 0.99)
	assert_eq(Turf.share(_run, &"old_market"), Turf.STARTING_SHARE - Turf.FIGHT_LOSS)
	assert_eq(_run.cash, 10000 - floori(10000 * Turf.BEATING_CASH_FRACTION))


func test_backing_off_gives_up_ground() -> void:
	_run.pending_encounter = Turf.clash(_run)
	Encounters.resolve(_run, Turf.BACK_OFF, 0.0)
	assert_eq(Turf.share(_run, &"old_market"), Turf.STARTING_SHARE - Turf.BACK_OFF_LOSS)


func test_taking_every_district_drives_vex_out() -> void:
	_set_all_shares(Turf.HOLD_SHARE)
	_run.turf[&"downtown"] = Turf.HOLD_SHARE - 1
	Turf.shift(_run, &"downtown", 1)
	assert_true(_run.vex_gone)
	assert_eq(_run.cash, 10000 + Turf.VICTORY_REWARD)
	assert_eq(_run.pending_encounter.type, Turf.VICTORY)
	assert_eq(Roster.rival_location(_run, Calendar.stamp(_run)), &"")
	assert_eq(Turf.held_count(_run), Turf.CONTESTED.size())


func test_victory_waits_for_the_pending_encounter() -> void:
	_set_all_shares(Turf.HOLD_SHARE)
	_run.pending_encounter = {"type": Encounters.RAID}
	Turf.check_victory(_run)
	assert_false(_run.vex_gone)
	_run.pending_encounter = {}
	Turf.check_victory(_run)
	assert_true(_run.vex_gone)


func test_turf_freezes_once_vex_is_gone() -> void:
	_run.vex_gone = true
	assert_eq(Turf.shift(_run, &"docks", -30), 0)
	assert_eq(Turf.holder(_run, &"slums"), Turf.Holder.PLAYER)
	assert_false(Turf.can_send_muscle(_run))
	assert_false(Turf.clash_due(_run, 0.0))


func test_turf_survives_a_save() -> void:
	_run.turf[&"docks"] = 72
	_run.muscle_stamp = 5
	_run.vex_gone = true
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(_run.to_dict())))
	assert_eq(Turf.share(restored, &"docks"), 72)
	assert_eq(restored.muscle_stamp, 5)
	assert_true(restored.vex_gone)


func test_sanitize_drops_unknown_districts_and_clamps() -> void:
	var clean := Turf.sanitize({"docks": 140, "warehouse_row": 80, "slums": -5})
	assert_eq(clean, {&"docks": 100, &"slums": 0})
