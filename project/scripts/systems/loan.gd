class_name Loan

const VENUE: StringName = &"loan_shark"
const LENDER: StringName = &"shark"
const DAILY_INTEREST := 0.015
const PAYMENT_PERIOD_DAYS := 7
const FIRST_PAYMENT := 5000
const MIN_PAYMENT := 2500
const MIN_PAYMENT_FRACTION := 0.06
const MAX_MISSED_WEEKS := 3
## Borrowing opens with the career, so this only caps career loans.
const MAX_DEBT := 50000
const ENFORCER_CASH_FRACTION := 0.15
const MAX_ENFORCER_TAKE := 5000
## Late fee as a share of the missed payment.
const ENFORCER_PENALTY_FRACTION := 0.5


static func minimum_payment(debt: int) -> int:
	if debt <= 0:
		return 0
	return mini(debt, maxi(MIN_PAYMENT, ceili(debt * MIN_PAYMENT_FRACTION)))


static func amount_due(run: RunState) -> int:
	return mini(run.debt, maxi(0, run.period_minimum - run.paid_this_period))


## The Shark charges no interest on the starting debt, only on career loans.
static func daily_interest(run: RunState) -> int:
	if not run.career:
		return 0
	return ceili(run.debt * DAILY_INTEREST)


static func accrue_interest(run: RunState) -> void:
	run.debt += daily_interest(run)


static func max_repay(run: RunState) -> int:
	return maxi(0, mini(run.cash, run.debt))


static func max_borrow(run: RunState) -> int:
	if not run.career or run.shark_bought:
		return 0
	return maxi(0, MAX_DEBT - run.debt)


static func can_visit(run: RunState) -> bool:
	var district := Content.district(run.district_id)
	return district != null and district.venues.has(VENUE)


static func can_borrow(run: RunState) -> bool:
	return run.career and not run.shark_bought and can_visit(run)


## Repaying works from anywhere. Only borrowing needs a visit to The Shark.
static func repay(run: RunState, amount: int) -> bool:
	if amount <= 0 or amount > max_repay(run):
		return false
	run.cash -= amount
	run.debt -= amount
	run.paid_this_period += amount
	return true


static func borrow(run: RunState, amount: int) -> bool:
	if not can_borrow(run) or amount <= 0 or amount > max_borrow(run):
		return false
	run.cash += amount
	run.debt += amount
	return true


static func is_payment_due_today(run: RunState) -> bool:
	return run.day >= run.next_due_day


static func start_next_period(run: RunState) -> void:
	run.next_due_day += PAYMENT_PERIOD_DAYS
	run.paid_this_period = 0
	run.period_minimum = minimum_payment(run.debt)


static func enforcer_cash_take(run: RunState) -> int:
	return mini(MAX_ENFORCER_TAKE, roundi(maxi(0, run.cash) * ENFORCER_CASH_FRACTION))


static func enforcer_penalty(run: RunState) -> int:
	return ceili(amount_due(run) * ENFORCER_PENALTY_FRACTION)
