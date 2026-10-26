extends GutTest

var _run: RunState
var _phones: ItemDef
var _no_events: Array[EventDef] = []


func before_each() -> void:
	_run = RunState.new()
	Story.mark(_run, War.VEX_FELL)
	_phones = Content.item(&"burner_phones")


func _choice_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for choice in Encounters.choices(_run, _run.pending_encounter):
		ids.append(choice.id)
	return ids


func test_max_heat_triggers_a_raid_when_time_passes() -> void:
	_run.day = Police.GRACE_DAYS + 1
	Inventory.add_units(_run, _phones.id, 5)
	_run.heat = Heat.MAX
	Encounters.after_time_passes(_run, false, true, RandomNumberGenerator.new(), _no_events)
	assert_eq(_run.pending_encounter.type, Encounters.RAID)
	assert_eq(Inventory.count(_run, _phones.id), 2)
	assert_eq(_run.heat, Police.HEAT_AFTER_ARREST)


func test_no_raid_or_stop_while_the_police_are_quiet() -> void:
	Inventory.add_units(_run, _phones.id, 20)
	_run.heat = Heat.MAX
	Encounters.check_raid(_run)
	assert_false(Encounters.has_pending(_run), "grace period")
	var rng := RandomNumberGenerator.new()
	Encounters.after_time_passes(_run, false, true, rng, _no_events)
	assert_false(Encounters.has_pending(_run), "no raid during grace period")


func test_no_immunity_shield_after_arrest() -> void:
	_run.day = Police.GRACE_DAYS + 1
	Police.arrest(_run)
	_run.heat = Heat.MAX
	Encounters.check_raid(_run)
	assert_true(Encounters.has_pending(_run), "arrest grants no immunity cooldown against max heat raids")


func test_check_raid_only_at_max_heat() -> void:
	_run.day = Police.GRACE_DAYS + 1
	_run.heat = Heat.MAX - 1
	Encounters.check_raid(_run)
	assert_false(Encounters.has_pending(_run))
	_run.heat = Heat.MAX
	Encounters.check_raid(_run)
	assert_eq(_run.pending_encounter.type, Encounters.RAID)


func _stay_put() -> void:
	_run.pending_encounter = Encounters.police_stop(_run)
	assert_eq(Encounters.resolve(_run, Encounters.STAY, 0.5), "")


func test_a_stop_offers_running_or_staying_then_a_talk() -> void:
	Inventory.add_units(_run, _phones.id, 5)
	_run.pending_encounter = Encounters.police_stop(_run)
	assert_eq(_choice_ids(), [Encounters.RUN, Encounters.STAY])
	_stay_put()
	assert_eq(_choice_ids(), [Encounters.BRIBE, Talk.PLAY_DUMB, Encounters.COMPLY])
	assert_false(bool(_run.pending_encounter.cornered))


func test_a_clean_search_lets_the_player_go() -> void:
	_stay_put()
	assert_string_contains(Encounters.resolve(_run, Encounters.COMPLY, 0.5), "finds nothing")
	assert_false(Police.is_jailed(_run))
	assert_false(Encounters.has_pending(_run))


func test_goods_found_in_a_search_book_the_player() -> void:
	Inventory.add_units(_run, _phones.id, 10)
	var carried := Police.carried_value(_run)
	_stay_put()
	assert_string_contains(Encounters.resolve(_run, Encounters.COMPLY, 0.5), "books you")
	assert_true(Police.is_jailed(_run))
	assert_lt(Inventory.count(_run, _phones.id), 10, "the evidence is seized")
	assert_eq(_run.jail_bail, maxi(Police.MIN_BAIL, roundi(carried * Police.BAIL_SHARE)))


func test_a_failed_line_ends_in_the_search() -> void:
	Inventory.add_units(_run, _phones.id, 10)
	_stay_put()
	var outcome := Encounters.resolve(_run, Talk.PLAY_DUMB, 0.999)
	assert_string_contains(outcome, "not buying it")
	assert_true(Police.is_jailed(_run))
	assert_false(Encounters.has_pending(_run))


