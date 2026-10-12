extends GutTest

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	_run.cash = 100000


func _set_cred_rank(rank: int) -> void:
	_run.street_cred = int(StreetCred.RANKS[rank - 1].cred)


func test_six_skills_with_names_and_three_ranks() -> void:
	var expected: Array[StringName] = [&"haggler", &"pack_mule", &"cool_head", &"wheelman", &"muscle", &"smuggler"]
	assert_eq(Skills.ids(), expected)
	assert_eq(Skills.max_rank(), 3)
	for id in Skills.ids():
		assert_ne(Skills.display_name(id), "", String(id))
		for rank in range(1, Skills.max_rank() + 1):
			assert_ne(Skills.describe(id, rank), "", "%s rank %d" % [id, rank])


func test_describe_shows_the_effect_at_that_rank() -> void:
	assert_eq(Skills.describe(&"haggler", 2), "Buy prices -6%")
	assert_eq(Skills.describe(&"pack_mule", 3), "Bag +35 slots")
	assert_eq(Skills.describe(&"cool_head", 1), "Heat cools 1 more per phase")
	assert_eq(Skills.describe(&"wheelman", 2), "Escapes a lot easier")
	assert_eq(Skills.describe(&"muscle", 3), "Fights far easier")
	assert_eq(Skills.describe(&"smuggler", 1), "Crate pay +10%, crates draw a little less police attention")


func test_describe_handles_bad_input() -> void:
	assert_eq(Skills.describe(&"haggler", 0), "")
	assert_eq(Skills.describe(&"lockpick", 1), "")
	assert_eq(Skills.describe(&"haggler", 9), Skills.describe(&"haggler", 3))


func test_points_are_earned_per_cred_rank_above_the_first() -> void:
	_set_cred_rank(1)
	assert_eq(Skills.points_earned(_run), 0)
	_set_cred_rank(5)
	assert_eq(Skills.points_earned(_run), 4)
	_set_cred_rank(StreetCred.max_rank())
	assert_eq(Skills.points_earned(_run), 9)


func test_spent_points_are_the_sum_of_ranks() -> void:
	_set_cred_rank(StreetCred.max_rank())
	_run.skills = { &"haggler": 2, &"muscle": 1 }
	assert_eq(Skills.points_spent(_run), 3)
	assert_eq(Skills.points_free(_run), 6)


func test_free_points_never_go_negative() -> void:
	_set_cred_rank(2)
	_run.skills = { &"haggler": 3, &"muscle": 3 }
	assert_eq(Skills.points_free(_run), 0)


func test_upgrade_adds_a_rank_and_spends_a_point() -> void:
	_set_cred_rank(3)
	assert_eq(Skills.upgrade(_run, &"haggler"), Skills.Result.OK)
	assert_eq(Skills.rank_of(_run, &"haggler"), 1)
	assert_eq(Skills.points_free(_run), 1)
	assert_eq(Skills.upgrade(_run, &"muscle"), Skills.Result.OK)
	assert_eq(Skills.points_free(_run), 0)


func test_no_points_blocks_the_upgrade() -> void:
	_set_cred_rank(1)
	assert_eq(Skills.check_upgrade(_run, &"haggler"), Skills.Result.NO_POINTS)
	assert_eq(Skills.upgrade(_run, &"haggler"), Skills.Result.NO_POINTS)
	assert_eq(Skills.rank_of(_run, &"haggler"), 0)
	assert_true(_run.skills.is_empty())


func test_cred_rank_gates() -> void:
	assert_eq(Skills.required_cred_rank(1), 1)
	assert_eq(Skills.required_cred_rank(2), 4)
	assert_eq(Skills.required_cred_rank(3), 7)


func test_second_rank_needs_cred_rank_four() -> void:
	_set_cred_rank(3)
	_run.skills = { &"haggler": 1 }
	assert_eq(Skills.upgrade(_run, &"haggler"), Skills.Result.RANK_TOO_LOW)
	assert_eq(Skills.rank_of(_run, &"haggler"), 1)
	_set_cred_rank(4)
	assert_eq(Skills.upgrade(_run, &"haggler"), Skills.Result.OK)
	assert_eq(Skills.rank_of(_run, &"haggler"), 2)


