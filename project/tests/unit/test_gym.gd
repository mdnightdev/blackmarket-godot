extends GutTest

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	_run.cash = 100000
	_run.day = 1
	Story.mark(_run, Corners.RABBIT_JOINED)


func _enlist(tier: Army.Tier, amount: int) -> void:
	Army.add(_run, tier, Army.State.ACTIVE, amount)


func test_lunatics_join_the_moment_they_are_paid_for() -> void:
	assert_eq(Gym.enroll(_run, Gym.Course.LUNATICS, 800), Gym.Result.OK)
	assert_eq(_run.cash, 100000 - 800)
	assert_eq(Army.count(_run, Army.Tier.LUNATICS), 800)


func test_guards_join_the_moment_they_are_paid_for() -> void:
	assert_eq(Gym.enroll(_run, Gym.Course.GUARDS, 300), Gym.Result.OK)
	assert_eq(_run.cash, 100000 - 1800)
	assert_eq(Army.count(_run, Army.Tier.GUARDS), 300)


func test_a_promotion_keeps_the_head_count_and_costs_less_than_new_guards() -> void:
	_enlist(Army.Tier.LUNATICS, 1000)
	assert_lt(Gym.price(Gym.Course.PROMOTION, 1000), Gym.price(Gym.Course.GUARDS, 1000))
	assert_eq(Gym.enroll(_run, Gym.Course.PROMOTION, 600), Gym.Result.OK)
	assert_eq(Army.count(_run, Army.Tier.LUNATICS), 400)
	assert_eq(Army.count(_run, Army.Tier.GUARDS), 600)
	assert_eq(Army.total(_run), 1000)


func test_a_promotion_needs_fit_lunatics() -> void:
	_enlist(Army.Tier.LUNATICS, 50)
	Army.add(_run, Army.Tier.LUNATICS, Army.State.WOUNDED, 100)
	assert_eq(Gym.most(_run, Gym.Course.PROMOTION), 50)
	assert_eq(Gym.enroll(_run, Gym.Course.PROMOTION, 51), Gym.Result.NOT_ENOUGH_MEN)


func test_cash_and_the_black_hand_lock_are_checked() -> void:
	_run.cash = 100
	assert_eq(Gym.most(_run, Gym.Course.LUNATICS), 100)
	assert_eq(Gym.enroll(_run, Gym.Course.LUNATICS, 101), Gym.Result.NOT_ENOUGH_CASH)
	assert_eq(Gym.enroll(_run, Gym.Course.LUNATICS, 0), Gym.Result.INVALID)
	_run.cash = 1000000
	assert_eq(Gym.enroll(_run, Gym.Course.BLACK_HAND, 10), Gym.Result.LOCKED)
	Story.mark(_run, War.VEX_FELL)
	assert_eq(Gym.enroll(_run, Gym.Course.BLACK_HAND, 10), Gym.Result.OK)
	assert_eq(Army.count(_run, Army.Tier.BLACK_HAND), 10)


func test_nothing_happens_before_rabbit_joins() -> void:
	var run := RunState.new()
	run.cash = 100000
	assert_false(Gym.is_open(run))
	assert_eq(Gym.enroll(run, Gym.Course.LUNATICS, 100), Gym.Result.CLOSED)


func test_men_still_training_in_an_old_save_join_on_load() -> void:
	_enlist(Army.Tier.GUARDS, 100)
	var data: Dictionary = JSON.parse_string(JSON.stringify(_run.to_dict()))
	data["training"] = [
		{ "tier": Army.Tier.GUARDS, "men": 250, "sessions": 2, "fresh": true },
		{ "tier": 9, "men": 5, "sessions": 1 },
		{ "tier": Army.Tier.LUNATICS, "men": 0, "sessions": 1 },
		"x",
	]
	var loaded := RunState.from_dict(data)
	assert_eq(Army.count(loaded, Army.Tier.GUARDS), 350)
	assert_eq(Army.count(loaded, Army.Tier.LUNATICS), 0)
