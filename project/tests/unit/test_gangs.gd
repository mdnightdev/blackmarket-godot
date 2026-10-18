extends GutTest

var _run: RunState
var _baby_at: StringName


func before_each() -> void:
	_run = RunState.new()
	_run.price_seed = 4711
	_run.district_id = &"docks"
	_run.cash = 10000
	Story.mark(_run, War.VEX_FELL)
	_baby_at = _find_baby()


func _find_baby() -> StringName:
	for attempt in 40:
		var location := Gangs.boss_location(_run, _baby(), Calendar.stamp(_run))
		if Turf.is_contested(location):
			return location
		Calendar.advance_phase(_run)
	fail_test("Baby never showed up in a contested district")
	return &""


func _hold_corners(district_id: StringName, count: int) -> void:
	for corner in Corners.of(district_id):
		Corners.lose(_run, corner.id)
	for corner in Corners.of(district_id).slice(0, count):
		Corners.take(_run, corner.id)


func _gate() -> Dictionary:
	_hold_corners(_baby_at, 3)
	_run.pending_encounter = Gangs.gate(_run, _baby())
	return _run.pending_encounter


func _ids(encounter: Dictionary) -> Array:
	return Encounters.choices(_run, encounter).map(func(choice: Encounters.Choice) -> StringName: return choice.id)


func test_vex_only_taxes_where_she_holds_more_and_the_player_stands() -> void:
	_hold_corners(_baby_at, 1)
	_run.district_id = &"golden_mile"
	assert_false(Gangs.gate_due(_run, _baby(), 0.0), "the player is somewhere else")
	_run.district_id = _baby_at
	assert_true(Gangs.gate_due(_run, _baby(), 0.0))
	assert_false(Gangs.gate_due(_run, _baby(), 0.99))
	_hold_corners(_baby_at, 2)
	assert_false(Gangs.gate_due(_run, _baby(), 0.0), "no tax at an even split")
	_hold_corners(_baby_at, 3)
	assert_eq(Gangs.gate_chance(_run, _baby()), 0.0, "never where the player holds more")


func test_her_tax_comes_more_often_the_stronger_her_hold() -> void:
	_run.district_id = _baby_at
	_hold_corners(_baby_at, 1)
	var weak := Gangs.gate_chance(_run, _baby())
	_hold_corners(_baby_at, 0)
	assert_gt(Gangs.gate_chance(_run, _baby()), weak)
	assert_lte(Gangs.gate_chance(_run, _baby()), _baby().max_gate_chance)


func test_no_gate_while_vex_is_hunting_or_gone() -> void:
	_run.district_id = _baby_at
	_hold_corners(_baby_at, 1)
	Gangs.set_anger(_run, _baby(), Gangs.MAX_ANGER)
	assert_false(Gangs.gate_due(_run, _baby(), 0.0))
	Gangs.set_anger(_run, _baby(), 0)
	_run.gangs_gone.append(&"baby")
	assert_false(Gangs.gate_due(_run, _baby(), 0.0))


func test_gate_offers_bribe_threat_and_ignore() -> void:
	var encounter := _gate()
	assert_eq(encounter.district, String(_baby_at))
	assert_eq(_ids(encounter), [Gangs.BRIBE, Gangs.THREATEN, Gangs.IGNORE])
	assert_false(Encounters.choices(_run, encounter)[1].enabled, "threat needs a trusting family")
	_run.family_standing[&"white_tiger"] = Families.TRUSTED_AT
	assert_true(Encounters.choices(_run, encounter)[1].enabled)


func test_bribe_is_small_and_leaves_turf_alone() -> void:
	var encounter := _gate()
	Encounters.resolve(_run, Gangs.BRIBE, 0.0)
	assert_eq(_run.cash, 10000 - int(encounter.bribe))
	assert_eq(int(encounter.bribe), _baby().bribe_base)
	assert_eq(Turf.share(_run, _baby_at), 75)
	assert_false(Encounters.has_pending(_run))


