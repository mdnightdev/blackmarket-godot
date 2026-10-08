extends GutTest

var _run: RunState
var _no_events: Array[EventDef] = []


func before_each() -> void:
	_run = RunState.new()
	# Vex's crew rolls on the same unseeded rng and would make the quiet-day checks flaky.
	_run.vex_gone = true


func _start_day(day: int) -> void:
	_run.day = day
	Encounters.after_time_passes(_run, true, false, RandomNumberGenerator.new(), _no_events)


func _start_career(debt: int) -> void:
	_run.career = true
	_run.debt = debt
	_run.period_minimum = Loan.minimum_payment(debt)


func test_first_week_asks_for_the_fixed_payment() -> void:
	assert_eq(_run.period_minimum, Loan.FIRST_PAYMENT)
	assert_eq(Loan.amount_due(_run), Loan.FIRST_PAYMENT)


func test_later_weeks_ask_for_a_share_of_the_debt() -> void:
	assert_eq(Loan.minimum_payment(100000), 6000)
	assert_eq(Loan.minimum_payment(30000), Loan.MIN_PAYMENT)
	assert_eq(Loan.minimum_payment(1000), 1000)
	assert_eq(Loan.minimum_payment(0), 0)


func test_no_interest_before_the_career() -> void:
	assert_eq(Loan.daily_interest(_run), 0)
	_start_day(2)
	assert_eq(_run.debt, RunState.STARTING_DEBT)


func test_career_loans_compound_daily() -> void:
	_start_career(10000)
	Loan.accrue_interest(_run)
	assert_eq(_run.debt, 10150)
	Loan.accrue_interest(_run)
	assert_eq(_run.debt, 10303)


func test_repay_works_anywhere() -> void:
	assert_true(Loan.repay(_run, 500))
	assert_eq(_run.cash, RunState.STARTING_CASH - 500)
	assert_eq(_run.debt, RunState.STARTING_DEBT - 500)
	assert_eq(Loan.amount_due(_run), Loan.FIRST_PAYMENT - 500)


func test_repay_is_limited_by_cash_and_debt() -> void:
	assert_false(Loan.repay(_run, RunState.STARTING_CASH + 1))
	_run.cash = RunState.STARTING_DEBT * 2
	assert_eq(Loan.max_repay(_run), RunState.STARTING_DEBT)


func test_no_borrowing_before_the_career() -> void:
	_run.district_id = &"downtown"
	assert_false(Loan.can_borrow(_run))
	assert_eq(Loan.max_borrow(_run), 0)
	assert_false(Loan.borrow(_run, 1000))
	assert_eq(_run.debt, RunState.STARTING_DEBT)


func test_career_borrowing_only_at_the_shark_and_capped() -> void:
	_start_career(0)
	assert_false(Loan.borrow(_run, 1000))
	_run.district_id = &"downtown"
	assert_true(Loan.borrow(_run, 1000))
	assert_eq(_run.debt, 1000)
	assert_eq(Loan.max_borrow(_run), Loan.MAX_DEBT - 1000)
	assert_false(Loan.borrow(_run, Loan.max_borrow(_run) + 1))


func test_missed_week_sends_enforcers_and_adds_a_strike() -> void:
	var cash_after_cut := RunState.STARTING_CASH + Turf.daily_cut(_run)
	_start_day(Loan.PAYMENT_PERIOD_DAYS + 1)
	assert_eq(_run.pending_encounter.type, Encounters.ENFORCERS)
	assert_string_contains(str(_run.pending_encounter.body), "Missed 1 of %d" % Loan.MAX_MISSED_WEEKS)
	assert_eq(_run.cash, cash_after_cut - roundi(cash_after_cut * Loan.ENFORCER_CASH_FRACTION))
	assert_eq(_run.debt, RunState.STARTING_DEBT + 2500)
	assert_eq(_run.missed_weeks, 1)
	assert_eq(_run.next_due_day, Loan.PAYMENT_PERIOD_DAYS * 2 + 1)
	assert_eq(_run.paid_this_period, 0)
	assert_eq(_run.period_minimum, Loan.minimum_payment(_run.debt))


func test_penalty_is_charged_on_the_unpaid_part() -> void:
	Loan.repay(_run, 2000)
	assert_eq(Loan.enforcer_penalty(_run), 1500)


func test_enforcers_take_no_more_than_the_cap() -> void:
	_run.cash = 500000
	assert_eq(Loan.enforcer_cash_take(_run), Loan.MAX_ENFORCER_TAKE)


func test_enforcers_never_take_goods() -> void:
	_run.cash = 0
	Inventory.add_units(_run, &"burner_sims", 4)
	Inventory.add_units(_run, &"forged_papers", 2)
	_start_day(Loan.PAYMENT_PERIOD_DAYS + 1)
	assert_eq(_run.pending_encounter.type, Encounters.ENFORCERS)
	assert_eq(Inventory.count(_run, &"forged_papers"), 2)
	assert_eq(Inventory.count(_run, &"burner_sims"), 4)


func test_paid_week_rolls_over_quietly_and_clears_strikes() -> void:
	_run.cash = 10000
	_run.missed_weeks = 2
	Loan.repay(_run, Loan.FIRST_PAYMENT)
	_start_day(Loan.PAYMENT_PERIOD_DAYS + 1)
	assert_true(_run.pending_encounter.is_empty())
	assert_eq(_run.missed_weeks, 0)
	assert_eq(_run.next_due_day, Loan.PAYMENT_PERIOD_DAYS * 2 + 1)
	assert_eq(_run.paid_this_period, 0)
	assert_eq(_run.period_minimum, Loan.minimum_payment(RunState.STARTING_DEBT - Loan.FIRST_PAYMENT))


func test_no_payment_check_before_the_due_day() -> void:
	_start_day(Loan.PAYMENT_PERIOD_DAYS)
	assert_true(_run.pending_encounter.is_empty())
	assert_eq(_run.missed_weeks, 0)
	assert_eq(_run.next_due_day, Loan.PAYMENT_PERIOD_DAYS + 1)