func test_caught_running_means_a_steeper_bribe_and_no_second_run() -> void:
	Inventory.add_units(_run, _phones.id, 5)
	_run.pending_encounter = Encounters.police_stop(_run)
	var bribe := int(_run.pending_encounter.bribe)
	assert_ne(Encounters.resolve(_run, Encounters.RUN, 0.999), "")
	assert_true(bool(_run.pending_encounter.cornered))
	assert_eq(int(_run.pending_encounter.bribe), roundi(bribe * Police.CORNERED_BRIBE_FACTOR))
	assert_false(_choice_ids().has(Encounters.RUN))


func test_jail_runs_on_real_time_and_survives_a_save() -> void:
	Police.go_to_jail(_run, 0, 1000.0)
	assert_true(Police.is_jailed(_run, 1000.0 + Police.JAIL_SECONDS - 1.0))
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(_run.to_dict())))
	assert_almost_eq(Police.jail_seconds_left(restored, 1000.0 + Police.JAIL_SECONDS - 1.0), 1.0, 0.001)
	assert_eq(restored.jail_bail, Police.MIN_BAIL)
	assert_false(Police.release_if_served(restored, 1000.0 + 10.0))
	assert_true(Police.release_if_served(restored, 1000.0 + Police.JAIL_SECONDS))
	assert_false(Police.release_if_served(restored, 1000.0 + Police.JAIL_SECONDS + 1.0), "only the release reports true")


func test_a_clock_turned_back_never_adds_time() -> void:
	Police.go_to_jail(_run, 0, 1000.0)
	assert_eq(Police.jail_seconds_left(_run, 0.0), Police.JAIL_SECONDS)


func test_bail_sets_the_player_free() -> void:
	Police.go_to_jail(_run, 0)
	_run.cash = Police.MIN_BAIL - 1
	assert_false(Police.post_bail(_run))
	assert_true(Police.is_jailed(_run))
	_run.cash = Police.MIN_BAIL
	assert_true(Police.post_bail(_run))
	assert_false(Police.is_jailed(_run))
	assert_eq(_run.cash, 0)


func test_nothing_finds_the_player_in_a_cell() -> void:
	_run.day = Police.GRACE_DAYS + 1
	Inventory.add_units(_run, _phones.id, 20)
	Police.go_to_jail(_run, 0)
	var rng := RandomNumberGenerator.new()
	for attempt in 50:
		rng.seed = attempt
		_run.heat = 90
		Encounters.after_time_passes(_run, false, false, rng, Content.events())
		assert_false(Encounters.has_pending(_run))


func test_bribe_pays_and_clears_the_stop() -> void:
	Inventory.add_units(_run, _phones.id, 5)
	_stay_put()
	var bribe := int(_run.pending_encounter.bribe)
	assert_ne(Encounters.resolve(_run, Encounters.BRIBE, 0.5), "")
	assert_eq(_run.cash, RunState.STARTING_CASH - bribe)
	assert_false(Encounters.has_pending(_run))
	assert_eq(Inventory.count(_run, _phones.id), 5)


func test_unaffordable_bribe_is_refused() -> void:
	Inventory.add_units(_run, _phones.id, 5)
	_stay_put()
	_run.cash = 10
	assert_eq(Encounters.resolve(_run, Encounters.BRIBE, 0.5), "")
	assert_true(Encounters.has_pending(_run))
	assert_eq(_run.cash, 10)


func test_mugging_pay_and_fight() -> void:
	var mugging := { "type": Encounters.EVENT, "effect": EventDef.Effect.MUGGING, "amount": 300 }
	_run.pending_encounter = mugging.duplicate()
	assert_eq(_choice_ids(), [Encounters.PAY, Encounters.FIGHT])
	Encounters.resolve(_run, Encounters.PAY, 0.5)
	assert_eq(_run.cash, RunState.STARTING_CASH - 300)

	_run.pending_encounter = mugging.duplicate()
	Encounters.resolve(_run, Encounters.FIGHT, 0.0)
	assert_eq(_run.cash, RunState.STARTING_CASH - 300)

	_run.pending_encounter = mugging.duplicate()
	Encounters.resolve(_run, Encounters.FIGHT, 0.99)
	assert_eq(_run.cash, RunState.STARTING_CASH - 300 - roundi(300 * StreetEvents.FIGHT_LOSS_MULTIPLIER))