func test_threat_uses_family_standing_and_calms_vex() -> void:
	_run.family_standing[&"white_tiger"] = Families.TRUSTED_AT + 10
	Gangs.set_anger(_run, _baby(), 2)
	_gate()
	Encounters.resolve(_run, Gangs.THREATEN, 0.0)
	assert_eq(Gangs.anger(_run, _baby()), 1)
	assert_eq(Families.standing(_run, &"white_tiger"), Families.TRUSTED_AT + 10 - Gangs.THREAT_STANDING_COST)
	assert_eq(_run.cash, 10000)


func test_ignoring_builds_to_a_hunt_but_never_moves_turf() -> void:
	for step in Gangs.MAX_ANGER:
		_gate()
		Encounters.resolve(_run, Gangs.IGNORE, 0.0)
		assert_eq(Turf.share(_run, _baby_at), 75, "corners only change hands by force")
	assert_eq(Gangs.anger(_run, _baby()), Gangs.MAX_ANGER)
	assert_eq(_run.cash, 10000, "ignoring never costs cash")
	assert_true(Gangs.hunt_due(_run, _baby(), 0.0))
	assert_false(Gangs.hunt_due(_run, _baby(), 0.99))


func test_hunt_fee_is_fixed_and_calms_vex() -> void:
	Gangs.set_anger(_run, _baby(), Gangs.MAX_ANGER)
	_run.pending_encounter = Gangs.hunt(_run, _baby())
	assert_eq(_ids(_run.pending_encounter), [Gangs.PAY, Gangs.FIGHT])
	Encounters.resolve(_run, Gangs.PAY, 0.0)
	assert_eq(_run.cash, 10000 - _baby().hunt_fee)
	assert_eq(Gangs.anger(_run, _baby()), Gangs.ANGER_AFTER_PAYING)


func test_winning_the_hunt_fight_ends_the_feud() -> void:
	Gangs.set_anger(_run, _baby(), Gangs.MAX_ANGER)
	_run.pending_encounter = Gangs.hunt(_run, _baby())
	Encounters.resolve(_run, Gangs.FIGHT, 0.0)
	assert_eq(Turf.share(_run, &"docks"), 0)
	assert_eq(Gangs.anger(_run, _baby()), 0)
	assert_eq(_run.cash, 10000)


func test_losing_the_hunt_fight_costs_heat_but_no_cash() -> void:
	Gangs.set_anger(_run, _baby(), Gangs.MAX_ANGER)
	_run.pending_encounter = Gangs.hunt(_run, _baby())
	Encounters.resolve(_run, Gangs.FIGHT, 0.99)
	assert_eq(_run.heat, Gangs.FIGHT_LOSS_HEAT)
	assert_eq(_run.cash, 10000)
	assert_eq(Gangs.anger(_run, _baby()), Gangs.ANGER_AFTER_BEATING)


func test_hunt_outside_the_turf_war_is_fought_over_the_strongest_district() -> void:
	_run.district_id = &"golden_mile"
	_hold_corners(&"docks", 3)
	assert_eq(Gangs.fight_district(_run, _baby()), &"docks")


func test_anger_survives_a_save_and_is_clamped() -> void:
	Gangs.set_anger(_run, _vex(), 2)
	var data := _run.to_dict()
	assert_eq(Gangs.anger(RunState.from_dict(JSON.parse_string(JSON.stringify(data))), _vex()), 2)
	data.gang_anger = { "vex": 99 }
	assert_eq(Gangs.anger(RunState.from_dict(data), _vex()), Gangs.MAX_ANGER)


func _vex() -> GangDef:
	return Content.gang(&"vex")


