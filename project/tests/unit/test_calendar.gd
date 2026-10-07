extends GutTest


func test_advance_moves_to_next_phase_on_same_day() -> void:
	var run := RunState.new()
	var new_day := Calendar.advance_phase(run)
	assert_false(new_day)
	assert_eq(run.day, 1)
	assert_eq(run.phase, RunState.Phase.NOON)


func test_advance_after_night_starts_next_morning() -> void:
	var run := RunState.new()
	run.phase = RunState.Phase.NIGHT
	var new_day := Calendar.advance_phase(run)
	assert_true(new_day)
	assert_eq(run.day, 2)
	assert_eq(run.phase, RunState.Phase.MORNING)


func test_full_day_takes_four_phases() -> void:
	var run := RunState.new()
	for i in 3:
		assert_false(Calendar.advance_phase(run))
	assert_true(Calendar.advance_phase(run))
	assert_eq(run.day, 2)


func test_advance_resets_phase_timer() -> void:
	var run := RunState.new()
	run.phase_seconds_left = 12.5
	Calendar.advance_phase(run)
	assert_eq(run.phase_seconds_left, Calendar.PHASE_SECONDS)


func test_phase_timer_survives_save_and_clamps_bad_values() -> void:
	var run := RunState.new()
	run.phase_seconds_left = 90.0
	assert_eq(RunState.from_dict(run.to_dict()).phase_seconds_left, 90.0)
	assert_eq(RunState.from_dict({"phase_seconds_left": -5.0}).phase_seconds_left, 0.0)
	assert_eq(RunState.from_dict({"phase_seconds_left": 99999.0}).phase_seconds_left, Calendar.PHASE_SECONDS)