func test_lucky_find_take_and_leave() -> void:
	var find := { "type": Encounters.EVENT, "effect": EventDef.Effect.LUCKY_FIND, "item": "burner_sims", "quantity": 4 }
	_run.pending_encounter = find.duplicate()
	Encounters.resolve(_run, Encounters.TAKE, 0.5)
	assert_eq(Inventory.count(_run, &"burner_sims"), 4)
	_run.pending_encounter = find.duplicate()
	Encounters.resolve(_run, Encounters.LEAVE, 0.5)
	assert_eq(Inventory.count(_run, &"burner_sims"), 4)


func test_info_cards_close_with_continue() -> void:
	_run.pending_encounter = { "type": Encounters.RAID, "title": "Raid", "body": "" }
	assert_eq(_choice_ids(), [Encounters.CONTINUE])
	assert_eq(Encounters.resolve(_run, Encounters.CONTINUE, 0.5), "")
	assert_false(Encounters.has_pending(_run))


func test_price_event_applies_its_shift_when_rolled() -> void:
	var rng := RandomNumberGenerator.new()
	var shift_only: Array[EventDef] = []
	for event in Content.events():
		if event.id == &"market_flooded":
			shift_only.append(event)
	Inventory.add_units(_run, _phones.id, 1)
	for attempt in 200:
		rng.seed = attempt
		_run.pending_encounter = {}
		_run.market_shifts.clear()
		_run.heat = 0
		Encounters.after_time_passes(_run, false, false, rng, shift_only)
		if _run.pending_encounter.get("type") == Encounters.EVENT:
			assert_eq(_run.market_shifts.size(), 1)
			assert_eq(_run.market_shifts[0].district, _run.pending_encounter.district)
			return
	fail_test("No street event rolled in 200 seeds")


func test_pending_encounter_and_shifts_survive_a_save() -> void:
	Inventory.add_units(_run, _phones.id, 5)
	_run.pending_encounter = Encounters.police_stop(_run)
	_run.market_shifts.append({ "district": "docks", "category": "arms", "multiplier": 1.5, "from": 2, "until": 5 })
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(_run.to_dict())))
	assert_eq(restored.pending_encounter.type, Encounters.POLICE)
	assert_eq(int(restored.pending_encounter.bribe), int(_run.pending_encounter.bribe))
	assert_eq(restored.market_shifts[0].until, 5)
	assert_eq(Encounters.resolve(restored, Encounters.STAY, 0.5), "")
	assert_string_contains(Encounters.resolve(restored, Encounters.COMPLY, 0.5), "He bags 3 Burner Phones")


func test_brandt_makes_every_stop_unless_ramos_works_for_vex() -> void:
	for stamp in 40:
		_run.day = floori(stamp / 4.0) + 1
		_run.phase = (stamp % 4) as RunState.Phase
		assert_eq(StringName(Encounters.police_stop(_run).speaker), Police.BRANDT)
	_run.lender = Loan.VEX_LENDER
	var ramos_stops := 0
	for stamp in 40:
		_run.day = floori(stamp / 4.0) + 1
		_run.phase = (stamp % 4) as RunState.Phase
		var patrol := Roster.strongest_patrol(_run, _run.district_id, stamp)
		var expected := Ramos.ID if patrol != null and patrol.id == Ramos.ID else Police.BRANDT
		var speaker := StringName(Encounters.police_stop(_run).speaker)
		assert_eq(speaker, expected)
		if speaker == Ramos.ID:
			ramos_stops += 1
	assert_gt(ramos_stops, 0, "Vex's Ramos stops the player himself")


func test_raid_and_collectors_have_their_own_speakers() -> void:
	assert_eq(StringName(Encounters.raid(_run).speaker), Encounters.RAID_LEAD)
	assert_eq(StringName(Encounters.send_enforcers(_run).speaker), Encounters.COLLECTOR)


func test_events_carry_their_speaker() -> void:
	_run.cash = 1000
	for event in Content.events():
		var encounter := StreetEvents.prepare(_run, event, RandomNumberGenerator.new())
		if not encounter.is_empty():
			assert_eq(StringName(encounter.speaker), event.speaker, String(event.id))
