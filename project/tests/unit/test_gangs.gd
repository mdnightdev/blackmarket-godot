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
		var location := Gangs.boss_location(_run, _vex(), Calendar.stamp(_run))
		if Turf.is_contested(location):
			return location
		Calendar.advance_phase(_run)
	fail_test("Vex never showed up in a contested district")
	return &""


func _gate() -> Dictionary:
	_run.turf[_vex_at] = 70
	_run.pending_encounter = Gangs.gate(_run, _vex())
	return _run.pending_encounter


func _ids(encounter: Dictionary) -> Array:
	return Encounters.choices(_run, encounter).map(func(choice: Encounters.Choice) -> StringName: return choice.id)


func test_vex_only_taxes_where_she_holds_more_and_the_player_stands() -> void:
	_run.turf[_vex_at] = 20
	_run.district_id = &"warehouse_row"
	assert_false(Gangs.gate_due(_run, _vex(), 0.0), "the player is somewhere else")
	_run.district_id = _vex_at
	assert_true(Gangs.gate_due(_run, _vex(), 0.0))
	assert_false(Gangs.gate_due(_run, _vex(), 0.99))
	_run.turf[_vex_at] = Turf.STARTING_SHARE
	assert_false(Gangs.gate_due(_run, _vex(), 0.0), "no tax at an even split")
	_run.turf[_vex_at] = Turf.HOLD_SHARE
	assert_eq(Gangs.gate_chance(_run, _vex()), 0.0, "never where the player holds more")


func test_her_tax_comes_more_often_the_stronger_her_hold() -> void:
	_run.district_id = _vex_at
	_run.turf[_vex_at] = 40
	var weak := Gangs.gate_chance(_run, _vex())
	_run.turf[_vex_at] = 10
	assert_gt(Gangs.gate_chance(_run, _vex()), weak)
	assert_lte(Gangs.gate_chance(_run, _vex()), _vex().max_gate_chance)


func test_no_gate_while_vex_is_hunting_or_gone() -> void:
	_run.district_id = _vex_at
	_run.turf[_vex_at] = 20
	Gangs.set_anger(_run, _vex(), Gangs.MAX_ANGER)
	assert_false(Gangs.gate_due(_run, _vex(), 0.0))
	Gangs.set_anger(_run, _vex(), 0)
	_run.gangs_gone.append(&"vex")
	assert_false(Gangs.gate_due(_run, _vex(), 0.0))


func test_gate_offers_bribe_threat_and_ignore() -> void:
	var encounter := _gate()
	assert_eq(encounter.district, String(_vex_at))
	assert_eq(_ids(encounter), [Gangs.BRIBE, Gangs.THREATEN, Gangs.IGNORE])
	assert_false(Encounters.choices(_run, encounter)[1].enabled, "threat needs a trusting family")
	_run.family_standing[&"white_tiger"] = Families.TRUSTED_AT
	assert_true(Encounters.choices(_run, encounter)[1].enabled)


func test_bribe_is_small_and_leaves_turf_alone() -> void:
	var encounter := _gate()
	Encounters.resolve(_run, Gangs.BRIBE, 0.0)
	assert_eq(_run.cash, 10000 - int(encounter.bribe))
	assert_eq(int(encounter.bribe), _vex().bribe_base)
	assert_eq(Turf.share(_run, _vex_at), 70)
	assert_false(Encounters.has_pending(_run))


func test_threat_uses_family_standing_and_calms_vex() -> void:
	_run.family_standing[&"white_tiger"] = Families.TRUSTED_AT + 10
	Gangs.set_anger(_run, _vex(), 2)
	_gate()
	Encounters.resolve(_run, Gangs.THREATEN, 0.0)
	assert_eq(Gangs.anger(_run, _vex()), 1)
	assert_eq(Families.standing(_run, &"white_tiger"), Families.TRUSTED_AT + 10 - Gangs.THREAT_STANDING_COST)
	assert_eq(_run.cash, 10000)


func test_ignoring_costs_ground_and_builds_to_a_hunt() -> void:
	for step in Gangs.MAX_ANGER:
		_gate()
		Encounters.resolve(_run, Gangs.IGNORE, 0.0)
		assert_eq(Turf.share(_run, _vex_at), 70 - Gangs.IGNORE_LOSS)
	assert_eq(Gangs.anger(_run, _vex()), Gangs.MAX_ANGER)
	assert_eq(_run.cash, 10000, "ignoring never costs cash")
	assert_true(Gangs.hunt_due(_run, _vex(), 0.0))
	assert_false(Gangs.hunt_due(_run, _vex(), 0.99))


