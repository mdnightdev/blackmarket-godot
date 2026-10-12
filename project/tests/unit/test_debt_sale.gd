extends GutTest

var _run: RunState
var _no_events: Array[EventDef] = []


func before_each() -> void:
	_run = RunState.new()
	_run.price_seed = 2468
	_run.gangs_gone.append(&"vex")


func _sell() -> void:
	_run.missed_weeks = Loan.MAX_MISSED_WEEKS
	assert_true(DebtSale.check(_run))


func _resolve(choice: StringName) -> String:
	return Encounters.resolve(_run, choice, 0.5)


func test_not_due_while_the_player_keeps_up() -> void:
	_run.missed_weeks = Loan.MAX_MISSED_WEEKS - 1
	assert_false(DebtSale.is_due(_run))


func test_trust_at_the_floor_sells_the_debt() -> void:
	_run.shark_trust = 0
	assert_true(DebtSale.is_due(_run))


func test_never_due_in_the_career_or_with_no_debt() -> void:
	_run.missed_weeks = Loan.MAX_MISSED_WEEKS
	_run.debt = 0
	assert_false(DebtSale.is_due(_run))
	_run.debt = 5000
	_run.career = true
	assert_false(DebtSale.is_due(_run))


func test_the_sale_doubles_the_debt_and_drops_the_shark_errands() -> void:
	Errands.post(_run)
	_sell()
	assert_eq(_run.lender, Loan.VEX_LENDER)
	assert_eq(_run.debt, RunState.STARTING_DEBT * DebtSale.DEBT_MULTIPLIER)
	assert_eq(_run.period_minimum, Loan.minimum_payment(_run.debt))
	assert_true(_run.errand_offers.is_empty())
	assert_eq(str(_run.pending_encounter.type), DebtSale.DEBT_SOLD)
	assert_false(DebtSale.check(_run), "only sold once")


func test_the_scenes_play_in_order() -> void:
	_sell()
	_resolve(Encounters.CONTINUE)
	assert_eq(str(_run.pending_encounter.type), DebtSale.VEX_TERMS)
	_resolve(Encounters.CONTINUE)
	assert_eq(str(_run.pending_encounter.type), DebtSale.RABBIT_OFFER)
	var ids: Array[StringName] = []
	for choice in Encounters.choices(_run, _run.pending_encounter):
		ids.append(choice.id)
	assert_eq(ids, [DebtSale.TAKE_GIFT, DebtSale.REFUSE_GIFT] as Array[StringName])


func test_taking_the_gift_clears_the_debt_and_starts_the_career() -> void:
	_sell()
	_resolve(Encounters.CONTINUE)
	_resolve(Encounters.CONTINUE)
	_resolve(DebtSale.TAKE_GIFT)
	assert_eq(_run.debt, 0)
	assert_true(_run.career)
	assert_eq(_run.rabbit_offer, DebtSale.RabbitOffer.TAKEN)
	assert_eq(str(_run.pending_encounter.type), Campaign.CAREER_START)


func test_refusing_the_gift_keeps_the_debt_with_vex() -> void:
	_sell()
	_resolve(Encounters.CONTINUE)
	_resolve(Encounters.CONTINUE)
	_resolve(DebtSale.REFUSE_GIFT)
	assert_eq(_run.debt, RunState.STARTING_DEBT * DebtSale.DEBT_MULTIPLIER)
	assert_false(_run.career)
	assert_eq(_run.rabbit_offer, DebtSale.RabbitOffer.REFUSED)


func test_vex_errands_pay_nothing() -> void:
	_sell()
	_run.pending_encounter = {}
	var errand := Errands.generate(_run)
	assert_eq(str(errand.sender), String(Loan.VEX_LENDER))
	assert_eq(int(errand.pay), 0)
	assert_eq(Errands.pay_label(errand), "Unpaid")


func test_saying_no_to_vex_sends_her_crew() -> void:
	_sell()
	_run.pending_encounter = {}
	_run.cash = 10000
	Errands.post(_run)
	var offer: Dictionary = _run.errand_offers[0]
	assert_true(Errands.decline(_run, str(offer.id)))
	assert_eq(str(_run.pending_encounter.type), DebtSale.VEX_VISIT)
	assert_lt(_run.cash, 10000)


func test_missed_weeks_with_vex_add_interest_but_never_sell_again() -> void:
	_sell()
	_run.pending_encounter = {}
	_run.missed_weeks = Loan.MAX_MISSED_WEEKS
	_run.day = _run.next_due_day
	var debt_before := _run.debt
	Encounters.after_time_passes(_run, true, false, RandomNumberGenerator.new(), _no_events)
	assert_eq(_run.lender, Loan.VEX_LENDER)
	assert_eq(_run.debt, debt_before + ceili(debt_before * Loan.MISSED_WEEK_INTEREST))
	assert_eq(str(_run.pending_encounter.type), Encounters.ENFORCERS)


func test_the_sale_survives_a_save() -> void:
	_sell()
	_run.rabbit_offer = DebtSale.RabbitOffer.REFUSED
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(_run.to_dict())))
	assert_eq(restored.lender, Loan.VEX_LENDER)
	assert_eq(restored.rabbit_offer, DebtSale.RabbitOffer.REFUSED)
	assert_eq(restored.debt, _run.debt)
