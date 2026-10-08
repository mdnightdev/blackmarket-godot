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


func test_minimum_payment() -> void:
	assert_eq(Loan.minimum_payment(5000), 1000)
	assert_eq(Loan.minimum_payment(1000), Loan.MIN_PAYMENT)
	assert_eq(Loan.minimum_payment(300), 300)
	assert_eq(Loan.minimum_payment(0), 0)
	assert_eq(_run.period_minimum, 1000)


func test_interest_compounds_daily() -> void:
	Loan.accrue_interest(_run)
	assert_eq(_run.debt, 5150)
	Loan.accrue_interest(_run)
	assert_eq(_run.debt, 5305)


func test_repay_anywhere_but_borrow_only_at_the_shark() -> void:
	assert_true(Loan.repay(_run, 500))
	assert_eq(_run.cash, RunState.STARTING_CASH - 500)
	assert_eq(_run.debt, RunState.STARTING_DEBT - 500)
	assert_eq(Loan.amount_due(_run), 500)
	assert_false(Loan.borrow(_run, 1000))
	_run.district_id = &"downtown"
	assert_true(Loan.borrow(_run, 1000))
	assert_eq(_run.debt, RunState.STARTING_DEBT + 500)


func test_repay_is_limited_by_cash_and_debt() -> void:
	_run.district_id = &"downtown"
	assert_false(Loan.repay(_run, RunState.STARTING_CASH + 1))
	_run.cash = 100_000
	assert_eq(Loan.max_repay(_run), RunState.STARTING_DEBT)


func test_borrowing_is_capped() -> void:
	_run.district_id = &"downtown"
	assert_eq(Loan.max_borrow(_run), Loan.MAX_DEBT - RunState.STARTING_DEBT)
	assert_false(Loan.borrow(_run, Loan.max_borrow(_run) + 1))


func test_missed_payment_sends_enforcers() -> void:
	var cash_after_cut := RunState.STARTING_CASH + Turf.daily_cut(_run)
	_start_day(Loan.PAYMENT_PERIOD_DAYS + 1)
	assert_eq(_run.pending_encounter.type, Encounters.ENFORCERS)
	assert_eq(_run.cash, cash_after_cut - roundi(cash_after_cut * Loan.ENFORCER_CASH_FRACTION))
	assert_eq(_run.debt, 5150 + 515)
	assert_eq(_run.next_due_day, Loan.PAYMENT_PERIOD_DAYS * 2 + 1)
	assert_eq(_run.paid_this_period, 0)
	assert_eq(_run.period_minimum, Loan.minimum_payment(_run.debt))


func test_enforcers_take_goods_when_cash_falls_short() -> void:
	_run.cash = 0
	Inventory.add_units(_run, &"burner_sims", 4)
	Inventory.add_units(_run, &"forged_papers", 2)
	_start_day(Loan.PAYMENT_PERIOD_DAYS + 1)
	assert_eq(Inventory.count(_run, &"forged_papers"), 0)
	assert_eq(Inventory.count(_run, &"burner_sims"), 4)


func test_paid_period_rolls_over_quietly() -> void:
	_run.district_id = &"downtown"
	Loan.repay(_run, 1000)
	_start_day(Loan.PAYMENT_PERIOD_DAYS + 1)
	assert_true(_run.pending_encounter.is_empty())
	assert_eq(_run.next_due_day, Loan.PAYMENT_PERIOD_DAYS * 2 + 1)
	assert_eq(_run.paid_this_period, 0)


func test_no_payment_check_before_the_due_day() -> void:
	_start_day(Loan.PAYMENT_PERIOD_DAYS)
	assert_true(_run.pending_encounter.is_empty())
	assert_eq(_run.next_due_day, Loan.PAYMENT_PERIOD_DAYS + 1)
