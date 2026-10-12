extends GutTest

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	_run.cash = 50000
	Corners.take(_run, Corners.MAMA_LIN)
	Story.mark(_run, Armory.UNLOCK_FLAG)


func _enlist(tier: Army.Tier, amount: int) -> void:
	Army.add(_run, tier, Army.State.ACTIVE, amount)


func test_the_outfit_starts_small_and_split_mostly_lunatics() -> void:
	assert_eq(Army.capacity(_run), 1000)
	assert_eq(Army.deploy_cap(_run), 300)
	assert_eq(Army.slots(_run, Army.Tier.LUNATICS), 800)
	assert_eq(Army.slots(_run, Army.Tier.GUARDS), 200)
	assert_eq(Army.slots(_run, Army.Tier.BLACK_HAND), 0)
	assert_eq(Army.vacancies(_run, Army.Tier.GUARDS), 200)


func test_an_expansion_is_bought_with_cash_and_its_slots_go_to_the_lunatics() -> void:
	assert_eq(Army.expand(_run), Army.Result.OK)
	assert_eq(_run.cash, 50000 - 25000)
	assert_eq(Army.capacity(_run), 3000)
	assert_eq(Army.deploy_cap(_run), 1000)
	assert_eq(Army.slots(_run, Army.Tier.LUNATICS), 2800)
	assert_eq(Army.expand(_run), Army.Result.NOT_ENOUGH_CASH)
	_run.army_level = Army.EXPANSIONS.size() - 1
	assert_eq(Army.expansion_price(_run), -1)
	assert_eq(Army.expand(_run), Army.Result.MAX_LEVEL)


func test_the_split_never_goes_past_capacity() -> void:
	Story.mark(_run, War.VEX_FELL)
	assert_eq(Army.set_slots(_run, Army.Tier.BLACK_HAND, 500), 0, "every slot is already split")
	Army.set_slots(_run, Army.Tier.LUNATICS, 400)
	assert_eq(Army.set_slots(_run, Army.Tier.BLACK_HAND, 500), 400)
	assert_eq(Army.slots_used(_run), Army.capacity(_run))
	assert_eq(Army.set_slots(_run, Army.Tier.GUARDS, -5), 0)


func test_making_room_takes_lunatic_slots_first() -> void:
	Army.make_room(_run, Army.Tier.BLACK_HAND, 50)
	assert_eq(Army.slots(_run, Army.Tier.BLACK_HAND), 50)
	assert_eq(Army.slots(_run, Army.Tier.LUNATICS), 750)
	assert_eq(Army.slots(_run, Army.Tier.GUARDS), 200)
	Army.set_slots(_run, Army.Tier.LUNATICS, 0)
	Army.make_room(_run, Army.Tier.BLACK_HAND, 1000)
	assert_eq(Army.slots(_run, Army.Tier.BLACK_HAND), 1000)
	assert_eq(Army.slots(_run, Army.Tier.GUARDS), 0)


func test_every_living_man_is_ready_or_wounded() -> void:
	_enlist(Army.Tier.LUNATICS, 10)
	Army.add(_run, Army.Tier.GUARDS, Army.State.WOUNDED, 3)
	assert_eq(Army.total(_run), 13)
	assert_eq(Army.total(_run, Army.Tier.GUARDS), 3)
	assert_eq(Army.active(_run), 10)
	assert_eq(Army.wounded(_run), 3)
	assert_eq(Army.vacancies(_run, Army.Tier.GUARDS), 197, "the wounded keep their slots")


func test_deployment_sends_the_best_first_up_to_the_cap() -> void:
	_enlist(Army.Tier.LUNATICS, 400)
	_enlist(Army.Tier.GUARDS, 100)
	_enlist(Army.Tier.BLACK_HAND, 50)
	var sent := Army.deployment(_run)
	assert_eq(sent, { Army.Tier.BLACK_HAND: 50, Army.Tier.GUARDS: 100, Army.Tier.LUNATICS: 150 })
	assert_eq(Army.deployed_count(Army.deployment(_run, 80)), 80)
	assert_eq(Army.deployment(_run, -1, false), { Army.Tier.GUARDS: 100, Army.Tier.LUNATICS: 200 }, "the Black Hand can stay back")


func test_a_picked_crew_is_held_to_fit_men_and_the_cap() -> void:
	_enlist(Army.Tier.LUNATICS, 400)
	_enlist(Army.Tier.GUARDS, 100)
	_enlist(Army.Tier.BLACK_HAND, 50)
	var wanted := { Army.Tier.LUNATICS: 120, Army.Tier.BLACK_HAND: 0 }
	assert_eq(Army.picked(_run, wanted), { Army.Tier.LUNATICS: 120 }, "tiers left at zero stay home")
	wanted = { Army.Tier.GUARDS: 500, Army.Tier.LUNATICS: 400 }
	assert_eq(Army.picked(_run, wanted), { Army.Tier.GUARDS: 100, Army.Tier.LUNATICS: 200 })


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
	_run.army_split = { Army.Tier.LUNATICS: 1500, Army.Tier.GUARDS: 1000, Army.Tier.BLACK_HAND: 500 }
	_run.hospital_level = 2
	var loaded := RunState.from_dict(JSON.parse_string(JSON.stringify(_run.to_dict())))
	assert_eq(Army.count(loaded, Army.Tier.GUARDS), 7)
	assert_eq(Army.count(loaded, Army.Tier.LUNATICS, Army.State.WOUNDED), 3)
	assert_eq(Army.fallen(loaded), 4)
	assert_eq(Army.capacity(loaded), 3000)
	assert_eq(Army.slots(loaded, Army.Tier.BLACK_HAND), 500)
	assert_eq(loaded.hospital_level, 2)


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


func test_the_black_hand_get_no_slots_until_vex_falls() -> void:
	Army.set_slots(_run, Army.Tier.LUNATICS, 0)
	assert_eq(Army.set_slots(_run, Army.Tier.BLACK_HAND, 500), 0)
	Story.mark(_run, War.VEX_FELL)
	assert_eq(Army.set_slots(_run, Army.Tier.BLACK_HAND, 500), 500)


func test_men_are_priced_per_hundred() -> void:
	assert_eq(Army.price_of(250, 100), 250)
	assert_eq(Army.price_of(250, 1), 3, "a part of a hundred is rounded up")
	assert_eq(Army.men_for(1500, 3000), 200)


func test_sanitize_drops_unknown_tiers_and_states() -> void:
	var clean := Army.sanitize({ "0": { "0": 5, "9": 3 }, "7": { "0": 1 }, "1": { "1": -2 } })
	assert_eq(clean, { Army.Tier.LUNATICS: { Army.State.ACTIVE: 5 } })
