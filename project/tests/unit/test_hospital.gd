extends GutTest

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	_run.cash = 100000


func _wound(tier: Army.Tier, amount: int) -> void:
	Army.add(_run, tier, Army.State.WOUNDED, amount)


func test_healing_covers_everyone_it_can_pay_for() -> void:
	_wound(Army.Tier.BLACK_HAND, 50)
	_wound(Army.Tier.GUARDS, 100)
	_wound(Army.Tier.LUNATICS, 100)
	var expected := 750 + 200 + 50
	assert_eq(Hospital.estimate(_run), expected)
	assert_eq(Hospital.heal(_run), { "healed": 250, "paid": expected })
	assert_eq(Army.wounded(_run), 0)
	assert_eq(_run.cash, 100000 - expected)


func test_a_short_purse_heals_the_black_hand_first() -> void:
	_wound(Army.Tier.BLACK_HAND, 20)
	_wound(Army.Tier.GUARDS, 30)
	_run.cash = 167
	assert_eq(Hospital.heal(_run), { "healed": 12, "paid": 167 })
	assert_eq(Army.count(_run, Army.Tier.BLACK_HAND, Army.State.WOUNDED), 9)
	assert_eq(Army.count(_run, Army.Tier.GUARDS, Army.State.WOUNDED), 29)


func test_a_full_hospital_turns_the_wounded_into_dead() -> void:
	_wound(Army.Tier.LUNATICS, Hospital.beds(_run) - 15)
	var losses := {
		Army.Tier.LUNATICS: { "dead": 5, "wounded": 20 },
		Army.Tier.BLACK_HAND: { "dead": 0, "wounded": 10 },
	}
	Hospital.admit(_run, losses)
	assert_eq(losses[Army.Tier.BLACK_HAND], { "dead": 0, "wounded": 10 }, "the Black Hand get beds first")
	assert_eq(losses[Army.Tier.LUNATICS], { "dead": 20, "wounded": 5 })


func test_upgrades_add_beds_until_fully_built() -> void:
	assert_eq(Hospital.beds(_run), 25000)
	_run.cash = 600000
	assert_eq(Hospital.upgrade(_run), Hospital.Result.OK)
	assert_eq(Hospital.beds(_run), 50000)
	assert_eq(_run.cash, 450000)
	assert_eq(Hospital.upgrade(_run), Hospital.Result.NOT_ENOUGH_CASH)
	_run.hospital_level = Hospital.LEVELS.size() - 1
	assert_eq(Hospital.beds(_run), 300000)
	assert_eq(Hospital.upgrade_price(_run), -1)
	assert_eq(Hospital.upgrade(_run), Hospital.Result.MAX_LEVEL)
