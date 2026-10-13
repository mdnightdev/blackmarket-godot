extends GutTest

var _run: RunState
var _phones: ItemDef
var _papers: ItemDef


func before_each() -> void:
	_run = RunState.new()
	Story.mark(_run, War.VEX_FELL)
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


func test_bribe_scales_with_carried_value_within_limits() -> void:
	Inventory.add_units(_run, _phones.id, 4)
	assert_eq(Police.bribe_cost(_run), Police.MIN_BRIBE)
	Inventory.add_units(_run, _phones.id, 196)
	var value := 200 * _phones.base_price
	for stamp in 30:
		Calendar.advance_phase(_run)
		assert_between(Police.bribe_cost(_run), floori(value * Police.BRIBE_LOW), ceili(value * Police.BRIBE_HIGH))


func test_bribe_holds_for_the_whole_phase() -> void:
	Inventory.add_units(_run, _phones.id, 200)
	assert_eq(Police.bribe_cost(_run), Police.bribe_cost(_run))


func test_a_cornered_player_cannot_run_and_pays_more() -> void:
	Inventory.add_units(_run, _phones.id, 200)
	var calm := Encounters.police_stop(_run)
	var cornered := Encounters.police_talk(calm, true)
	assert_eq(int(cornered.bribe), roundi(int(calm.bribe) * Police.CORNERED_BRIBE_FACTOR))
	var ids := Encounters.choices(_run, cornered).map(func(choice: Encounters.Choice) -> StringName: return choice.id)
	assert_false(ids.has(Encounters.RUN))


func test_escape_keeps_goods_and_adds_heat() -> void:
	Inventory.add_units(_run, _phones.id, 3)
	assert_true(Police.run_for_it(_run, 0.0))
	assert_eq(Inventory.count(_run, _phones.id), 3)
	assert_eq(_run.heat, Police.ESCAPED_HEAT)


func test_getting_caught_running_leads_to_a_cornered_stop_not_an_arrest() -> void:
	Trade.buy(_run, _phones, 4, 100)
	var cash := _run.cash
	_run.heat = 80
	_run.pending_encounter = Encounters.police_stop(_run)
	assert_ne(Encounters.resolve(_run, Encounters.RUN, 0.99), "")
	assert_eq(Inventory.count(_run, _phones.id), 4)
	assert_eq(_run.cash, cash)
	assert_eq(_run.busts, 0)
	assert_true(bool(_run.pending_encounter.get("cornered", false)))


func test_vehicle_improves_escape_odds() -> void:
	var on_foot := Police.escape_chance(_run)
	_run.gear.append(&"scooter")
	assert_gt(Police.escape_chance(_run), on_foot)


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
	_run.district_id = &"docks"
	Inventory.add_units(_run, _phones.id, 5)
	_run.heat = 0
	var contested := Police.stop_chance(_run)
	assert_lt(contested, Police.MAX_STOP_CHANCE)
	Corners.take_all(_run, _run.district_id)
	assert_almost_eq(Police.stop_chance(_run), contested * Turf.HELD_STOP_FACTOR, 0.0001)


func test_heat_makes_escapes_harder_but_never_hopeless() -> void:
	var cool := Police.escape_chance(_run)
	_run.heat = Heat.MAX
	assert_lt(Police.escape_chance(_run), cool)
	assert_gte(Police.escape_chance(_run), Odds.MIN_CHANCE)
	assert_lte(cool, Odds.MAX_CHANCE)


func test_arrest_takes_half_of_each_stack_rounded_up_but_not_the_stash() -> void:
	_run.heat = Heat.MAX
	Inventory.add_units(_run, _phones.id, 5)
	Inventory.add_units(_run, _papers.id, 1)
	_run.stash[_papers.id] = 2
	_run.stashed_cash = 500
	Police.arrest(_run)
	assert_eq(Inventory.count(_run, _phones.id), 2)
	assert_eq(Inventory.count(_run, _papers.id), 0)
	assert_eq(Inventory.stashed(_run, _papers.id), 2)
	assert_eq(_run.stashed_cash, 500)
	assert_eq(_run.heat, Police.HEAT_AFTER_ARREST)
	assert_eq(_run.busts, 1)


func test_police_stay_away_during_the_first_days() -> void:
	_run.day = Police.GRACE_DAYS
	assert_true(Police.is_quiet(_run))
	_run.day = Police.GRACE_DAYS + 1
	assert_false(Police.is_quiet(_run))


func test_police_stay_away_for_a_full_day_after_an_arrest() -> void:
	_run.day = Police.GRACE_DAYS + 1
	Police.arrest(_run)
	for phase in Police.QUIET_PHASES_AFTER_ARREST:
		Calendar.advance_phase(_run)
		assert_true(Police.is_quiet(_run))
	Calendar.advance_phase(_run)
	assert_false(Police.is_quiet(_run))