func test_third_rank_needs_cred_rank_seven() -> void:
	_set_cred_rank(6)
	_run.skills = { &"haggler": 2 }
	assert_eq(Skills.upgrade(_run, &"haggler"), Skills.Result.RANK_TOO_LOW)
	_set_cred_rank(7)
	assert_eq(Skills.upgrade(_run, &"haggler"), Skills.Result.OK)
	assert_eq(Skills.rank_of(_run, &"haggler"), 3)


func test_upgrades_stop_at_max_rank() -> void:
	_set_cred_rank(StreetCred.max_rank())
	for _step in Skills.max_rank():
		assert_eq(Skills.upgrade(_run, &"pack_mule"), Skills.Result.OK)
	assert_eq(Skills.upgrade(_run, &"pack_mule"), Skills.Result.MAX_RANK)
	assert_eq(Skills.rank_of(_run, &"pack_mule"), 3)
	assert_eq(Skills.points_spent(_run), 3)


func test_unknown_skills_are_rejected() -> void:
	_set_cred_rank(StreetCred.max_rank())
	assert_eq(Skills.upgrade(_run, &"lockpick"), Skills.Result.UNKNOWN)
	assert_eq(Skills.rank_of(_run, &"lockpick"), 0)
	assert_eq(Skills.display_name(&"lockpick"), "")
	assert_true(_run.skills.is_empty())


func test_unknown_stored_skills_are_ignored() -> void:
	_set_cred_rank(3)
	_run.skills = { &"lockpick": 2 }
	assert_eq(Skills.points_spent(_run), 0)
	assert_eq(Skills.points_free(_run), 2)


func test_ranks_stored_above_max_read_as_max() -> void:
	_set_cred_rank(StreetCred.max_rank())
	_run.skills = { &"haggler": 7 }
	assert_eq(Skills.rank_of(_run, &"haggler"), 3)
	assert_eq(Skills.points_spent(_run), 3)
	assert_eq(Skills.check_upgrade(_run, &"haggler"), Skills.Result.MAX_RANK)
	assert_almost_eq(Skills.buy_discount(_run), 0.10, 0.0001)


func test_negative_stored_ranks_read_as_zero() -> void:
	_run.skills = { &"muscle": -2 }
	assert_eq(Skills.rank_of(_run, &"muscle"), 0)
	assert_eq(Skills.points_spent(_run), 0)
	assert_almost_eq(Skills.fight_bonus(_run), 0.0, 0.0001)


func test_respec_cost_scales_with_cred_rank() -> void:
	_set_cred_rank(1)
	assert_eq(Skills.respec_cost(_run), 5000)
	_set_cred_rank(6)
	assert_eq(Skills.respec_cost(_run), 30000)


func test_respec_needs_spent_points() -> void:
	_set_cred_rank(5)
	assert_eq(Skills.check_respec(_run), Skills.Result.NOTHING_TO_RESET)
	assert_eq(Skills.respec(_run), Skills.Result.NOTHING_TO_RESET)
	assert_eq(_run.cash, 100000)


func test_respec_needs_the_cash() -> void:
	_set_cred_rank(5)
	_run.skills = { &"haggler": 1 }
	_run.cash = Skills.respec_cost(_run) - 1
	assert_eq(Skills.respec(_run), Skills.Result.NOT_ENOUGH_CASH)
	assert_eq(Skills.rank_of(_run, &"haggler"), 1)
	assert_eq(_run.cash, Skills.respec_cost(_run) - 1)


func test_respec_pays_and_refunds_every_point() -> void:
	_set_cred_rank(StreetCred.max_rank())
	_run.skills = { &"haggler": 3, &"wheelman": 2, &"smuggler": 1 }
	var cost := Skills.respec_cost(_run)
	assert_eq(Skills.respec(_run), Skills.Result.OK)
	assert_eq(_run.cash, 100000 - cost)
	assert_true(_run.skills.is_empty())
	assert_eq(Skills.points_free(_run), Skills.points_earned(_run))


