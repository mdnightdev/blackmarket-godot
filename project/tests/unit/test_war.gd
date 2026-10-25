extends GutTest

const STEPS: StringName = &"tran_steps"
const LANTERN: StringName = &"lantern"

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	_run.price_seed = 3131
	_run.district_id = Corners.HOME
	_run.cash = 50000
	_run.debt = 0
	_run.career = true
	Corners.take(_run, Corners.MAMA_LIN)
	Story.mark(_run, Armory.UNLOCK_FLAG)


func _enlist(tier: Army.Tier, amount: int) -> void:
	Army.add(_run, tier, Army.State.ACTIVE, amount)


func test_war_opens_with_mama_lins_corner_and_closes_when_vex_falls() -> void:
	assert_true(War.is_open(_run))
	assert_false(War.is_open(RunState.new()))
	Story.mark(_run, War.VEX_FELL)
	assert_false(War.is_open(_run))


func test_an_attack_needs_men() -> void:
	var steps := Corners.find(STEPS)
	assert_false(War.can_attack(_run, steps))
	assert_true(War.attack(_run, STEPS, Army.deployment(_run), 0.5, 0.5).is_empty())
	_enlist(Army.Tier.LUNATICS, 1)
	assert_true(War.can_attack(_run, steps))
	assert_false(War.can_attack(_run, Corners.find(Corners.MAMA_LIN)), "already held")


func test_the_stronghold_is_harder_to_take() -> void:
	var lantern := Corners.find(LANTERN)
	assert_almost_eq(War.enemy_power(_run, lantern), lantern.defenders * Rivals.SKILL * War.STRONGHOLD_FACTOR, 0.001)


func test_the_starting_outfit_cannot_take_a_corner_alone() -> void:
	_enlist(Army.Tier.GUARDS, 200)
	_enlist(Army.Tier.LUNATICS, 800)
	_run.armory = { Armory.Grade.HANDGUN: 200, Armory.Grade.BLADE: 200 }
	assert_lt(Army.strength(_run) * (1.0 + War.LUCK), War.enemy_power(_run, Corners.find(STEPS)))


func test_a_won_attack_takes_the_corner_and_counts_dead_and_wounded() -> void:
	_run.army_level = 1
	_enlist(Army.Tier.GUARDS, 400)
	_run.armory = { Armory.Grade.RIFLE: 400 }
	var result := War.attack(_run, STEPS, Army.deployment(_run), 0.5, 0.5)
	assert_true(result.won)
	assert_false(result.ended)
	assert_true(Corners.holds(_run, STEPS))
	assert_eq(result.dead, 13)
	assert_eq(result.wounded, 35)
	assert_eq(Army.count(_run, Army.Tier.GUARDS), 352)
	assert_eq(Army.count(_run, Army.Tier.GUARDS, Army.State.WOUNDED), 35)
	assert_eq(Army.fallen(_run, Army.Tier.GUARDS), 13)
	assert_eq(Armory.count(_run, Armory.Grade.RIFLE), 387, "the dead take their weapons, the wounded keep theirs")
	assert_eq(War.defenders(_run, Corners.find(STEPS)), 0)


func test_a_lost_attack_bleeds_both_sides_and_brings_rabbits_unit() -> void:
	_enlist(Army.Tier.LUNATICS, 200)
	var result := War.attack(_run, STEPS, Army.deployment(_run), 0.5, 0.5)
	assert_false(result.won)
	assert_false(Corners.holds(_run, STEPS))
	assert_eq(result.dead, 40)
	assert_eq(result.wounded, 40)
	assert_eq(Army.count(_run, Army.Tier.LUNATICS), 120)
	assert_eq(Army.total(_run), 160, "the dead leave the outfit, the wounded stay in it")
	assert_eq(_run.heat, War.ATTACK_HEAT, "a street fight is loud even when it is lost")
	assert_eq(War.defenders(_run, Corners.find(STEPS)), 640)
	assert_true(War.unit_on_offer(_run))


func test_a_smaller_force_risks_fewer_men() -> void:
	_enlist(Army.Tier.LUNATICS, 300)
	var half := Army.deployment(_run, 150)
	var result := War.attack(_run, STEPS, half, 0.5, 0.5)
	assert_eq(Army.deployed_count(result.deployed), 150)
	assert_true(int(result.dead) + int(result.wounded) <= 150)
	assert_eq(Army.count(_run, Army.Tier.LUNATICS), 300 - int(result.dead) - int(result.wounded))


