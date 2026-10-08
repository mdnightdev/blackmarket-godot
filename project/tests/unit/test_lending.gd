extends GutTest

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	_run.price_seed = 4321
	_run.career = true
	_run.debt = 0
	_run.cash = Lending.BUYOUT_PRICE + 100000
	_run.district_id = &"downtown"


func _bought_run() -> RunState:
	assert_true(Lending.buy_out(_run))
	return _run


func test_buyout_needs_a_clear_career_and_the_money() -> void:
	_run.debt = 1000
	assert_false(Lending.buy_out(_run))
	_run.debt = 0
	_run.cash = Lending.BUYOUT_PRICE - 1
	assert_false(Lending.buy_out(_run))
	_run.cash = Lending.BUYOUT_PRICE
	_run.district_id = &"docks"
	assert_false(Lending.buy_out(_run), "only at the Shark's office")


func test_buyout_brings_the_shark_onto_the_crew_for_free() -> void:
	var run := _bought_run()
	assert_eq(run.cash, 100000)
	assert_true(run.shark_bought)
	assert_true(Crew.is_free_role(run, Lending.ENFORCER_ROLE))
	assert_eq(Crew.hired_count(run), 0)
	assert_eq(Crew.daily_wages(run), 0)
	assert_false(Loan.can_borrow(run))
	run.cash = 0
	assert_true(Crew.pay_wages(run).is_empty())
	assert_true(Crew.has(run, Lending.ENFORCER_ROLE), "a free member never walks out")


func test_buyout_stops_wages_for_hired_muscle() -> void:
	_run.street_cred = int(StreetCred.RANKS[-1].cred)
	assert_eq(Crew.hire(_run, Lending.ENFORCER_ROLE), Crew.Result.OK)
	_run.cash = Lending.BUYOUT_PRICE
	assert_true(Lending.buy_out(_run))
	assert_eq(_run.crew.size(), 1)
	assert_eq(Crew.daily_wages(_run), 0)


func test_requests_are_stable_and_skip_dealers_who_owe() -> void:
	var run := _bought_run()
	var requests := Lending.requests(run)
	assert_between(requests.size(), 1, Lending.REQUESTS_PER_DAY)
	assert_eq(Lending.requests(run), requests)
	assert_eq(Lending.lend(run, str(requests[0].id)), Lending.Result.OK)
	assert_eq(Lending.lend(run, str(requests[0].id)), Lending.Result.GONE)
	assert_eq(Lending.requests(run).size(), requests.size() - 1)


func test_loans_need_the_buyout() -> void:
	assert_true(Lending.requests(_run).is_empty())
	assert_eq(Lending.lend(_run, "loan:1:anything"), Lending.Result.NOT_OWNER)


func test_loans_come_back_with_interest_or_partly_recovered() -> void:
	var run := _bought_run()
	var request: Dictionary = Lending.requests(run)[0]
	var amount := int(request.amount)
	var dealer := Content.dealer(StringName(str(request.dealer)))
	Lending.lend(run, str(request.id))
	var after_lending := run.cash
	assert_eq(after_lending, 100000 - amount)
	run.day += Lending.TERM_DAYS - 1
	assert_true(Lending.settle(run).is_empty())
	run.day += 1
	var notices := Lending.settle(run)
	assert_eq(notices.size(), 1)
	assert_true(run.dealer_loans.is_empty())
	var returned := run.cash - after_lending
	assert_true(returned == Lending.repayment(dealer, amount) or returned == roundi(amount * Lending.RECOVERED_SHARE), str(returned))


func test_buyout_and_loans_survive_a_save() -> void:
	var run := _bought_run()
	Lending.lend(run, str(Lending.requests(run)[0].id))
	var loaded := RunState.from_dict(run.to_dict())
	assert_true(loaded.shark_bought)
	assert_eq(loaded.dealer_loans, run.dealer_loans)
	assert_true(Crew.is_free_role(loaded, Lending.ENFORCER_ROLE))
