extends GutTest

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	_run.price_seed = 4711
	_run.district_id = &"old_market"
	_run.cash = 10000


func _set_all_shares(value: int) -> void:
	for district_id in Turf.contested():
		_run.turf[district_id] = value


func _set_rank(rank_number: int) -> void:
	_run.street_cred = int(StreetCred.RANKS[rank_number - 1].cred)


func _hold_at_level(district_id: StringName, bought: int) -> void:
	_run.turf[district_id] = Turf.HOLD_SHARE
	_run.turf_levels[district_id] = bought


func _move_to_vex() -> void:
	for attempt in 40:
		var location := Gangs.boss_location(_run, _vex(), Calendar.stamp(_run))
		if not location.is_empty():
			_run.district_id = location
			return
		Calendar.advance_phase(_run)
	fail_test("Vex never showed up")


func test_starting_shares() -> void:
	assert_eq(Turf.share(_run, &"old_market"), Turf.STARTING_SHARE)
	assert_eq(Turf.share(_run, &"slums"), 25)
	assert_eq(Turf.holder(_run, &"old_market"), Turf.Holder.NOBODY)
	assert_eq(Turf.holder(_run, &"slums"), Turf.Holder.GANG)
	assert_eq(Turf.holder(_run, &"warehouse_row"), Turf.Holder.NOBODY)
	assert_eq(Turf.held_count(_run), 0)


func test_holders_follow_the_share_thresholds() -> void:
	_run.turf[&"docks"] = Turf.HOLD_SHARE
	_run.turf[&"downtown"] = Turf.GANG_HOLD_SHARE
	assert_eq(Turf.holder(_run, &"docks"), Turf.Holder.PLAYER)
	assert_eq(Turf.holder(_run, &"downtown"), Turf.Holder.GANG)
	assert_eq(Turf.held_count(_run), 1)


func test_sell_factor_depends_on_who_holds_the_district() -> void:
	_run.turf[&"docks"] = 80
	assert_eq(Turf.sell_factor(_run, &"docks"), Turf.HELD_SELL_FACTOR)
	assert_eq(Turf.sell_factor(_run, &"slums"), Turf.GANG_SELL_FACTOR)
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
	_run.turf[_run.district_id] = Turf.STARTING_SHARE
	var push := Turf.gang_push(_run, _vex(), _run.district_id)
	assert_gt(push, 0)
	Turf.gangs_push(_run)
	assert_eq(Turf.share(_run, _run.district_id), Turf.STARTING_SHARE - push)


func test_vex_barely_pushes_where_the_player_dominates() -> void:
	_run.turf[&"docks"] = 10
	var strong := Turf.gang_push(_run, _vex(), &"docks")
	_run.turf[&"docks"] = 90
	assert_eq(Turf.gang_push(_run, _vex(), &"docks"), 0)
	assert_gt(strong, Turf.gang_push(_run, _vex(), &"docks"))


func test_fight_odds_follow_the_share() -> void:
	_run.turf[&"docks"] = Turf.STARTING_SHARE
	var even := Turf.fight_chance(_run, &"docks")
	assert_between(even, 0.45, 0.65, "an even split is close to a coin flip")
	_run.turf[&"docks"] = 90
	assert_gte(Turf.fight_chance(_run, &"docks"), 0.9, "losing while holding most of it is rare")
	_run.turf[&"docks"] = 10
	assert_lte(Turf.fight_chance(_run, &"docks"), 0.2, "her stronghold is a long shot")
	_run.turf[&"docks"] = 100
	assert_lte(Turf.fight_chance(_run, &"docks"), Odds.MAX_CHANCE)


func test_held_districts_pay_a_daily_cut() -> void:
	assert_eq(Turf.collect_daily_cut(_run), 0)
	_run.turf[&"docks"] = Turf.HOLD_SHARE
	_run.turf[&"old_market"] = 80
	assert_eq(Turf.collect_daily_cut(_run), 2 * Turf.DAILY_CUT)
	assert_eq(_run.cash, 10000 + 2 * Turf.DAILY_CUT)


func test_daily_cut_grows_with_the_level() -> void:
	_hold_at_level(&"docks", 1)
	_hold_at_level(&"old_market", 3)
	assert_eq(Turf.district_cut(_run, &"docks"), Turf.DAILY_CUT)
	assert_eq(Turf.district_cut(_run, &"old_market"), Turf.DAILY_CUT + 2 * Turf.CUT_PER_LEVEL)
	assert_eq(Turf.district_cut(_run, &"slums"), 0)
	var expected := 2 * Turf.DAILY_CUT + 2 * Turf.CUT_PER_LEVEL
	assert_eq(Turf.collect_daily_cut(_run), expected)
	assert_eq(_run.cash, 10000 + expected)


func test_level_counts_only_while_held() -> void:
	assert_eq(Turf.level(_run, &"docks"), 0)
	assert_eq(Turf.bought_level(_run, &"docks"), 1)
	_run.turf[&"docks"] = Turf.HOLD_SHARE
	assert_eq(Turf.level(_run, &"docks"), 1)
	assert_eq(Turf.level(_run, &"warehouse_row"), 0)


