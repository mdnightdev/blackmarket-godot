extends GutTest

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	_run.price_seed = 4711
	_run.district_id = &"downtown"
	_run.cash = 10000
	Story.mark(_run, War.VEX_FELL)


func _hold_corners(district_id: StringName, count: int) -> void:
	for corner in Corners.of(district_id):
		Corners.lose(_run, corner.id)
	for corner in Corners.of(district_id).slice(0, count):
		Corners.take(_run, corner.id)


func _hold_turf(gang: GangDef) -> void:
	for district_id in gang.turf:
		Corners.take_all(_run, district_id)


func _set_rank(rank_number: int) -> void:
	_run.street_cred = int(StreetCred.RANKS[rank_number - 1].cred)


func test_every_rival_district_starts_with_the_gang() -> void:
	for district_id in Turf.contested():
		if district_id == Corners.HOME:
			continue
		assert_eq(Turf.share(_run, district_id), 0, String(district_id))
		assert_eq(Turf.holder(_run, district_id), Turf.Holder.GANG, String(district_id))
	assert_eq(Turf.holder(_run, &"golden_mile"), Turf.Holder.NOBODY)
	assert_eq(Turf.held_count(_run), 0)


func test_the_share_is_the_corners_held() -> void:
	_hold_corners(&"docks", 1)
	assert_eq(Turf.share(_run, &"docks"), 25)
	assert_eq(Turf.holder(_run, &"docks"), Turf.Holder.GANG)
	_hold_corners(&"docks", 2)
	assert_eq(Turf.holder(_run, &"docks"), Turf.Holder.NOBODY)
	_hold_corners(&"docks", 3)
	assert_eq(Turf.holder(_run, &"docks"), Turf.Holder.PLAYER)
	assert_eq(Turf.held_count(_run), 1)


func test_sell_factor_depends_on_who_holds_the_district() -> void:
	_hold_corners(&"docks", 3)
	_hold_corners(&"downtown", 2)
	assert_eq(Turf.sell_factor(_run, &"docks"), Turf.HELD_SELL_FACTOR)
	assert_eq(Turf.sell_factor(_run, &"slums"), Turf.GANG_SELL_FACTOR)
	assert_eq(Turf.sell_factor(_run, &"downtown"), 1.0)
	assert_eq(Turf.sell_factor(_run, &"golden_mile"), 1.0)


func test_selling_never_moves_turf() -> void:
	var item := Content.item(&"burner_phones")
	Inventory.add_units(_run, item.id, 10)
	assert_eq(Trade.sell(_run, item, 10, 5000), Trade.Result.OK)
	assert_eq(Turf.share(_run, &"downtown"), 0)


func test_fight_odds_follow_the_share() -> void:
	_hold_corners(&"docks", 2)
	assert_between(Turf.fight_chance(_run, &"docks"), 0.45, 0.65, "an even split is close to a coin flip")
	_hold_corners(&"docks", 4)
	assert_gte(Turf.fight_chance(_run, &"docks"), 0.9, "losing while holding all of it is rare")
	_hold_corners(&"docks", 0)
	assert_lte(Turf.fight_chance(_run, &"docks"), 0.2, "where the gang holds everything it is a long shot")


func test_held_corners_pay_a_daily_cut() -> void:
	assert_eq(Turf.collect_daily_cut(_run), 0)
	_hold_corners(&"docks", 2)
	var expected := Corners.of(&"docks")[0].daily_cut() + Corners.of(&"docks")[1].daily_cut()
	assert_eq(Turf.collect_daily_cut(_run), expected)
	assert_eq(_run.cash, 10000 + expected)


func test_losing_the_hold_loses_its_perks() -> void:
	_hold_corners(&"docks", 3)
	assert_eq(Turf.stop_factor(_run, &"docks"), Turf.HELD_STOP_FACTOR)
	assert_eq(Turf.business_slots(_run, &"docks"), 1)
	_hold_corners(&"docks", 2)
	assert_eq(Turf.stop_factor(_run, &"docks"), 1.0)
	assert_eq(Turf.business_slots(_run, &"docks"), 0)


func test_a_second_business_needs_the_rank() -> void:
	_hold_corners(&"docks", 3)
	assert_eq(Turf.business_slots(_run, &"docks"), 1)
	_set_rank(Turf.SECOND_BUSINESS_RANK)
	assert_eq(Turf.business_slots(_run, &"docks"), 2)
	_set_rank(Turf.SECOND_BUSINESS_RANK - 1)
	assert_eq(Turf.business_slots(_run, &"docks"), 1)


func test_no_muggings_on_held_turf() -> void:
	var mugging: EventDef = Content.events().filter(func(event: EventDef) -> bool: return event.effect == EventDef.Effect.MUGGING)[0]
	assert_false(StreetEvents.prepare(_run, mugging, RandomNumberGenerator.new()).is_empty())
	_hold_corners(&"downtown", 3)
	assert_true(StreetEvents.prepare(_run, mugging, RandomNumberGenerator.new()).is_empty())


func test_taking_every_corner_drives_the_gang_out() -> void:
	var gang := _jackal()
	_hold_turf(gang)
	Corners.lose(_run, Corners.of(gang.turf[-1])[-1].id)
	Turf.check_victory(_run)
	assert_false(Gangs.is_gone(_run, gang), "one corner left")
	Corners.take_all(_run, gang.turf[-1])
	Turf.check_victory(_run)
	assert_true(Gangs.is_gone(_run, gang))
	assert_eq(_run.cash, 10000 + gang.victory_reward)
	assert_eq(_run.pending_encounter.type, Turf.VICTORY)
	assert_eq(Gangs.boss_location(_run, gang, Calendar.stamp(_run)), &"")


func test_vex_needs_old_market_too() -> void:
	for district_id in _vex().turf:
		if district_id != Corners.HOME:
			Corners.take_all(_run, district_id)
	Turf.check_victory(_run)
	assert_false(Gangs.is_gone(_run, _vex()))
	Corners.take_all(_run, Corners.HOME)
	Turf.check_victory(_run)
	assert_true(Gangs.is_gone(_run, _vex()))


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


func test_a_gone_gang_leaves_its_districts_to_the_player() -> void:
	_run.gangs_gone.append(&"vex")
	assert_eq(Turf.holder(_run, &"slums"), Turf.Holder.PLAYER)
	assert_false(Gangs.gate_due(_run, _vex(), 0.0))


func test_old_saves_turn_their_shares_into_corners() -> void:
	var data := _run.to_dict()
	data["turf"] = { "docks": 72, "slums": 95, "downtown": 50, "riverside": 10 }
	data["muscle_stamp"] = 5
	data["gangs_gone"] = ["celeste"]
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(data)))
	assert_eq(Corners.held_count(restored, &"docks"), Corners.MIGRATED_HELD_CORNERS)
	assert_false(Corners.of(&"docks").any(func(corner: CornerDef) -> bool: return corner.stronghold and Corners.holds(restored, corner.id)),
		"the stronghold stays with the gang")
	assert_eq(Corners.held_count(restored, &"slums"), 4)
	assert_eq(Corners.held_count(restored, &"downtown"), 0)
	assert_eq(Corners.held_count(restored, &"riverside"), 0)
	assert_eq(Corners.held_count(restored, &"the_heights"), 4, "Celeste was already gone")
	assert_false(restored.to_dict().has("turf"))


func _vex() -> GangDef:
	return Content.gang(&"vex")


func _jackal() -> GangDef:
	return Content.gang(&"jackal")
