extends GutTest

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	_run.cash = 100000


func _wound(tier: Army.Tier, amount: int) -> void:
	Army.add(_run, tier, Army.State.WOUNDED, amount)


func test_beds_heal_the_black_hand_first() -> void:
	_wound(Army.Tier.BLACK_HAND, 50)
	_wound(Army.Tier.GUARDS, 100)
	_wound(Army.Tier.LUNATICS, 100)
	var expected := 2000 + 500 + 50
	assert_eq(Hospital.estimate(_run), expected)
	assert_eq(Hospital.heal(_run), { "healed": 200, "paid": expected })
	assert_eq(Army.count(_run, Army.Tier.BLACK_HAND), 50)
	assert_eq(Army.count(_run, Army.Tier.GUARDS), 100)
	assert_eq(Army.count(_run, Army.Tier.LUNATICS, Army.State.WOUNDED), 50, "no bed left for them")
	assert_eq(_run.cash, 100000 - expected)


func test_a_short_purse_leaves_men_waiting() -> void:
	_wound(Army.Tier.BLACK_HAND, 20)
	_wound(Army.Tier.GUARDS, 30)
	_run.cash = 450
	assert_eq(Hospital.heal(_run), { "healed": 13, "paid": 450 })
	assert_eq(Army.count(_run, Army.Tier.BLACK_HAND, Army.State.WOUNDED), 9)
	assert_eq(Army.count(_run, Army.Tier.GUARDS, Army.State.WOUNDED), 28)


func test_upgrades_add_beds_until_fully_built() -> void:
	assert_eq(Hospital.beds(_run), 200)
	assert_eq(Hospital.upgrade(_run), Hospital.Result.OK)
	assert_eq(Hospital.beds(_run), 600)
	assert_eq(_run.cash, 100000 - 15000)
	_run.cash = 0
	assert_eq(Hospital.upgrade(_run), Hospital.Result.NOT_ENOUGH_CASH)
	_run.hospital_level = Hospital.LEVELS.size() - 1
	assert_eq(Hospital.upgrade_price(_run), -1)
	assert_eq(Hospital.upgrade(_run), Hospital.Result.MAX_LEVEL)
