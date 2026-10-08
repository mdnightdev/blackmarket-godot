extends GutTest


func test_contests_are_even_at_no_edge_and_lopsided_at_a_big_one() -> void:
	assert_almost_eq(Odds.contest(0.0), 0.5, 0.0001)
	assert_gt(Odds.contest(0.1), 0.6)
	assert_lt(Odds.contest(-0.1), 0.4)
	assert_eq(Odds.contest(10.0), Odds.MAX_CHANCE, "never a sure thing")
	assert_eq(Odds.contest(-10.0), Odds.MIN_CHANCE, "never hopeless")


func test_bell_rolls_stay_in_bounds_and_bunch_near_the_usual_value() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var near := 0
	var extreme := 0
	for attempt in 2000:
		var value := Odds.bell(rng, 0.02, 0.05, 0.12)
		assert_between(value, 0.02, 0.12)
		if absf(value - 0.05) < 0.02:
			near += 1
		if value > 0.11:
			extreme += 1
	assert_gt(near, 1000, "most rolls land close to the usual value")
	assert_lt(extreme, 60, "the cap is rare")


func test_the_same_phase_and_purpose_give_the_same_roll() -> void:
	var run := RunState.new()
	run.price_seed = 5
	var first := Odds.rng_for(run, &"bribe").randf()
	assert_eq(Odds.rng_for(run, &"bribe").randf(), first)
	assert_ne(Odds.rng_for(run, &"toll").randf(), first)
	Calendar.advance_phase(run)
	assert_ne(Odds.rng_for(run, &"bribe").randf(), first)


func test_readings_never_show_numbers() -> void:
	for chance in [0.05, 0.3, 0.5, 0.8, 0.95]:
		var text := Odds.reading(chance)
		assert_false(text.contains("%"))
		assert_false(text.is_valid_float())
