extends GutTest

const RUNNER: StringName = &"runner"
const MUSCLE: StringName = &"muscle"
const LOOKOUT: StringName = &"lookout"
const DRIVER: StringName = &"driver"

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	_run.career = true
	Story.mark(_run, War.VEX_FELL)
	_run.cash = 50_000
	_run.stash_level = Safehouse.UPGRADES.size()
	_set_rank(StreetCred.max_rank())


func _set_rank(rank_number: int) -> void:
	_run.street_cred = int(StreetCred.RANKS[rank_number - 1].cred)


func _hire_everyone() -> void:
	for role in Content.crew_roles():
		assert_eq(Crew.hire(_run, role.id), Crew.Result.OK, String(role.id))


func test_every_role_is_complete() -> void:
	var roles := Content.crew_roles()
	assert_eq(roles.size(), 4)
	for role in roles:
		assert_false(role.display_name.is_empty(), String(role.id))
		assert_false(role.description.is_empty(), String(role.id))
		assert_gt(role.hire_cost, 0, String(role.id))
		assert_gt(role.daily_wage, 0, String(role.id))
		assert_between(role.min_rank, 1, StreetCred.max_rank(), String(role.id))


func test_cap_grows_with_the_safehouse() -> void:
	_run.stash_level = 0
	assert_eq(Crew.cap(_run), 1)
	_run.stash_level = Safehouse.UPGRADES.size()
	assert_eq(Crew.cap(_run), 1 + Safehouse.UPGRADES.size())


func test_hiring_pays_and_records_the_day() -> void:
	_run.day = 7
	var runner := Content.crew_role(RUNNER)
	assert_eq(Crew.hire(_run, RUNNER), Crew.Result.OK)
	assert_eq(_run.cash, 50_000 - runner.hire_cost)
	assert_true(Crew.has(_run, RUNNER))
	assert_eq(_run.crew.size(), 1)
	assert_eq(_run.crew[0], { "role": "runner", "hired_day": 7, "unpaid_days": 0 })


func test_crew_waits_for_act_two() -> void:
	_run.story_flags.clear()
	assert_eq(Crew.check_hire(_run, RUNNER), Crew.Result.NOT_CAREER)
	assert_eq(Crew.hire(_run, RUNNER), Crew.Result.NOT_CAREER)
	assert_true(_run.crew.is_empty())
	assert_eq(_run.cash, 50_000)


func test_unknown_roles_cannot_be_hired() -> void:
	assert_eq(Crew.hire(_run, &"accountant"), Crew.Result.UNKNOWN)
	assert_true(_run.crew.is_empty())


func test_each_role_needs_its_rank() -> void:
	var muscle := Content.crew_role(MUSCLE)
	_set_rank(muscle.min_rank - 1)
	assert_eq(Crew.hire(_run, MUSCLE), Crew.Result.RANK_TOO_LOW)
	_set_rank(muscle.min_rank)
	assert_eq(Crew.hire(_run, MUSCLE), Crew.Result.OK)


func test_one_of_each_role() -> void:
	Crew.hire(_run, RUNNER)
	assert_eq(Crew.hire(_run, RUNNER), Crew.Result.ALREADY_HIRED)
	assert_eq(_run.crew.size(), 1)


func test_crew_is_limited_by_the_cap() -> void:
	_run.stash_level = 0
	assert_eq(Crew.hire(_run, RUNNER), Crew.Result.OK)
	assert_eq(Crew.check_hire(_run, MUSCLE), Crew.Result.CREW_FULL)
	_run.stash_level = 1
	assert_eq(Crew.hire(_run, MUSCLE), Crew.Result.OK)


func test_hiring_needs_the_cash() -> void:
	_run.cash = Content.crew_role(DRIVER).hire_cost - 1
	assert_eq(Crew.hire(_run, DRIVER), Crew.Result.NOT_ENOUGH_CASH)
	assert_eq(_run.cash, Content.crew_role(DRIVER).hire_cost - 1)
	assert_true(_run.crew.is_empty())


func test_firing_frees_the_slot() -> void:
	_run.stash_level = 0
	Crew.hire(_run, RUNNER)
	var cash_before := _run.cash
	assert_eq(Crew.fire(_run, RUNNER), Crew.Result.OK)
	assert_false(Crew.has(_run, RUNNER))
	assert_eq(_run.cash, cash_before, "no refund")
	assert_eq(Crew.fire(_run, RUNNER), Crew.Result.NOT_HIRED)
	assert_eq(Crew.hire(_run, MUSCLE), Crew.Result.OK)


