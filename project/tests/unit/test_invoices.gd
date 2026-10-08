extends GutTest

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	_run.price_seed = 2468
	_run.district_id = Smuggling.ORIGIN
	_run.cash = 1000


func _take_long_crate(invoice: bool) -> Dictionary:
	var offer: Dictionary = Smuggling.board(_run)[Smuggling.POSTED_PER_DAY - 1]
	var route: Array[StringName] = []
	route.assign(Routes.paths(Smuggling.ORIGIN, StringName(str(offer.destination)))[0])
	Smuggling.accept(_run, offer, route, invoice)
	return offer


func test_an_invoice_pays_more_but_later() -> void:
	var offer := _take_long_crate(true)
	_run.district_id = StringName(str(offer.destination))
	var owed := Smuggling.deliver(_run)
	assert_eq(owed, roundi(int(offer.pay) * (1.0 + Invoices.PAY_BONUS)))
	assert_eq(_run.cash, 1000, "nothing paid on delivery")
	assert_eq(_run.invoices.size(), 1)
	assert_eq(int(_run.invoices[0].amount), owed)
	assert_eq(int(_run.invoices[0].due_day), _run.day + Invoices.DAYS_TO_PAY)
	assert_eq(Invoices.owed(_run), owed)


func test_invoices_wait_for_their_due_day() -> void:
	Invoices.file(_run, "a", Smuggling.CLIENT, 500)
	_run.day += Invoices.DAYS_TO_PAY - 1
	assert_true(Invoices.settle(_run).is_empty())
	assert_eq(_run.invoices.size(), 1)
	_run.day += 1
	assert_eq(Invoices.settle(_run).size(), 1)
	assert_true(_run.invoices.is_empty())


func test_some_buyers_pay_and_some_never_do() -> void:
	for index in 40:
		Invoices.file(_run, "job:%d" % index, Smuggling.CLIENT, 100)
	_run.day += Invoices.DAYS_TO_PAY
	var settled := Invoices.settle(_run)
	var paid := settled.filter(func(invoice: Dictionary) -> bool: return invoice.paid).size()
	assert_eq(_run.cash, 1000 + paid * 100)
	assert_between(paid, 1, 39)


func test_the_outcome_survives_a_reload() -> void:
	Invoices.file(_run, "job:7", Smuggling.CLIENT, 100)
	_run.day += Invoices.DAYS_TO_PAY
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(_run.to_dict())))
	assert_eq(restored.invoices, _run.invoices)
	assert_eq(Invoices.settle(restored)[0].paid, Invoices.settle(_run)[0].paid)


func test_street_cred_makes_buyers_pay() -> void:
	assert_almost_eq(Invoices.default_chance(_run), Invoices.BASE_DEFAULT_CHANCE, 0.0001)
	_run.street_cred = int(StreetCred.RANKS[4].cred)
	assert_lt(Invoices.default_chance(_run), Invoices.BASE_DEFAULT_CHANCE)
	_run.street_cred = StreetCred.MAX
	assert_gte(Invoices.default_chance(_run), Invoices.MIN_DEFAULT_CHANCE)


func test_broken_invoices_are_dropped_on_load() -> void:
	var data := _run.to_dict()
	data.invoices = [{ "id": "", "amount": 100 }, { "id": "x", "amount": 0 }, { "id": "ok", "amount": 50, "due_day": 3 }]
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(data)))
	assert_eq(restored.invoices.size(), 1)
	assert_eq(restored.invoices[0].id, "ok")


func test_the_buyer_meets_at_a_stop_already_reached() -> void:
	var offer := _take_long_crate(false)
	assert_false(Smuggling.can_meet_halfway(_run), "not before leaving Pier 9")
	var first: StringName = Smuggling.stops_left(_run.crate)[0]
	_run.district_id = first
	Smuggling.record_stop(_run)
	assert_true(Smuggling.can_meet_halfway(_run))
	var pay := Smuggling.meet_halfway(_run)
	assert_eq(pay, roundi(int(offer.pay) * Smuggling.HALFWAY_PAY))
	assert_eq(_run.cash, 1000 + pay)
	assert_false(Smuggling.is_carrying(_run))


func test_no_halfway_meeting_off_the_route_or_at_the_drop() -> void:
	var offer := _take_long_crate(false)
	var first: StringName = Smuggling.stops_left(_run.crate)[0]
	_run.district_id = first
	Smuggling.record_stop(_run)
	_run.district_id = Smuggling.ORIGIN
	assert_false(Smuggling.can_meet_halfway(_run), "back at the docks")
	assert_eq(Smuggling.meet_halfway(_run), 0)
	_run.district_id = StringName(str(offer.destination))
	assert_false(Smuggling.can_meet_halfway(_run), "full delivery is possible here")


func test_halfway_on_invoice_owes_the_cut_pay_with_the_bonus() -> void:
	var offer := _take_long_crate(true)
	_run.district_id = Smuggling.stops_left(_run.crate)[0]
	Smuggling.record_stop(_run)
	var owed := Smuggling.meet_halfway(_run)
	assert_eq(owed, roundi(int(offer.pay) * Smuggling.HALFWAY_PAY * (1.0 + Invoices.PAY_BONUS)))
	assert_eq(Invoices.owed(_run), owed)
	assert_eq(_run.cash, 1000)


func test_payment_terms_survive_a_save() -> void:
	_take_long_crate(true)
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(_run.to_dict())))
	assert_true(Smuggling.is_invoiced(restored.crate))
