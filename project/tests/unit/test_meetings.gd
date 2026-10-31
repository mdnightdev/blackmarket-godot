extends GutTest

const BAR: StringName = &"docks"

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	_run.price_seed = 1357
	_run.cash = 100000


func _away_from(district_id: StringName) -> StringName:
	for district in Content.districts():
		if district.id != district_id and not Travel.is_locked(_run, district):
			return district.id
	return &""


## Gives the order an id whose meeting goes the way the test needs.
func _set_scam(order: Dictionary, scam: bool) -> void:
	for attempt in 500:
		order.id = "meet:test:%d" % attempt
		if Meetings.is_scam(_run, order) == scam:
			return
	fail_test("no order id found")


func _customer_order(temperament: CustomerDef.Temperament) -> Dictionary:
	var customer: CustomerDef = null
	for candidate in Content.customers():
		if candidate.temperament == temperament:
			customer = candidate
	var offer := CustomerOffers.generate(_run, customer)
	offer.id = "customer:meet"
	_run.customer_offers.append(offer)
	assert_true(Customers.accept(_run, str(offer.id)))
	var order := Customers.find(_run, str(offer.id))
	Inventory.add_units(_run, StringName(str(order.item)), int(order.quantity))
	_run.district_id = _away_from(StringName(str(order.district)))
	return order


func _bar_order() -> Dictionary:
	_run.district_id = BAR
	Orders.accept(_run, Orders.board(_run, BAR)[0])
	var order: Dictionary = _run.orders[0]
	Inventory.add_units(_run, StringName(str(order.item)), int(order.quantity))
	_run.district_id = _away_from(Orders.client_district(order))
	return order


func test_spots_start_here_and_stop_short_of_the_client() -> void:
	_run.district_id = &"docks"
	var spots := Meetings.spots(_run, &"north_port")
	assert_eq(spots[0], &"docks")
	assert_false(spots.has(&"north_port"))
	for spot in spots:
		assert_false(Travel.is_locked(_run, Content.district(spot)))
	assert_true(Meetings.spots(_run, &"docks").is_empty())


func test_a_customer_met_on_the_way_pays_the_meeting_price() -> void:
	var order := _customer_order(CustomerDef.Temperament.FAIR)
	_set_scam(order, false)
	assert_false(Customers.can_hand_over(_run, order))
	Meetings.agree(order, _run.district_id)
	assert_true(Customers.can_hand_over(_run, order))
	var cash := _run.cash
	var result := Customers.hand_over(_run, order, 0.99)
	assert_eq(int(result.paid), Customers.meeting_total(order))
	assert_eq(_run.cash, cash + Customers.meeting_total(order))
	assert_false(bool(result.scammed))
	assert_lt(Customers.meeting_total(order), Customers.total(order))


func test_a_scammer_short_pays_at_the_meeting() -> void:
	var order := _customer_order(CustomerDef.Temperament.FAIR)
	_set_scam(order, true)
	Meetings.agree(order, _run.district_id)
	var result := Customers.hand_over(_run, order, 0.99)
	assert_true(bool(result.scammed))
	assert_lt(int(result.paid), Customers.meeting_total(order))
	assert_true(Customers.find(_run, str(order.id)).is_empty())


func test_a_bar_client_meets_the_player_for_less() -> void:
	var order := _bar_order()
	_set_scam(order, false)
	assert_false(Orders.can_meet(_run, order))
	Meetings.agree(order, _run.district_id)
	assert_true(Orders.can_meet(_run, order))
	var cash := _run.cash
	assert_eq(Orders.meet(_run, order), Orders.meeting_total(order))
	assert_eq(_run.cash, cash + Orders.meeting_total(order))
	assert_true(_run.orders.is_empty())


func test_no_meeting_in_the_dealers_own_district() -> void:
	var order := _bar_order()
	_run.district_id = Orders.client_district(order)
	Meetings.agree(order, _run.district_id)
	assert_false(Orders.can_meet(_run, order))
	assert_eq(Orders.meet(_run, order), 0)


func test_meeting_spots_survive_a_save() -> void:
	var order := _bar_order()
	Meetings.agree(order, _run.district_id)
	var customer := _customer_order(CustomerDef.Temperament.FAIR)
	Meetings.agree(customer, _run.district_id)
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(_run.to_dict())))
	assert_eq(Meetings.spot(restored.orders[0]), Meetings.spot(order))
	assert_eq(Meetings.spot(restored.customer_orders[0]), _run.district_id)
	var bogus := Orders.sanitize({ "meet": "nowhere" })
	assert_false(bogus.has("meet"))