func test_rabbits_unit_joins_as_the_black_hand() -> void:
	assert_false(War.hire_unit(_run), "only after a loss")
	Story.mark(_run, War.LOST_ONCE)
	assert_true(War.hire_unit(_run))
	assert_eq(_run.cash, 50000 - War.RABBIT_UNIT_PRICE)
	assert_eq(Army.count(_run, Army.Tier.BLACK_HAND), War.RABBIT_UNIT_SIZE)
	assert_false(War.unit_on_offer(_run))
	assert_almost_eq(Army.strength(_run), War.RABBIT_UNIT_SIZE * Army.BLACK_HAND_POWER, 0.001)
	assert_true(War.can_attack(_run, Corners.find(STEPS)), "the unit can attack on its own")


func test_rabbits_unit_is_paid_up_front() -> void:
	Story.mark(_run, War.LOST_ONCE)
	_run.cash = War.RABBIT_UNIT_PRICE - 1
	assert_false(War.hire_unit(_run))
	assert_eq(Army.count(_run, Army.Tier.BLACK_HAND), 0)


func test_men_without_a_bed_die_of_their_wounds() -> void:
	_run.army_level = 1
	_enlist(Army.Tier.GUARDS, 400)
	_run.armory = { Armory.Grade.RIFLE: 400 }
	Army.add(_run, Army.Tier.LUNATICS, Army.State.WOUNDED, Hospital.beds(_run) - 10)
	var result := War.attack(_run, STEPS, Army.deployment(_run), 0.5, 0.5)
	assert_eq(result.wounded, 10, "only ten beds were free")
	assert_eq(result.dead, 13 + 25)
	assert_eq(Army.fallen(_run, Army.Tier.GUARDS), 38)
	assert_eq(Hospital.free_beds(_run), 0)


func test_taking_the_last_corner_ends_the_war_and_opens_act_two() -> void:
	for corner in Corners.of(Corners.HOME):
		if corner.id != LANTERN:
			Corners.take(_run, corner.id)
	Story.mark(_run, War.LOST_ONCE)
	Story.mark(_run, War.UNIT_HIRED)
	_run.army_level = 1
	_enlist(Army.Tier.BLACK_HAND, War.RABBIT_UNIT_SIZE)
	_enlist(Army.Tier.GUARDS, 950)
	_run.armory = { Armory.Grade.RIFLE: 950 }
	var result := War.attack(_run, LANTERN, Army.deployment(_run), 0.5, 0.5)
	assert_true(result.won)
	assert_true(result.ended)
	assert_true(Campaign.is_act_two(_run))
	assert_true(Story.has(_run, Moreau.WATCHLIST))
	assert_false(_run.gangs_gone.has(War.VEX_GANG), "Vex keeps her other districts")
	assert_eq(Turf.holder(_run, &"slums"), Turf.Holder.GANG)
	assert_false(Story.has(_run, War.BOOK_BURNED))


func test_on_the_vex_branch_the_book_burns_with_her() -> void:
	_run.lender = Loan.VEX_LENDER
	_run.debt = 40000
	_run.career = false
	War.end_war(_run)
	assert_true(Story.has(_run, War.BOOK_BURNED))
	assert_eq(_run.debt, 0)
	assert_true(_run.career)


func test_defenders_survive_a_save() -> void:
	_run.corner_defenders = { "tran_steps": 120 }
	var loaded := RunState.from_dict(_run.to_dict())
	assert_eq(loaded.corner_defenders, { "tran_steps": 120 })


func test_sanitize_defenders_drops_unknown_corners_and_clamps() -> void:
	var clean := War.sanitize_defenders({ "tran_steps": 99999, "nowhere": 5, "fish_row": -3 })
	assert_eq(clean, { "tran_steps": Rivals.max_garrison(Corners.find(STEPS)), "fish_row": 0 })


func _open_act_two() -> void:
	Corners.take_all(_run, Corners.HOME)
	Story.mark(_run, War.VEX_FELL)


func test_other_districts_open_to_attack_in_act_two() -> void:
	_enlist(Army.Tier.LUNATICS, 10)
	var slums_corner := Corners.find(&"steam_grate_alley")
	var bay := Corners.find(&"loading_bay")
	assert_false(War.can_attack(_run, slums_corner), "Act 1 is only about Old Market")
	assert_false(War.can_attack(_run, bay), "Act 1 is only about Old Market")
	_open_act_two()
	assert_true(War.can_attack(_run, slums_corner), "The Slums opens immediately in Act 2")
	assert_false(War.can_attack(_run, bay), "Warehouse Row requires holding The Slums first")
	Corners.take_all(_run, &"slums")
	assert_true(War.can_attack(_run, bay), "Warehouse Row opens once The Slums is held")
	assert_false(War.is_target(_run, Corners.find(&"iron_gate_lane")), "the heights are out of reach")
	assert_false(War.is_target(_run, Corners.find(STEPS)), "Old Market is already the player's")