func test_levels_pause_when_the_hold_is_lost() -> void:
	_hold_at_level(&"docks", 4)
	assert_eq(Turf.level(_run, &"docks"), 4)
	_run.turf[&"docks"] = 50
	assert_eq(Turf.level(_run, &"docks"), 0)
	assert_eq(Turf.bought_level(_run, &"docks"), 4)
	assert_eq(Turf.district_cut(_run, &"docks"), 0)
	assert_eq(Turf.stop_factor(_run, &"docks"), 1.0)
	assert_eq(Turf.business_slots(_run, &"docks"), 0)
	assert_eq(Turf.check_level_up(_run, &"docks"), Turf.LevelResult.NOT_HELD)
	_run.turf[&"docks"] = Turf.HOLD_SHARE
	assert_eq(Turf.level(_run, &"docks"), 4)


func test_vex_leaving_hands_over_every_level() -> void:
	_run.gangs_gone.append(&"vex")
	_run.turf_levels[&"slums"] = 2
	assert_eq(Turf.level(_run, &"slums"), 2)
	assert_eq(Turf.level(_run, &"downtown"), 1)


func test_stop_factor_drops_with_the_level_down_to_the_floor() -> void:
	_hold_at_level(&"docks", 1)
	assert_eq(Turf.stop_factor(_run, &"docks"), Turf.HELD_STOP_FACTOR)
	_run.turf_levels[&"docks"] = 3
	assert_almost_eq(Turf.stop_factor(_run, &"docks"), 0.6, 0.0001)
	_run.turf_levels[&"docks"] = Turf.MAX_LEVEL
	assert_almost_eq(Turf.stop_factor(_run, &"docks"), Turf.MIN_HELD_STOP_FACTOR, 0.0001)
	_run.turf_levels[&"docks"] = 99
	assert_almost_eq(Turf.stop_factor(_run, &"docks"), Turf.MIN_HELD_STOP_FACTOR, 0.0001)
	assert_eq(Turf.stop_factor(_run, &"slums"), 1.0)


func test_business_slots_open_at_levels_two_and_four() -> void:
	var expected := [0, 1, 1, 2, 2]
	for bought in Turf.MAX_LEVEL:
		_hold_at_level(&"docks", bought + 1)
		assert_eq(Turf.business_slots(_run, &"docks"), expected[bought], "level %d" % (bought + 1))


func test_power_sums_levels_in_effect() -> void:
	assert_eq(Turf.power(_run), 0)
	_hold_at_level(&"docks", 2)
	_hold_at_level(&"old_market", 1)
	_run.turf_levels[&"downtown"] = 5
	assert_eq(Turf.power(_run), 3)
	assert_eq(Turf.max_power(), Turf.contested().size() * Turf.MAX_LEVEL)
	_run.gangs_gone.append(&"vex")
	for district_id in Turf.contested():
		_run.turf_levels[district_id] = Turf.MAX_LEVEL
	assert_eq(Turf.power(_run), Turf.max_power())


func test_level_up_costs_climb_with_rank_gates() -> void:
	_hold_at_level(&"old_market", 1)
	assert_eq(Turf.next_level_cost(_run, &"old_market"), 2000)
	assert_eq(Turf.next_level_rank(_run, &"old_market"), 3)
	assert_eq(Turf.level_up(_run, &"old_market"), Turf.LevelResult.RANK_TOO_LOW)
	assert_eq(_run.cash, 10000)
	_set_rank(3)
	assert_eq(Turf.level_up(_run, &"old_market"), Turf.LevelResult.OK)
	assert_eq(_run.cash, 8000)
	assert_eq(Turf.level(_run, &"old_market"), 2)
	assert_eq(Turf.next_level_cost(_run, &"old_market"), 5000)
	assert_eq(Turf.next_level_rank(_run, &"old_market"), 5)
	assert_eq(Turf.check_level_up(_run, &"old_market"), Turf.LevelResult.RANK_TOO_LOW)
	_run.turf_levels[&"old_market"] = 3
	assert_eq(Turf.next_level_cost(_run, &"old_market"), 12000)
	assert_eq(Turf.next_level_rank(_run, &"old_market"), 7)
	_run.turf_levels[&"old_market"] = 4
	assert_eq(Turf.next_level_cost(_run, &"old_market"), 25000)
	assert_eq(Turf.next_level_rank(_run, &"old_market"), 9)


func test_level_up_needs_a_held_contested_district() -> void:
	_set_rank(StreetCred.max_rank())
	assert_eq(Turf.check_level_up(_run, &"warehouse_row"), Turf.LevelResult.NOT_CONTESTED)
	assert_eq(Turf.next_level_cost(_run, &"warehouse_row"), -1)
	assert_eq(Turf.check_level_up(_run, &"docks"), Turf.LevelResult.NOT_HELD)


func test_level_up_needs_the_cash() -> void:
	_set_rank(3)
	_hold_at_level(&"docks", 1)
	_run.cash = 1999
	assert_eq(Turf.level_up(_run, &"docks"), Turf.LevelResult.NOT_ENOUGH_CASH)
	assert_eq(_run.cash, 1999)
	assert_eq(Turf.bought_level(_run, &"docks"), 1)