func _baby() -> GangDef:
	return Content.gang(&"baby")


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
	assert_eq(Content.gangs().size(), 5)
	assert_eq(Turf.contested().size(), 7)
	for gang in Content.gangs():
		var boss := Content.character(gang.boss)
		assert_not_null(boss, "%s boss" % gang.id)
		assert_eq(boss.role, CharacterDef.Role.RIVAL, "%s boss role" % gang.id)
		assert_false(gang.turf.is_empty(), "%s turf" % gang.id)
		for district_id in gang.turf:
			assert_not_null(Content.district(district_id), "%s turf %s" % [gang.id, district_id])
			var corners := Corners.of(district_id)
			assert_eq(corners.size(), 4, "%s corners" % district_id)
			assert_eq(corners.filter(func(corner: CornerDef) -> bool: return corner.stronghold).size(), 1, "%s stronghold" % district_id)
			assert_true(corners.any(func(corner: CornerDef) -> bool: return Corners.gang_of(corner.id) == gang), "%s holds corners in %s" % [gang.id, district_id])
		assert_string_contains(gang.gate_line, "%s")
		assert_string_contains(gang.victory_line, "%s")


func _style_gate(gang_id: StringName, district_id: StringName) -> Dictionary:
	var encounter := Gangs.gate(_run, Content.gang(gang_id))
	encounter.district = String(district_id)
	_run.district_id = district_id
	_hold_corners(district_id, 1)
	_run.pending_encounter = encounter
	return encounter


func test_each_gang_has_its_own_style() -> void:
	assert_eq(_vex().style, GangDef.Style.TAX)
	assert_eq(_baby().style, GangDef.Style.TAX)
	assert_eq(Content.gang(&"lucyferek").style, GangDef.Style.TAX)
	assert_eq(Content.gang(&"jackal").style, GangDef.Style.MUGGING)
	assert_eq(Content.gang(&"celeste").style, GangDef.Style.INFORMER)


func test_muggers_ask_for_a_share_of_the_cash_and_offer_no_refusal() -> void:
	var encounter := _style_gate(&"jackal", &"riverside")
	assert_eq(int(encounter.bribe), roundi(10000 * Gangs.MUGGING_SHARE))
	assert_eq(_ids(encounter), [Gangs.BRIBE, Gangs.FIGHT, Gangs.RUN])
	_run.cash = 100
	assert_eq(Gangs.mugging_cut(_run, Content.gang(&"jackal")), Content.gang(&"jackal").bribe_base)


func test_losing_a_fight_to_muggers_empties_more_of_your_pockets() -> void:
	var encounter := _style_gate(&"jackal", &"riverside")
	var cut := int(encounter.bribe)
	Encounters.resolve(_run, Gangs.FIGHT, 0.99)
	assert_eq(_run.cash, 10000 - roundi(cut * Gangs.BEATEN_MUGGING_FACTOR))
	assert_eq(Turf.share(_run, &"riverside"), 25)


func test_running_from_muggers_costs_heat_or_the_cut() -> void:
	_style_gate(&"jackal", &"riverside")
	Encounters.resolve(_run, Gangs.RUN, 0.0)
	assert_eq(_run.cash, 10000)
	assert_eq(_run.heat, Gangs.ESCAPED_HEAT)
	assert_eq(Gangs.anger(_run, Content.gang(&"jackal")), 1)
	var encounter := _style_gate(&"jackal", &"riverside")
	var cut := int(encounter.bribe)
	Encounters.resolve(_run, Gangs.RUN, 0.99)
	assert_eq(_run.cash, 10000 - cut)


func test_refusing_an_informer_brings_the_police() -> void:
	var encounter := _style_gate(&"celeste", &"west_end")
	assert_eq(_ids(encounter), [Gangs.BRIBE, Gangs.THREATEN, Gangs.IGNORE])
	Encounters.resolve(_run, Gangs.IGNORE, 0.0)
	assert_eq(_run.heat, Gangs.TIP_OFF_HEAT)
	assert_eq(_run.pending_encounter.get("type"), Encounters.POLICE)
	assert_eq(Gangs.anger(_run, Content.gang(&"celeste")), 1)

