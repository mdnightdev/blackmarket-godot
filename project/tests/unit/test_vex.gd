extends GutTest

var _run: RunState
var _vex_at: StringName


func before_each() -> void:
	_run = RunState.new()
	_run.price_seed = 4711
	_run.district_id = &"old_market"
	_run.cash = 10000
	_vex_at = _find_vex()


func _find_vex() -> StringName:
	for attempt in 40:
		var location := Roster.rival_location(_run, Calendar.stamp(_run))
		if Turf.is_contested(location):
			return location
		Calendar.advance_phase(_run)
	fail_test("Vex never showed up in a contested district")
	return &""


func _gate() -> Dictionary:
	_run.turf[_vex_at] = 70
	_run.pending_encounter = Vex.gate(_run)
	return _run.pending_encounter


func _ids(encounter: Dictionary) -> Array:
	return Encounters.choices(_run, encounter).map(func(choice: Encounters.Choice) -> StringName: return choice.id)


func test_vex_only_taxes_where_she_holds_more_and_the_player_stands() -> void:
	_run.turf[_vex_at] = 20
	_run.district_id = &"warehouse_row"
	assert_false(Vex.gate_due(_run, 0.0), "the player is somewhere else")
	_run.district_id = _vex_at
	assert_true(Vex.gate_due(_run, 0.0))
	assert_false(Vex.gate_due(_run, 0.99))
	_run.turf[_vex_at] = Turf.STARTING_SHARE
	assert_false(Vex.gate_due(_run, 0.0), "no tax at an even split")
	_run.turf[_vex_at] = Turf.HOLD_SHARE
	assert_eq(Vex.gate_chance(_run), 0.0, "never where the player holds more")


func test_her_tax_comes_more_often_the_stronger_her_hold() -> void:
	_run.district_id = _vex_at
	_run.turf[_vex_at] = 40
	var weak := Vex.gate_chance(_run)
	_run.turf[_vex_at] = 10
	assert_gt(Vex.gate_chance(_run), weak)
	assert_lte(Vex.gate_chance(_run), Vex.MAX_GATE_CHANCE)


func test_no_gate_while_vex_is_hunting_or_gone() -> void:
	_run.district_id = _vex_at
	_run.turf[_vex_at] = 20
	_run.vex_anger = Vex.MAX_ANGER
	assert_false(Vex.gate_due(_run, 0.0))
	_run.vex_anger = 0
	_run.vex_gone = true
	assert_false(Vex.gate_due(_run, 0.0))


func test_gate_offers_bribe_threat_and_ignore() -> void:
	var encounter := _gate()
	assert_eq(encounter.district, String(_vex_at))
	assert_eq(_ids(encounter), [Vex.BRIBE, Vex.THREATEN, Vex.IGNORE])
	assert_false(Encounters.choices(_run, encounter)[1].enabled, "threat needs a trusting family")
	_run.family_standing[&"white_tiger"] = Families.TRUSTED_AT
	assert_true(Encounters.choices(_run, encounter)[1].enabled)


func test_bribe_is_small_and_leaves_turf_alone() -> void:
	var encounter := _gate()
	Encounters.resolve(_run, Vex.BRIBE, 0.0)
	assert_eq(_run.cash, 10000 - int(encounter.bribe))
	assert_eq(int(encounter.bribe), Vex.BRIBE_BASE)
	assert_eq(Turf.share(_run, _vex_at), 70)
	assert_false(Encounters.has_pending(_run))


func test_threat_uses_family_standing_and_calms_vex() -> void:
	_run.family_standing[&"white_tiger"] = Families.TRUSTED_AT + 10
	_run.vex_anger = 2
	_gate()
	Encounters.resolve(_run, Vex.THREATEN, 0.0)
	assert_eq(_run.vex_anger, 1)
	assert_eq(Families.standing(_run, &"white_tiger"), Families.TRUSTED_AT + 10 - Vex.THREAT_STANDING_COST)
	assert_eq(_run.cash, 10000)


func test_ignoring_costs_ground_and_builds_to_a_hunt() -> void:
	for step in Vex.MAX_ANGER:
		_gate()
		Encounters.resolve(_run, Vex.IGNORE, 0.0)
		assert_eq(Turf.share(_run, _vex_at), 70 - Vex.IGNORE_LOSS)
	assert_eq(_run.vex_anger, Vex.MAX_ANGER)
	assert_eq(_run.cash, 10000, "ignoring never costs cash")
	assert_true(Vex.hunt_due(_run, 0.0))
	assert_false(Vex.hunt_due(_run, 0.99))


func test_hunt_fee_is_fixed_and_calms_vex() -> void:
	_run.vex_anger = Vex.MAX_ANGER
	_run.pending_encounter = Vex.hunt(_run)
	assert_eq(_ids(_run.pending_encounter), [Vex.PAY, Vex.FIGHT])
	Encounters.resolve(_run, Vex.PAY, 0.0)
	assert_eq(_run.cash, 10000 - Vex.HUNT_FEE)
	assert_eq(_run.vex_anger, Vex.ANGER_AFTER_PAYING)


func test_winning_the_hunt_fight_gains_ground_and_ends_the_feud() -> void:
	_run.vex_anger = Vex.MAX_ANGER
	_run.pending_encounter = Vex.hunt(_run)
	Encounters.resolve(_run, Vex.FIGHT, 0.0)
	assert_eq(Turf.share(_run, &"old_market"), Turf.STARTING_SHARE + Vex.FIGHT_GAIN)
	assert_eq(_run.vex_anger, 0)
	assert_eq(_run.cash, 10000)


func test_losing_the_hunt_fight_costs_ground_and_heat_but_no_cash() -> void:
	_run.vex_anger = Vex.MAX_ANGER
	_run.pending_encounter = Vex.hunt(_run)
	Encounters.resolve(_run, Vex.FIGHT, 0.99)
	assert_eq(Turf.share(_run, &"old_market"), Turf.STARTING_SHARE - Vex.FIGHT_LOSS)
	assert_eq(_run.heat, Vex.FIGHT_LOSS_HEAT)
	assert_eq(_run.cash, 10000)
	assert_eq(_run.vex_anger, Vex.ANGER_AFTER_BEATING)


func test_hunt_outside_the_turf_war_is_fought_over_the_strongest_district() -> void:
	_run.district_id = &"warehouse_row"
	_run.turf[&"docks"] = 80
	assert_eq(Vex.fight_district(_run), &"docks")


func test_anger_survives_a_save_and_is_clamped() -> void:
	_run.vex_anger = 2
	var data := _run.to_dict()
	assert_eq(RunState.from_dict(JSON.parse_string(JSON.stringify(data))).vex_anger, 2)
	data.vex_anger = 99
	assert_eq(RunState.from_dict(data).vex_anger, Vex.MAX_ANGER)