func test_level_up_stops_at_max_level() -> void:
	_set_rank(StreetCred.max_rank())
	_hold_at_level(&"docks", Turf.MAX_LEVEL)
	assert_eq(Turf.check_level_up(_run, &"docks"), Turf.LevelResult.MAX_LEVEL)
	assert_eq(Turf.next_level_cost(_run, &"docks"), -1)
	assert_eq(Turf.next_level_rank(_run, &"docks"), -1)


func test_top_levels_in_a_family_home_need_its_trust() -> void:
	_set_rank(StreetCred.max_rank())
	_run.cash = 100000
	_hold_at_level(&"docks", 2)
	assert_eq(Turf.home_family(&"docks").id, &"white_tiger")
	assert_eq(Turf.level_up(_run, &"docks"), Turf.LevelResult.OK, "level 3 needs no trust")
	assert_eq(Turf.level_up(_run, &"docks"), Turf.LevelResult.NEEDS_TRUST)
	_run.family_standing[&"white_tiger"] = Families.TRUSTED_AT
	assert_eq(Turf.level_up(_run, &"docks"), Turf.LevelResult.OK)
	_run.family_standing[&"white_tiger"] = Families.TRUSTED_AT - 1
	assert_eq(Turf.check_level_up(_run, &"docks"), Turf.LevelResult.NEEDS_TRUST)
	_run.family_standing[&"white_tiger"] = Families.FAMILY_AT
	assert_eq(Turf.level_up(_run, &"docks"), Turf.LevelResult.OK)
	assert_eq(Turf.level(_run, &"docks"), Turf.MAX_LEVEL)
	assert_eq(_run.cash, 100000 - 5000 - 12000 - 25000)


func test_no_muggings_on_held_turf() -> void:
	var mugging: EventDef = Content.events().filter(func(event: EventDef) -> bool: return event.effect == EventDef.Effect.MUGGING)[0]
	assert_false(StreetEvents.prepare(_run, mugging, RandomNumberGenerator.new()).is_empty())
	_run.turf[&"old_market"] = Turf.HOLD_SHARE
	assert_true(StreetEvents.prepare(_run, mugging, RandomNumberGenerator.new()).is_empty())


func test_taking_every_district_drives_vex_out() -> void:
	_set_all_shares(Turf.HOLD_SHARE)
	_run.turf[&"downtown"] = Turf.HOLD_SHARE - 1
	Turf.shift(_run, &"downtown", 1)
	assert_true(Gangs.is_gone(_run, _vex()))
	assert_eq(_run.cash, 10000 + _vex().victory_reward)
	assert_eq(_run.pending_encounter.type, Turf.VICTORY)
	assert_eq(Gangs.boss_location(_run, _vex(), Calendar.stamp(_run)), &"")
	assert_eq(Turf.held_count(_run), Turf.contested().size())


func test_victory_ends_with_a_summary_of_what_was_won() -> void:
	_set_all_shares(Turf.HOLD_SHARE)
	Turf.check_victory(_run)
	var summary := Encounters.resolve(_run, Encounters.CONTINUE, 0.0)
	assert_string_contains(summary, Format.money(_vex().victory_reward))
	assert_string_contains(summary, str(StreetCred.GANG_BEATEN))
	assert_true(_run.pending_encounter.is_empty())


func test_victory_waits_for_the_pending_encounter() -> void:
	_set_all_shares(Turf.HOLD_SHARE)
	_run.pending_encounter = {"type": Encounters.RAID}
	Turf.check_victory(_run)
	assert_false(Gangs.is_gone(_run, _vex()))
	_run.pending_encounter = {}
	Turf.check_victory(_run)
	assert_true(Gangs.is_gone(_run, _vex()))


func test_turf_freezes_once_vex_is_gone() -> void:
	_run.gangs_gone.append(&"vex")
	assert_eq(Turf.shift(_run, &"docks", -30), 0)
	assert_eq(Turf.holder(_run, &"slums"), Turf.Holder.PLAYER)
	assert_false(Turf.can_send_muscle(_run))
	assert_false(Gangs.gate_due(_run, _vex(), 0.0))


func test_turf_survives_a_save() -> void:
	_run.turf[&"docks"] = 72
	_run.muscle_stamp = 5
	_run.gangs_gone.append(&"vex")
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(_run.to_dict())))
	assert_eq(Turf.share(restored, &"docks"), 72)
	assert_eq(restored.muscle_stamp, 5)
	assert_true(Gangs.is_gone(restored, _vex()))


func test_turf_levels_survive_a_save() -> void:
	_run.turf_levels[&"docks"] = 3
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(_run.to_dict())))
	assert_eq(Turf.bought_level(restored, &"docks"), 3)


func test_sanitize_drops_unknown_districts_and_clamps() -> void:
	var clean := Turf.sanitize({"docks": 140, "warehouse_row": 80, "slums": -5})
	assert_eq(clean, {&"docks": 100, &"slums": 0})


func _vex() -> GangDef:
	return Content.gang(&"vex")
