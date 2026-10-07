extends GutTest

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	_run.cash = 5000
	_run.heat = 60


func test_clean_up_removes_heat_for_cash() -> void:
	var cost := Fixer.clean_up_cost(_run)
	assert_eq(cost, Fixer.CLEAN_UP_BASE_COST + Fixer.CLEAN_UP_HEAT * Fixer.CLEAN_UP_COST_PER_HEAT)
	assert_eq(Fixer.clean_up(_run), Fixer.CLEAN_UP_HEAT)
	assert_eq(_run.heat, 60 - Fixer.CLEAN_UP_HEAT)
	assert_eq(_run.cash, 5000 - cost)


func test_low_heat_costs_less() -> void:
	_run.heat = 10
	assert_eq(Fixer.clean_up_cost(_run), Fixer.CLEAN_UP_BASE_COST + 10 * Fixer.CLEAN_UP_COST_PER_HEAT)
	assert_eq(Fixer.clean_up(_run), 10)
	assert_eq(_run.heat, 0)


func test_once_per_phase() -> void:
	Fixer.clean_up(_run)
	assert_true(Fixer.cleaned_up(_run))
	assert_eq(Fixer.clean_up(_run), 0)
	Calendar.advance_phase(_run)
	assert_true(Fixer.can_clean_up(_run))


func test_needs_heat_and_cash() -> void:
	_run.heat = 0
	assert_false(Fixer.can_clean_up(_run))
	_run.heat = 60
	_run.cash = Fixer.clean_up_cost(_run) - 1
	assert_eq(Fixer.clean_up(_run), 0)
	assert_eq(_run.heat, 60)


func test_clean_up_survives_a_save() -> void:
	Fixer.clean_up(_run)
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(_run.to_dict())))
	assert_true(Fixer.cleaned_up(restored))