func test_hunt_fee_is_fixed_and_calms_vex() -> void:
	Gangs.set_anger(_run, _vex(), Gangs.MAX_ANGER)
	_run.pending_encounter = Gangs.hunt(_run, _vex())
	assert_eq(_ids(_run.pending_encounter), [Gangs.PAY, Gangs.FIGHT])
	Encounters.resolve(_run, Gangs.PAY, 0.0)
	assert_eq(_run.cash, 10000 - _vex().hunt_fee)
	assert_eq(Gangs.anger(_run, _vex()), Gangs.ANGER_AFTER_PAYING)


func test_winning_the_hunt_fight_gains_ground_and_ends_the_feud() -> void:
	Gangs.set_anger(_run, _vex(), Gangs.MAX_ANGER)
	_run.pending_encounter = Gangs.hunt(_run, _vex())
	Encounters.resolve(_run, Gangs.FIGHT, 0.0)
	assert_eq(Turf.share(_run, &"old_market"), Turf.STARTING_SHARE + Gangs.FIGHT_GAIN)
	assert_eq(Gangs.anger(_run, _vex()), 0)
	assert_eq(_run.cash, 10000)


func test_losing_the_hunt_fight_costs_ground_and_heat_but_no_cash() -> void:
	Gangs.set_anger(_run, _vex(), Gangs.MAX_ANGER)
	_run.pending_encounter = Gangs.hunt(_run, _vex())
	Encounters.resolve(_run, Gangs.FIGHT, 0.99)
	assert_eq(Turf.share(_run, &"old_market"), Turf.STARTING_SHARE - Gangs.FIGHT_LOSS)
	assert_eq(_run.heat, Gangs.FIGHT_LOSS_HEAT)
	assert_eq(_run.cash, 10000)
	assert_eq(Gangs.anger(_run, _vex()), Gangs.ANGER_AFTER_BEATING)


func test_hunt_outside_the_turf_war_is_fought_over_the_strongest_district() -> void:
	_run.district_id = &"warehouse_row"
	_run.turf[&"docks"] = 80
	assert_eq(Gangs.fight_district(_run, _vex()), &"docks")


func test_anger_survives_a_save_and_is_clamped() -> void:
	Gangs.set_anger(_run, _vex(), 2)
	var data := _run.to_dict()
	assert_eq(Gangs.anger(RunState.from_dict(JSON.parse_string(JSON.stringify(data))), _vex()), 2)
	data.gang_anger = { "vex": 99 }
	assert_eq(Gangs.anger(RunState.from_dict(data), _vex()), Gangs.MAX_ANGER)


func _vex() -> GangDef:
	return Content.gang(&"vex")


func test_old_saves_keep_vex_anger_exile_and_pending_tax() -> void:
	var data := _run.to_dict()
	data.erase("gang_anger")
	data.erase("gangs_gone")
	data["vex_anger"] = 2
	data["vex_gone"] = true
	data["pending_encounter"] = { "type": "vex_gate", "district": "slums", "bribe": 300 }
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(data)))
	assert_eq(Gangs.anger(restored, _vex()), 2)
	assert_true(Gangs.is_gone(restored, _vex()))
	assert_eq(restored.pending_encounter.type, Gangs.GATE)
	assert_eq(Gangs.of_encounter(restored.pending_encounter), _vex())


func test_driving_a_gang_out_survives_a_save() -> void:
	_run.gangs_gone.append(&"vex")
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(_run.to_dict())))
	assert_true(Gangs.is_gone(restored, _vex()))


func test_every_gang_has_a_boss_and_its_own_turf() -> void:
	var claimed: Array[StringName] = []
	for gang in Content.gangs():
		var boss := Content.character(gang.boss)
		assert_not_null(boss, "%s boss" % gang.id)
		assert_eq(boss.role, CharacterDef.Role.RIVAL, "%s boss role" % gang.id)
		assert_false(gang.turf.is_empty(), "%s turf" % gang.id)
		for district_id in gang.turf:
			assert_not_null(Content.district(district_id), "%s turf %s" % [gang.id, district_id])
			assert_false(claimed.has(district_id), "%s is claimed twice" % district_id)
			claimed.append(district_id)
		for district_id: StringName in gang.strongholds:
			assert_true(gang.turf.has(district_id), "%s stronghold %s" % [gang.id, district_id])
		assert_string_contains(gang.gate_line, "%s")
		assert_string_contains(gang.victory_line, "%s")