func test_a_rival_fights_with_what_it_carries() -> void:
	_open_act_two()
	var bay := Corners.find(&"loading_bay")
	assert_almost_eq(War.enemy_power(_run, bay), bay.defenders * Armory.power_of(Armory.Grade.HANDGUN) * Rivals.SKILL, 0.001)
	_run.rivals[&"jackal"] = { "gear": Armory.Grade.RIFLE }
	assert_almost_eq(War.enemy_power(_run, bay), bay.defenders * Armory.power_of(Armory.Grade.RIFLE) * Rivals.SKILL, 0.001)


func test_taking_a_rivals_last_corner_drives_it_out() -> void:
	_open_act_two()
	var jackal := Content.gang(&"jackal")
	for corner in Rivals.corners(_run, jackal):
		Corners.take(_run, corner.id)
	Corners.lose(_run, &"loading_bay")
	_run.army_level = 2
	_enlist(Army.Tier.GUARDS, 2000)
	_run.armory = { Armory.Grade.RIFLE: 2000 }
	_run.scouted = { "loading_bay": { "low": 1, "high": 2, "gear": 2, "day": _run.day, "seen": false } }
	var result := War.attack(_run, &"loading_bay", Army.deployment(_run), 0.5, 0.5)
	assert_true(result.won)
	assert_false(result.ended)
	assert_true(Gangs.is_gone(_run, jackal))
	assert_eq(_run.pending_encounter.type, Turf.VICTORY)
	assert_false(_run.scouted.has("loading_bay"), "a taken corner needs no report")


func test_posted_garrison_draws_from_reserve_and_gains_cover_multiplier() -> void:
	_enlist(Army.Tier.GUARDS, 150)
	_run.armory[Armory.Grade.BLADE] = 150
	assert_eq(Army.reserve(_run), 150)
	Corners.take(_run, Corners.MAMA_LIN)
	assert_true(Corners.post_garrison(_run, Corners.MAMA_LIN, 60))
	assert_eq(Corners.garrison(_run, Corners.MAMA_LIN), 60)
	assert_eq(Army.reserve(_run), 90, "posted men are committed to the corner")
	assert_eq(Army.deployed_count(Army.deployment(_run)), 90)
	var mama := Corners.find(Corners.MAMA_LIN)
	assert_gt(Corners.garrison_power(_run, mama), 60 * Army.SKILL[Army.Tier.GUARDS]
	 * Corners.GARRISON_FACTOR)
	Corners.take(_run, LANTERN)
	assert_true(Corners.post_garrison(_run, LANTERN, 50))
	assert_gt(Corners.garrison_power(_run, Corners.find(LANTERN)), Corners.garrison_power(_run, mama), "stronghold cover multiplier is higher")


func test_live_battle_reconcile_flips_loss_into_victory_on_enemy_rout() -> void:
	_enlist(Army.Tier.LUNATICS, 200)
	var result := War.attack(_run, STEPS, Army.deployment(_run), 0.5, 0.5)
	assert_false(result.won)
	assert_false(Corners.holds(_run, STEPS))
	var player_side := BattleSide.new()
	player_side.survivors = 155
	var enemy_side := BattleSide.new()
	enemy_side.survivors = 80
	War.reconcile_live_battle(_run, result, player_side, enemy_side)
	assert_true(result.won)
	assert_true(Corners.holds(_run, STEPS))
	assert_eq(War.defenders(_run, Corners.find(STEPS)), 0)


func test_retreating_survivors_reinforce_other_district_corners_in_act_two() -> void:
	_open_act_two()
	Corners.take_all(_run, &"slums")
	_run.army_level = 2
	_enlist(Army.Tier.GUARDS, 1800)
	_run.armory = { Armory.Grade.RIFLE: 1800 }
	var rollup := Corners.find(&"roll_up_row")
	var scrap := Corners.find(&"scrap_yard")
	var lockup := Corners.find(&"jackal_lockup")
	var before := War.defenders(_run, rollup) + War.defenders(_run, scrap) + War.defenders(_run, lockup)
	var result := War.attack(_run, &"loading_bay", Army.deployment(_run), 0.5, 0.5)
	assert_true(result.won)
	var after := War.defenders(_run, rollup) + War.defenders(_run, scrap) + War.defenders(_run, lockup)
	assert_gt(after, before, "survivors fall back to nearby gang corners")