func test_roles_and_wages_follow_the_crew() -> void:
	Crew.hire(_run, MUSCLE)
	Crew.hire(_run, RUNNER)
	var roles := Crew.roles(_run)
	assert_eq(roles.size(), 2)
	assert_eq(roles[0].id, MUSCLE)
	assert_eq(roles[1].id, RUNNER)
	assert_eq(Crew.daily_wages(_run), Content.crew_role(MUSCLE).daily_wage + Content.crew_role(RUNNER).daily_wage)


func test_wages_are_paid_each_morning() -> void:
	Crew.hire(_run, RUNNER)
	Crew.hire(_run, MUSCLE)
	_run.crew[0]["unpaid_days"] = 1
	_run.cash = 1000
	var walked := Crew.pay_wages(_run)
	assert_true(walked.is_empty())
	assert_eq(_run.cash, 1000 - Crew.daily_wages(_run))
	assert_eq(int(_run.crew[0].unpaid_days), 0)


func test_unpaid_crew_walk_out() -> void:
	var runner := Content.crew_role(RUNNER)
	var muscle := Content.crew_role(MUSCLE)
	Crew.hire(_run, RUNNER)
	Crew.hire(_run, MUSCLE)
	var cred_before := _run.street_cred
	_run.cash = runner.daily_wage + muscle.daily_wage - 1

	assert_true(Crew.pay_wages(_run).is_empty())
	assert_eq(_run.cash, muscle.daily_wage - 1)
	assert_eq(int(_run.crew[0].unpaid_days), 0)
	assert_eq(int(_run.crew[1].unpaid_days), 1)

	var walked := Crew.pay_wages(_run)
	assert_eq(walked.size(), 1)
	assert_eq(walked[0].id, MUSCLE)
	assert_false(Crew.has(_run, MUSCLE))
	assert_true(Crew.has(_run, RUNNER))
	assert_eq(_run.cash, muscle.daily_wage - 1 - runner.daily_wage)
	assert_eq(int(_run.crew[0].unpaid_days), 0)
	assert_eq(_run.street_cred, cred_before + StreetCred.CREW_WALKED)


func test_broke_crews_all_walk_together() -> void:
	_hire_everyone()
	_run.cash = 0
	var cred_before := _run.street_cred
	Crew.pay_wages(_run)
	assert_eq(Crew.pay_wages(_run).size(), 4)
	assert_true(_run.crew.is_empty())
	assert_eq(_run.street_cred, cred_before + 4 * StreetCred.CREW_WALKED)


func test_no_crew_means_no_effects() -> void:
	assert_eq(Crew.capacity_bonus(_run), 0)
	assert_almost_eq(Crew.stop_factor(_run), 1.0, 0.0001)
	assert_almost_eq(Crew.escape_bonus(_run), 0.0, 0.0001)
	assert_almost_eq(Crew.fight_bonus(_run), 0.0, 0.0001)
	assert_almost_eq(Crew.mugging_factor(_run), 1.0, 0.0001)
	assert_false(Crew.can_warn_of_raid(_run))
	assert_eq(Crew.daily_wages(_run), 0)


func test_full_crew_effects_add_up() -> void:
	_hire_everyone()
	var capacity := 0
	var reduction := 0.0
	var escape := 0.0
	var fight := 0.0
	var mugging := 1.0
	for role in Content.crew_roles():
		capacity += role.capacity_bonus
		reduction += role.stop_reduction
		escape += role.escape_bonus
		fight += role.fight_bonus
		mugging *= role.mugging_factor
	assert_eq(Crew.capacity_bonus(_run), capacity)
	assert_almost_eq(Crew.stop_factor(_run), maxf(Crew.MIN_STOP_FACTOR, 1.0 - reduction), 0.0001)
	assert_almost_eq(Crew.escape_bonus(_run), escape, 0.0001)
	assert_almost_eq(Crew.fight_bonus(_run), fight, 0.0001)
	assert_almost_eq(Crew.mugging_factor(_run), mugging, 0.0001)


