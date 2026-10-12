extends GutTest

var _run: RunState
var _no_events: Array[EventDef] = []


func before_each() -> void:
	_run = RunState.new()


func _start_day(day: int) -> void:
	_run.day = day
	Encounters.after_time_passes(_run, true, false, RandomNumberGenerator.new(), _no_events)


func test_clearing_the_debt_starts_the_career() -> void:
	_run.district_id = &"downtown"
	_run.cash = RunState.STARTING_DEBT
	assert_true(Loan.repay(_run, RunState.STARTING_DEBT))
	assert_true(Campaign.start_career_if_cleared(_run))
	assert_true(_run.career)
	assert_eq(_run.outcome, RunState.Outcome.ONGOING)
	assert_eq(str(_run.pending_encounter.type), Campaign.CAREER_START)
	assert_false(Campaign.is_over(_run))
	assert_false(Campaign.start_career_if_cleared(_run))


func test_career_survives_missed_weeks() -> void:
	_run.debt = 0
	Campaign.start_career_if_cleared(_run)
	_run.pending_encounter = {}
	_run.debt = 2000
	_run.period_minimum = 2000
	_run.missed_weeks = Loan.MAX_MISSED_WEEKS
	_start_day(Loan.PAYMENT_PERIOD_DAYS + 1)
	assert_eq(_run.outcome, RunState.Outcome.ONGOING)
	assert_false(Campaign.is_over(_run))


func test_act_one_has_no_day_limit() -> void:
	_run.cash = 10000
	Loan.repay(_run, Loan.FIRST_PAYMENT)
	_start_day(100)
	assert_eq(_run.outcome, RunState.Outcome.ONGOING)
	assert_false(Campaign.is_over(_run))


func test_missing_a_week_while_under_the_limit_keeps_the_run() -> void:
	_run.missed_weeks = Loan.MAX_MISSED_WEEKS - 2
	_start_day(Loan.PAYMENT_PERIOD_DAYS + 1)
	assert_eq(_run.missed_weeks, Loan.MAX_MISSED_WEEKS - 1)
	assert_eq(_run.outcome, RunState.Outcome.ONGOING)
	assert_eq(_run.pending_encounter.type, Encounters.ENFORCERS)


func test_third_missed_week_in_a_row_sells_the_debt() -> void:
	_run.missed_weeks = Loan.MAX_MISSED_WEEKS - 1
	_start_day(Loan.PAYMENT_PERIOD_DAYS + 1)
	assert_eq(_run.lender, Loan.VEX_LENDER)
	assert_eq(_run.debt, RunState.STARTING_DEBT * DebtSale.DEBT_MULTIPLIER)
	assert_eq(_run.missed_weeks, 0)
	assert_eq(str(_run.pending_encounter.type), DebtSale.DEBT_SOLD)
	assert_eq(_run.outcome, RunState.Outcome.ONGOING)
	assert_false(Campaign.is_over(_run))


func test_debt_still_owed_does_not_start_the_career() -> void:
	assert_false(Campaign.start_career_if_cleared(_run))
	assert_false(_run.career)


func test_net_worth_counts_goods_and_stash() -> void:
	Inventory.add_units(_run, &"burner_phones", 2)
	_run.stash[&"fake_ids"] = 1
	assert_eq(Campaign.net_worth(_run), RunState.STARTING_CASH - RunState.STARTING_DEBT + 200 + 180)


func test_trades_and_profit_are_tracked() -> void:
	var phones := Content.item(&"burner_phones")
	Trade.buy(_run, phones, 4, 100)
	Trade.sell(_run, phones, 3, 150)
	assert_eq(_run.trades, 2)
	assert_eq(_run.profit, 150)


func test_career_survives_a_save() -> void:
	_run.debt = 0
	Campaign.start_career_if_cleared(_run)
	_run.busts = 2
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(_run.to_dict())))
	assert_true(restored.career)
	assert_eq(restored.outcome, RunState.Outcome.ONGOING)
	assert_eq(restored.busts, 2)


func test_old_won_and_endless_saves_become_careers() -> void:
	var saved := _run.to_dict()
	saved["outcome"] = RunState.Outcome.WON
	saved["endless"] = true
	var restored := RunState.from_dict(saved)
	assert_true(restored.career)
	assert_eq(restored.outcome, RunState.Outcome.ONGOING)
	assert_false(Campaign.is_over(restored))
