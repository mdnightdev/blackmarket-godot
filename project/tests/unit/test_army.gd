extends GutTest

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	_run.cash = 50000
	Corners.take(_run, Corners.MAMA_LIN)
	Story.mark(_run, Armory.UNLOCK_FLAG)


func _enlist(tier: Army.Tier, amount: int) -> void:
	Army.add(_run, tier, Army.State.ACTIVE, amount)


func test_the_outfit_starts_sending_a_thousand() -> void:
	assert_eq(Army.deploy_cap(_run), 1000)


func test_an_expansion_is_bought_with_cash() -> void:
	assert_eq(Army.expand(_run), Army.Result.OK)
	assert_eq(_run.cash, 50000 - 10000)
	assert_eq(Army.deploy_cap(_run), 5000)
	_run.cash = 1000
	assert_eq(Army.expand(_run), Army.Result.NOT_ENOUGH_CASH)
	_run.army_level = Army.EXPANSIONS.size() - 1
	assert_eq(Army.deploy_cap(_run), 120000)
	assert_eq(Army.expansion_price(_run), -1)
	assert_eq(Army.expand(_run), Army.Result.MAX_LEVEL)


func test_there_is_no_limit_on_men_kept() -> void:
	_enlist(Army.Tier.LUNATICS, 1000000)
	assert_eq(Army.total(_run), 1000000)


func test_every_living_man_is_ready_or_wounded() -> void:
	_enlist(Army.Tier.LUNATICS, 10)
	Army.add(_run, Army.Tier.GUARDS, Army.State.WOUNDED, 3)
	assert_eq(Army.total(_run), 13)
	assert_eq(Army.total(_run, Army.Tier.GUARDS), 3)
	assert_eq(Army.active(_run), 10)
	assert_eq(Army.wounded(_run), 3)


func test_deployment_sends_the_best_first_up_to_the_cap() -> void:
	_enlist(Army.Tier.LUNATICS, 2000)
	_enlist(Army.Tier.GUARDS, 100)
	_enlist(Army.Tier.BLACK_HAND, 50)
	var sent := Army.deployment(_run)
	assert_eq(sent, { Army.Tier.BLACK_HAND: 50, Army.Tier.GUARDS: 100, Army.Tier.LUNATICS: 850 })
	assert_eq(Army.deployed_count(Army.deployment(_run, 80)), 80)
	assert_eq(Army.deployment(_run, -1, false), { Army.Tier.GUARDS: 100, Army.Tier.LUNATICS: 900 }, "the Black Hand can stay back")


func test_a_picked_crew_is_held_to_fit_men_and_the_cap() -> void:
	_enlist(Army.Tier.LUNATICS, 2000)
	_enlist(Army.Tier.GUARDS, 100)
	_enlist(Army.Tier.BLACK_HAND, 50)
	var wanted := { Army.Tier.LUNATICS: 120, Army.Tier.BLACK_HAND: 0 }
	assert_eq(Army.picked(_run, wanted), { Army.Tier.LUNATICS: 120 }, "tiers left at zero stay home")
	wanted = { Army.Tier.GUARDS: 500, Army.Tier.LUNATICS: 2000 }
	assert_eq(Army.picked(_run, wanted), { Army.Tier.GUARDS: 100, Army.Tier.LUNATICS: 900 })


func test_guards_are_armed_before_lunatics_and_fight_harder() -> void:
	_enlist(Army.Tier.GUARDS, 10)
	_enlist(Army.Tier.LUNATICS, 20)
	_run.armory = { Armory.Grade.BLADE: 15, Armory.Grade.RIFLE: 10 }
	var sent := Army.deployment(_run)
	var carried := Army.issue(_run, sent)
	assert_eq(carried[Army.Tier.GUARDS][Armory.Grade.RIFLE], 10)
	assert_eq(carried[Army.Tier.LUNATICS][Armory.Grade.BLADE], 15)
	assert_eq(carried[Army.Tier.LUNATICS][Armory.Grade.NONE], 5)
	assert_almost_eq(Army.power(_run, sent), 10 * 2.4 * 2.5 + 15 * 1.0 + 5 * Armory.UNARMED_POWER, 0.001)


func test_elite_tiers_are_hit_less_and_die_less() -> void:
	var sent := { Army.Tier.BLACK_HAND: 10, Army.Tier.GUARDS: 10, Army.Tier.LUNATICS: 10 }
	var losses := Army.casualties(sent, 0.4, 0.5)
	assert_eq(losses[Army.Tier.LUNATICS], { "dead": 2, "wounded": 2 })
	assert_eq(losses[Army.Tier.GUARDS], { "dead": 1, "wounded": 1 })
	assert_eq(losses[Army.Tier.BLACK_HAND], { "dead": 0, "wounded": 1 })
	assert_eq(Army.sum_losses(losses, "dead"), 3)


func test_army_and_hospital_survive_a_save() -> void:
	_enlist(Army.Tier.GUARDS, 7)
	Army.add(_run, Army.Tier.LUNATICS, Army.State.WOUNDED, 3)
	_run.fallen = { Army.Tier.LUNATICS: 4 }
	_run.army_level = 1
	_run.hospital_level = 2
	var loaded := RunState.from_dict(JSON.parse_string(JSON.stringify(_run.to_dict())))
	assert_eq(Army.count(loaded, Army.Tier.GUARDS), 7)
	assert_eq(Army.count(loaded, Army.Tier.LUNATICS, Army.State.WOUNDED), 3)
	assert_eq(Army.fallen(loaded), 4)
	assert_eq(Army.deploy_cap(loaded), 5000)
	assert_eq(loaded.hospital_level, 2)