func test_each_role_brings_its_perk() -> void:
	Crew.hire(_run, RUNNER)
	assert_eq(Crew.capacity_bonus(_run), Content.crew_role(RUNNER).capacity_bonus)
	Crew.hire(_run, MUSCLE)
	assert_almost_eq(Crew.mugging_factor(_run), Content.crew_role(MUSCLE).mugging_factor, 0.0001)
	assert_almost_eq(Crew.fight_bonus(_run), Content.crew_role(MUSCLE).fight_bonus, 0.0001)
	Crew.hire(_run, DRIVER)
	assert_lt(Crew.stop_factor(_run), 1.0)
	assert_almost_eq(Crew.escape_bonus(_run), Content.crew_role(DRIVER).escape_bonus, 0.0001)
	assert_false(Crew.can_warn_of_raid(_run))
	Crew.hire(_run, LOOKOUT)
	assert_almost_eq(Crew.stop_factor(_run), 1.0 - Content.crew_role(LOOKOUT).stop_reduction - Content.crew_role(DRIVER).stop_reduction, 0.0001)
	assert_true(Crew.can_warn_of_raid(_run))


func test_lookout_warns_once_a_day() -> void:
	Crew.hire(_run, LOOKOUT)
	_run.day = 4
	assert_true(Crew.can_warn_of_raid(_run))
	Crew.use_raid_warning(_run)
	assert_eq(_run.raid_warning_day, 4)
	assert_false(Crew.can_warn_of_raid(_run))
	_run.day = 5
	assert_true(Crew.can_warn_of_raid(_run))


func test_sanitize_cleans_saved_entries() -> void:
	assert_true(Crew.sanitize({ "role": "accountant", "hired_day": 2 }).is_empty())
	assert_true(Crew.sanitize({}).is_empty())
	assert_eq(Crew.sanitize({ "role": "runner", "hired_day": -3, "unpaid_days": 9 }), {
		"role": "runner",
		"hired_day": 1,
		"unpaid_days": Crew.UNPAID_DAYS_TO_WALK - 1,
	})
	assert_eq(Crew.sanitize({ "role": "driver", "hired_day": 12.0, "unpaid_days": 1.0 }), {
		"role": "driver",
		"hired_day": 12,
		"unpaid_days": 1,
	})


func test_crew_survives_a_save() -> void:
	_run.day = 3
	Crew.hire(_run, RUNNER)
	Crew.hire(_run, LOOKOUT)
	Crew.use_raid_warning(_run)
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(_run.to_dict())))
	assert_true(Crew.has(restored, RUNNER))
	assert_true(Crew.has(restored, LOOKOUT))
	assert_eq(Crew.daily_wages(restored), Crew.daily_wages(_run))
	assert_false(Crew.can_warn_of_raid(restored))


func test_every_role_lists_its_effects_in_numbers() -> void:
	assert_eq(Crew.effects(Content.crew_role(RUNNER)), "+15 bag slots, delivers 1 job a phase")
	for role in Content.crew_roles():
		assert_false(Crew.effects(role).is_empty(), String(role.id))


func _take_order(quantity: int) -> Dictionary:
	var order := {
		"id": "test:0:0", "venue": "", "dealer": "wei", "item": "burner_phones",
		"quantity": quantity, "price": 200, "due": Calendar.stamp(_run) + 2,
	}
	_run.orders.append(order)
	Inventory.add_units(_run, &"burner_phones", quantity)
	return order


func test_runner_delivers_once_a_phase_without_heat() -> void:
	var order := _take_order(4)
	assert_eq(Crew.send_runner(_run, order), 0, "no runner hired yet")
	Crew.hire(_run, RUNNER)
	var cash := _run.cash
	assert_eq(Crew.send_runner(_run, order), 800)
	assert_eq(_run.cash, cash + 800)
	assert_eq(_run.heat, 0)
	assert_true(_run.orders.is_empty())
	assert_false(Crew.runner_ready(_run))
	var second := _take_order(2)
	assert_eq(Crew.send_runner(_run, second), 0, "one run a phase")
	Calendar.advance_phase(_run)
	assert_eq(Crew.send_runner(_run, second), 400)


func test_morning_report_counts_what_the_crew_did() -> void:
	assert_eq(Crew.report_line(_run), "")
	Crew.use_runner(_run, 900)
	Crew.use_runner(_run, 300)
	assert_eq(Crew.report_line(_run), "Yesterday your runner made 2 deliveries worth $1,200.")


func test_crew_report_and_runner_survive_a_save() -> void:
	Crew.hire(_run, RUNNER)
	Crew.use_runner(_run, 500)
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(_run.to_dict())))
	assert_eq(restored.crew_report, _run.crew_report)
	assert_false(Crew.runner_ready(restored))
