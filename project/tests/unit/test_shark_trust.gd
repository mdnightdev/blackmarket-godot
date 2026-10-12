extends GutTest

var _run: RunState
var _no_events: Array[EventDef] = []


func before_each() -> void:
	_run = RunState.new()
	_run.price_seed = 2468
	# Vex's crew rolls on the same unseeded rng and would take the slot the Shark's scenes need.
	_run.gangs_gone.append(&"vex")


func _end_first_week() -> void:
	_run.day = Loan.PAYMENT_PERIOD_DAYS + 1
	Encounters.after_time_passes(_run, true, false, RandomNumberGenerator.new(), _no_events)


func test_a_new_run_starts_neutral() -> void:
	assert_eq(_run.shark_trust, SharkTrust.START)
	assert_eq(SharkTrust.level_name(_run), "Neutral")


func test_paying_early_earns_more_and_one_letter() -> void:
	_run.cash = 10000
	assert_true(Loan.repay(_run, Loan.FIRST_PAYMENT))
	assert_true(SharkTrust.paid_early(_run))
	_end_first_week()
	assert_eq(_run.shark_trust, SharkTrust.START + SharkTrust.PAID_EARLY)
	assert_eq(str(_run.pending_encounter.type), SharkTrust.LETTER)
	assert_true(_run.shark_letter_sent)


func test_paying_on_the_due_day_is_on_time_not_early() -> void:
	_run.cash = 10000
	_run.day = Loan.PAYMENT_PERIOD_DAYS
	assert_true(Loan.repay(_run, Loan.FIRST_PAYMENT))
	assert_false(SharkTrust.paid_early(_run))
	_end_first_week()
	assert_eq(_run.shark_trust, SharkTrust.START + SharkTrust.PAID_ON_TIME)
	assert_false(_run.shark_letter_sent)


func test_a_missed_week_costs_trust_and_adds_interest() -> void:
	_end_first_week()
	assert_eq(_run.shark_trust, SharkTrust.START + SharkTrust.MISSED_WEEK)
	assert_eq(_run.missed_total, 1)
	assert_eq(_run.debt, RunState.STARTING_DEBT + ceili(RunState.STARTING_DEBT * Loan.MISSED_WEEK_INTEREST))


func test_declining_an_errand_costs_trust() -> void:
	Errands.post(_run)
	var offer: Dictionary = _run.errand_offers[0]
	assert_true(Errands.decline(_run, str(offer.id)))
	assert_eq(_run.shark_trust, SharkTrust.START + SharkTrust.ERRAND_DECLINED)


func test_trust_stays_within_bounds() -> void:
	SharkTrust.add(_run, 500)
	assert_eq(_run.shark_trust, SharkTrust.MAX)
	assert_eq(SharkTrust.level_name(_run), "Trusted")
	SharkTrust.add(_run, -500)
	assert_eq(_run.shark_trust, 0)
	assert_true(SharkTrust.at_floor(_run))


func test_trust_is_frozen_once_vex_holds_the_debt() -> void:
	_run.lender = Loan.VEX_LENDER
	SharkTrust.add(_run, SharkTrust.MISSED_WEEK)
	assert_eq(_run.shark_trust, SharkTrust.START)


func test_the_promise_comes_once_at_half_the_debt() -> void:
	_run.debt = roundi(RunState.STARTING_DEBT * SharkTrust.PROMISE_DEBT_SHARE) + 1
	assert_false(SharkTrust.check_promise(_run))
	_run.debt -= 1
	assert_true(SharkTrust.check_promise(_run))
	assert_eq(str(_run.pending_encounter.type), SharkTrust.PROMISE)
	_run.pending_encounter = {}
	assert_false(SharkTrust.check_promise(_run))


func test_one_missed_week_rules_out_the_promise() -> void:
	_run.debt = 10000
	_run.missed_total = 1
	assert_false(SharkTrust.check_promise(_run))


func test_trust_survives_a_save() -> void:
	_run.shark_trust = 72
	_run.shark_letter_sent = true
	_run.inheritance_promised = true
	_run.missed_total = 2
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(_run.to_dict())))
	assert_eq(restored.shark_trust, 72)
	assert_true(restored.shark_letter_sent)
	assert_true(restored.inheritance_promised)
	assert_eq(restored.missed_total, 2)
