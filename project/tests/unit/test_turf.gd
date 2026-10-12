extends GutTest

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	_run.price_seed = 4711
	_run.district_id = &"downtown"
	_run.cash = 10000
	Story.mark(_run, War.VEX_FELL)


func _hold_turf(gang: GangDef) -> void:
	for district_id in gang.turf:
		_run.turf[district_id] = Turf.HOLD_SHARE


func _set_rank(rank_number: int) -> void:
	_run.street_cred = int(StreetCred.RANKS[rank_number - 1].cred)


func _hold(district_id: StringName) -> void:
	_run.turf[district_id] = Turf.HOLD_SHARE


func _move_to_vex() -> void:
	for attempt in 40:
		var location := Gangs.boss_location(_run, _vex(), Calendar.stamp(_run))
		if not location.is_empty():
			_run.district_id = location
			return
		Calendar.advance_phase(_run)
	fail_test("Vex never showed up")


func test_starting_shares() -> void:
	assert_eq(Turf.share(_run, &"downtown"), Turf.STARTING_SHARE)
	assert_eq(Turf.share(_run, &"slums"), 25)
	assert_eq(Turf.holder(_run, &"downtown"), Turf.Holder.NOBODY)
	assert_eq(Turf.holder(_run, &"slums"), Turf.Holder.GANG)
	assert_eq(Turf.holder(_run, &"golden_mile"), Turf.Holder.NOBODY)
	assert_eq(Turf.held_count(_run), 0)


func test_holders_follow_the_share_thresholds() -> void:
	_run.turf[&"docks"] = Turf.HOLD_SHARE
	_run.turf[&"north_port"] = Turf.GANG_HOLD_SHARE
	assert_eq(Turf.holder(_run, &"docks"), Turf.Holder.PLAYER)
	assert_eq(Turf.holder(_run, &"north_port"), Turf.Holder.GANG)
	assert_eq(Turf.held_count(_run), 1)


func test_sell_factor_depends_on_who_holds_the_district() -> void:
	_run.turf[&"docks"] = 80
	assert_eq(Turf.sell_factor(_run, &"docks"), Turf.HELD_SELL_FACTOR)
	assert_eq(Turf.sell_factor(_run, &"slums"), Turf.GANG_SELL_FACTOR)
	assert_eq(Turf.sell_factor(_run, &"downtown"), 1.0)
	assert_eq(Turf.sell_factor(_run, &"golden_mile"), 1.0)


func test_sales_gain_a_little_ground() -> void:
	Turf.record_sale(_run, 100)
	assert_eq(Turf.share(_run, &"downtown"), Turf.STARTING_SHARE + 1)
	Turf.record_sale(_run, 1000000)
	assert_eq(Turf.share(_run, &"downtown"), Turf.STARTING_SHARE + 1 + Turf.MAX_SALE_GAIN)


func test_neutral_districts_have_no_turf() -> void:
	_run.district_id = &"golden_mile"
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
	assert_eq(Turf.share(_run, &"downtown"), Turf.STARTING_SHARE + Turf.MUSCLE_GAIN)
	assert_false(Turf.send_muscle(_run), "only once per phase")
	Calendar.advance_phase(_run)
	assert_true(Turf.can_send_muscle(_run))


func test_muscle_needs_the_cash() -> void:
	_run.cash = Turf.muscle_cost(_run) - 1
	assert_false(Turf.send_muscle(_run))
	assert_eq(Turf.share(_run, &"downtown"), Turf.STARTING_SHARE)


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
	_run.turf[&"downtown"] = 80
	assert_eq(Turf.collect_daily_cut(_run), 2 * Turf.DAILY_CUT)
	assert_eq(_run.cash, 10000 + 2 * Turf.DAILY_CUT)


func test_each_held_district_pays_the_same_cut() -> void:
	_hold(&"docks")
	_hold(&"downtown")
	assert_eq(Turf.district_cut(_run, &"docks"), Turf.DAILY_CUT)
	assert_eq(Turf.district_cut(_run, &"slums"), 0)
	assert_eq(Turf.collect_daily_cut(_run), 2 * Turf.DAILY_CUT)
	assert_eq(_run.cash, 10000 + 2 * Turf.DAILY_CUT)


func test_losing_the_hold_loses_its_perks() -> void:
	_hold(&"docks")
	assert_eq(Turf.stop_factor(_run, &"docks"), Turf.HELD_STOP_FACTOR)
	assert_eq(Turf.business_slots(_run, &"docks"), 1)
	_run.turf[&"docks"] = 50
	assert_eq(Turf.district_cut(_run, &"docks"), 0)
	assert_eq(Turf.stop_factor(_run, &"docks"), 1.0)
	assert_eq(Turf.business_slots(_run, &"docks"), 0)


func test_a_second_business_needs_the_rank() -> void:
	_hold(&"docks")
	assert_eq(Turf.business_slots(_run, &"docks"), 1)
	_set_rank(Turf.SECOND_BUSINESS_RANK)
	assert_eq(Turf.business_slots(_run, &"docks"), 2)
	_set_rank(Turf.SECOND_BUSINESS_RANK - 1)
	assert_eq(Turf.business_slots(_run, &"docks"), 1)


func test_no_muggings_on_held_turf() -> void:
	var mugging: EventDef = Content.events().filter(func(event: EventDef) -> bool: return event.effect == EventDef.Effect.MUGGING)[0]
	assert_false(StreetEvents.prepare(_run, mugging, RandomNumberGenerator.new()).is_empty())
	_run.turf[&"downtown"] = Turf.HOLD_SHARE
	assert_true(StreetEvents.prepare(_run, mugging, RandomNumberGenerator.new()).is_empty())


func test_taking_every_district_drives_the_gang_out() -> void:
	var gang := _jackal()
	_hold_turf(gang)
	_run.turf[gang.turf[-1]] = Turf.HOLD_SHARE - 1
	Turf.shift(_run, gang.turf[-1], 1)
	assert_true(Gangs.is_gone(_run, gang))
	assert_eq(_run.cash, 10000 + gang.victory_reward)
	assert_eq(_run.pending_encounter.type, Turf.VICTORY)
	assert_eq(Gangs.boss_location(_run, gang, Calendar.stamp(_run)), &"")


func test_vex_is_only_beaten_in_the_war_for_her_corners() -> void:
	_hold_turf(_vex())
	Turf.check_victory(_run)
	assert_false(Gangs.is_gone(_run, _vex()))


func test_victory_ends_with_a_summary_of_what_was_won() -> void:
	_hold_turf(_jackal())
	Turf.check_victory(_run)
	var summary := Encounters.resolve(_run, Encounters.CONTINUE, 0.0)
	assert_string_contains(summary, Format.money(_jackal().victory_reward))
	assert_string_contains(summary, str(StreetCred.GANG_BEATEN))
	assert_true(_run.pending_encounter.is_empty())


func test_victory_waits_for_the_pending_encounter() -> void:
	_hold_turf(_jackal())
	_run.pending_encounter = {"type": Encounters.RAID}
	Turf.check_victory(_run)
	assert_false(Gangs.is_gone(_run, _jackal()))
	_run.pending_encounter = {}
	Turf.check_victory(_run)
	assert_true(Gangs.is_gone(_run, _jackal()))


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


func test_sanitize_drops_unknown_districts_and_clamps() -> void:
	var clean := Turf.sanitize({"docks": 140, "golden_mile": 80, "slums": -5})
	assert_eq(clean, {&"docks": 100, &"slums": 0})


func _vex() -> GangDef:
	return Content.gang(&"vex")


func _jackal() -> GangDef:
	return Content.gang(&"jackal")