func test_old_saves_keep_every_man_and_start_the_hospital_at_its_new_base() -> void:
	_enlist(Army.Tier.LUNATICS, 782)
	var data: Dictionary = JSON.parse_string(JSON.stringify(_run.to_dict()))
	data.erase("hospital_size")
	data.erase("training")
	data["hospital_level"] = 5
	data["army_split"] = { "0": 350, "1": 650 }
	var loaded := RunState.from_dict(data)
	assert_eq(Army.count(loaded, Army.Tier.LUNATICS), 782)
	assert_eq(Hospital.beds(loaded), 25000)


func test_old_saves_turn_their_men_into_lunatics_and_the_unit_into_the_black_hand() -> void:
	var data := RunState.new().to_dict()
	data.erase("army")
	data.erase("war_scale")
	data["men"] = 25
	data["story_flags"] = [War.UNIT_HIRED]
	var loaded := RunState.from_dict(data)
	assert_eq(Army.count(loaded, Army.Tier.LUNATICS), 250)
	assert_eq(Army.count(loaded, Army.Tier.BLACK_HAND), War.RABBIT_UNIT_SIZE)


func test_saves_from_the_small_scale_are_multiplied_up() -> void:
	_enlist(Army.Tier.GUARDS, 7)
	_run.fallen = { Army.Tier.LUNATICS: 4 }
	_run.armory = { Armory.Grade.RIFLE: 12 }
	_run.corner_defenders = { "tran_steps": 30 }
	var data := _run.to_dict()
	data.erase("war_scale")
	var loaded := RunState.from_dict(JSON.parse_string(JSON.stringify(data)))
	assert_eq(Army.count(loaded, Army.Tier.GUARDS), 70)
	assert_eq(Army.fallen(loaded), 40)
	assert_eq(Armory.count(loaded, Armory.Grade.RIFLE), 120)
	assert_eq(int(loaded.corner_defenders["tran_steps"]), 300)


func test_men_are_priced_per_thousand() -> void:
	assert_eq(Army.price_of(2500, 1000), 2500)
	assert_eq(Army.price_of(2500, 1), 3, "a part of a thousand is rounded up")
	assert_eq(Army.men_for(15000, 3000), 200)


func test_sanitize_drops_unknown_tiers_and_states() -> void:
	var clean := Army.sanitize({ "0": { "0": 5, "9": 3 }, "7": { "0": 1 }, "1": { "1": -2 } })
	assert_eq(clean, { Army.Tier.LUNATICS: { Army.State.ACTIVE: 5 } })


func test_3factor_unit_stats_and_damage_mitigation_formula() -> void:
	var t1 := Army.unit_stats(Army.Tier.LUNATICS)
	var t2 := Army.unit_stats(Army.Tier.GUARDS)
	var t3 := Army.unit_stats(Army.Tier.BLACK_HAND)
	assert_lt(float(t1.defense), float(t2.defense))
	assert_lt(float(t2.defense), float(t3.defense))
	assert_lt(float(t1.hp), float(t2.hp))
	assert_lt(float(t2.hp), float(t3.hp))
	var dr := Army.damage_reduction(100.0, 100.0)
	assert_almost_eq(dr, 0.5, 0.001)
	var net := Army.net_damage_taken(1000.0, 100.0, 100.0)
	assert_almost_eq(net, 500.0, 0.001)
	var total_cas := Army.total_casualties_from_damage(500.0, 50.0)
	assert_eq(total_cas, 10)


func test_attacker_60_40_vs_defender_100_0_casualty_splits() -> void:
	var sent := { Army.Tier.GUARDS: 100 }
	var atk_losses := Army.split_casualties_by_role(sent, 50, false)
	assert_eq(int(atk_losses[Army.Tier.GUARDS].wounded), 30, "60% wounded on offensive march")
	assert_eq(int(atk_losses[Army.Tier.GUARDS].dead), 20, "40% dead on offensive march")
	var def_losses := Army.split_casualties_by_role(sent, 50, true)
	assert_eq(int(def_losses[Army.Tier.GUARDS].wounded), 50, "100% wounded on home/garrison defense")
	assert_eq(int(def_losses[Army.Tier.GUARDS].dead), 0, "0% outright battlefield death on defense")


func test_march_capacity_progression_and_enforcer_bonus() -> void:
	_run.street_cred = 0
	var rank1_cap := Army.march_capacity(_run)
	assert_gt(rank1_cap, 0)
	assert_lt(rank1_cap, Army.PRE_KINGPIN_MAX_DISPATCH)
	_run.street_cred = int(StreetCred.RANKS[StreetCred.max_rank() - 1].cred)
	assert_eq(StreetCred.rank(_run), StreetCred.max_rank())
	assert_eq(Army.march_capacity(_run), Army.KINGPIN_BASE_DISPATCH)
	for skill_id in Skills.ids():
		_run.skills[skill_id] = Skills.MAX_RANK
	assert_eq(Army.march_capacity(_run), Army.MAX_BASE_DISPATCH_CAP)
	assert_eq(Army.march_capacity(_run, War.RABBIT), Army.MAX_BASE_DISPATCH_CAP + Army.ENFORCER_CAPACITY_BONUS)
