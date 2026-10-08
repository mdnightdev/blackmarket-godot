extends GutTest

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	Inventory.add_units(_run, &"burner_phones", 5)


func _family() -> FamilyDef:
	return Content.families()[0]


func test_the_best_line_wins_family_then_fake_id_then_playing_dumb() -> void:
	assert_eq(Talk.police_line(_run), Talk.PLAY_DUMB)
	Inventory.add_units(_run, Talk.FAKE_ID, 1)
	assert_eq(Talk.police_line(_run), Talk.SHOW_ID)
	_run.family_standing[_family().id] = Families.TRUSTED_AT
	assert_eq(Talk.police_line(_run), Talk.NAME_DROP)
	assert_string_contains(Talk.police_label(_run, Talk.NAME_DROP), _family().english_name)


func test_cred_helps_and_heat_hurts() -> void:
	var start := Talk.police_chance(_run, Talk.PLAY_DUMB)
	_run.street_cred = StreetCred.MAX
	assert_gt(Talk.police_chance(_run, Talk.PLAY_DUMB), start)
	_run.street_cred = 0
	_run.heat = Heat.MAX
	assert_lt(Talk.police_chance(_run, Talk.PLAY_DUMB), start)
	assert_gte(Talk.police_chance(_run, Talk.PLAY_DUMB), Odds.MIN_CHANCE)


func test_a_family_name_beats_a_fake_id_and_a_fake_id_beats_playing_dumb() -> void:
	_run.family_standing[_family().id] = Families.FAMILY_AT
	assert_gt(Talk.police_chance(_run, Talk.NAME_DROP), Talk.police_chance(_run, Talk.SHOW_ID))
	assert_gt(Talk.police_chance(_run, Talk.SHOW_ID), Talk.police_chance(_run, Talk.PLAY_DUMB))


func test_a_good_line_ends_the_stop_for_free() -> void:
	_run.pending_encounter = Encounters.police_stop(_run)
	assert_ne(Encounters.resolve(_run, Talk.PLAY_DUMB, 0.0), "")
	assert_false(Encounters.has_pending(_run))
	assert_eq(_run.cash, RunState.STARTING_CASH)
	assert_eq(Inventory.count(_run, &"burner_phones"), 5)


func test_a_bad_line_leaves_the_player_cornered() -> void:
	_run.pending_encounter = Encounters.police_stop(_run)
	Encounters.resolve(_run, Talk.PLAY_DUMB, 0.999)
	assert_true(bool(_run.pending_encounter.get("cornered", false)))
	var ids := Encounters.choices(_run, _run.pending_encounter).map(func(choice: Encounters.Choice) -> StringName: return choice.id)
	assert_false(ids.has(Talk.PLAY_DUMB), "no second try")
	assert_false(ids.has(Encounters.RUN))


func test_a_fake_id_that_fails_is_kept_by_the_police() -> void:
	Inventory.add_units(_run, Talk.FAKE_ID, 2)
	_run.pending_encounter = Encounters.police_stop(_run)
	Encounters.resolve(_run, Talk.SHOW_ID, 0.999)
	assert_eq(Inventory.count(_run, Talk.FAKE_ID), 1)


func test_a_line_the_player_does_not_have_is_refused() -> void:
	_run.pending_encounter = Encounters.police_stop(_run)
	assert_eq(Encounters.resolve(_run, Talk.SHOW_ID, 0.0), "")
	assert_true(Encounters.has_pending(_run))
