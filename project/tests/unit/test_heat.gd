extends GutTest

var _run: RunState
var _phones: ItemDef


func before_each() -> void:
	_run = RunState.new()
	_phones = Content.item(&"burner_phones")


func test_trade_heat_scales_with_risk_quantity_and_district() -> void:
	assert_eq(Heat.for_trade(_run, _phones, 8), 3)
	_run.district_id = &"north_port"
	assert_eq(Heat.for_trade(_run, _phones, 8), 5)
	_run.district_id = &"slums"
	assert_eq(Heat.for_trade(_run, _phones, 1), 1)


func test_travel_heat_comes_from_carried_goods() -> void:
	assert_eq(Heat.for_travel(_run), 0)
	Inventory.add_units(_run, _phones.id, 10)
	assert_eq(Heat.carried_risk(_run), 150)
	assert_eq(Heat.for_travel(_run), 2)


func test_heat_cools_faster_overnight() -> void:
	_run.heat = 20
	Heat.cool_down(_run, false)
	assert_eq(_run.heat, 20 - Heat.DECAY_PER_PHASE)
	Heat.cool_down(_run, true)
	assert_eq(_run.heat, 20 - Heat.DECAY_PER_PHASE * 2 - Heat.OVERNIGHT_DECAY)


func test_heat_stays_between_zero_and_max() -> void:
	Heat.add(_run, -50)
	assert_eq(_run.heat, 0)
	Heat.add(_run, 500)
	assert_eq(_run.heat, Heat.MAX)
	assert_true(Heat.is_maxed(_run))
