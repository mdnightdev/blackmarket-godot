extends GutTest

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	_run.cash = 100000
	Story.mark(_run, Corners.RABBIT_JOINED)


func _enlist(tier: Army.Tier, amount: int) -> void:
	Army.add(_run, tier, Army.State.ACTIVE, amount)


func test_sessions_run_four_mornings_a_week() -> void:
	var sessions := 0
	for day in range(1, 8):
		if Gym.is_session_day(day):
			sessions += 1
	assert_eq(sessions, 4)
	_run.day = 1
	assert_eq(Gym.next_session_day(_run), 3)


func test_a_session_heals_then_fills_every_tier_to_its_slots() -> void:
	Army.add(_run, Army.Tier.GUARDS, Army.State.WOUNDED, 30)
	_enlist(Army.Tier.LUNATICS, 20)
	var expected := 150 + 2550 + 1950
	assert_eq(Gym.estimate(_run), expected)
	var result := Gym.session(_run)
	assert_eq(result.healed, 30)
	assert_eq(result.replaced, { Army.Tier.GUARDS: 170, Army.Tier.LUNATICS: 780 })
	assert_eq(result.paid, expected)
	assert_eq(result.vacancies, 0)
	assert_eq(_run.cash, 100000 - expected)
	assert_eq(Army.count(_run, Army.Tier.GUARDS), 200)
	assert_eq(Army.count(_run, Army.Tier.LUNATICS), 800)
	assert_eq(Gym.estimate(_run), 0)


func test_a_short_purse_fills_the_better_tiers_first() -> void:
	_run.cash = 1000
	var result := Gym.session(_run)
	assert_eq(result.replaced, { Army.Tier.GUARDS: 66, Army.Tier.LUNATICS: 4 })
	assert_eq(result.vacancies, 930)
	assert_eq(_run.cash, 0)


func test_men_over_their_slots_are_let_go() -> void:
	_enlist(Army.Tier.LUNATICS, 300)
	Army.set_slots(_run, Army.Tier.LUNATICS, 100)
	var result := Gym.session(_run)
	assert_eq(result.released, 200)
	assert_eq(Army.count(_run, Army.Tier.LUNATICS), 100)


func test_the_morning_notice_comes_only_on_session_days() -> void:
	_run.day = 2
	assert_true(Gym.morning(_run).is_empty())
	_run.day = 3
	var notices := Gym.morning(_run)
	assert_eq(notices.size(), 1)
	assert_string_contains(str(notices[0].line), "1000 new men")
	assert_true(Gym.morning(_run).is_empty(), "nothing left to do")


func test_nothing_happens_before_rabbit_joins() -> void:
	var run := RunState.new()
	run.day = 3
	assert_false(Gym.is_open(run))
	assert_true(Gym.morning(run).is_empty())
	assert_eq(Army.total(run), 0)