func test_getters_are_neutral_when_nothing_is_learned() -> void:
	assert_almost_eq(Skills.buy_discount(_run), 0.0, 0.0001)
	assert_eq(Skills.capacity_bonus(_run), 0)
	assert_eq(Skills.extra_cooling(_run), 0)
	assert_almost_eq(Skills.escape_bonus(_run), 0.0, 0.0001)
	assert_almost_eq(Skills.fight_bonus(_run), 0.0, 0.0001)
	assert_almost_eq(Skills.crate_pay_bonus(_run), 0.0, 0.0001)
	assert_almost_eq(Skills.crate_risk_factor(_run), 1.0, 0.0001)


func test_getters_at_rank_one() -> void:
	_run.skills = { &"haggler": 1, &"pack_mule": 1, &"cool_head": 1, &"wheelman": 1, &"muscle": 1, &"smuggler": 1 }
	assert_almost_eq(Skills.buy_discount(_run), 0.03, 0.0001)
	assert_eq(Skills.capacity_bonus(_run), 10)
	assert_eq(Skills.extra_cooling(_run), 1)
	assert_almost_eq(Skills.escape_bonus(_run), 0.05, 0.0001)
	assert_almost_eq(Skills.fight_bonus(_run), 0.05, 0.0001)
	assert_almost_eq(Skills.crate_pay_bonus(_run), 0.10, 0.0001)
	assert_almost_eq(Skills.crate_risk_factor(_run), 0.85, 0.0001)


func test_getters_at_rank_two() -> void:
	_run.skills = { &"haggler": 2, &"pack_mule": 2, &"cool_head": 2, &"wheelman": 2, &"muscle": 2, &"smuggler": 2 }
	assert_almost_eq(Skills.buy_discount(_run), 0.06, 0.0001)
	assert_eq(Skills.capacity_bonus(_run), 20)
	assert_eq(Skills.extra_cooling(_run), 2)
	assert_almost_eq(Skills.escape_bonus(_run), 0.10, 0.0001)
	assert_almost_eq(Skills.fight_bonus(_run), 0.10, 0.0001)
	assert_almost_eq(Skills.crate_pay_bonus(_run), 0.20, 0.0001)
	assert_almost_eq(Skills.crate_risk_factor(_run), 0.70, 0.0001)


func test_getters_at_rank_three() -> void:
	_run.skills = { &"haggler": 3, &"pack_mule": 3, &"cool_head": 3, &"wheelman": 3, &"muscle": 3, &"smuggler": 3 }
	assert_almost_eq(Skills.buy_discount(_run), 0.10, 0.0001)
	assert_eq(Skills.capacity_bonus(_run), 35)
	assert_eq(Skills.extra_cooling(_run), 3)
	assert_almost_eq(Skills.escape_bonus(_run), 0.15, 0.0001)
	assert_almost_eq(Skills.fight_bonus(_run), 0.15, 0.0001)
	assert_almost_eq(Skills.crate_pay_bonus(_run), 0.30, 0.0001)
	assert_almost_eq(Skills.crate_risk_factor(_run), 0.55, 0.0001)


func test_one_skill_does_not_leak_into_another() -> void:
	_run.skills = { &"haggler": 3 }
	assert_eq(Skills.capacity_bonus(_run), 0)
	assert_almost_eq(Skills.crate_risk_factor(_run), 1.0, 0.0001)


func test_skills_survive_a_save() -> void:
	_set_cred_rank(StreetCred.max_rank())
	_run.skills = { &"haggler": 2, &"smuggler": 1 }
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(_run.to_dict())))
	assert_eq(Skills.rank_of(restored, &"haggler"), 2)
	assert_eq(Skills.rank_of(restored, &"smuggler"), 1)
	assert_eq(Skills.points_free(restored), 6)
