extends GutTest

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	_run.price_seed = 8642
	_run.district_id = &"docks"


func test_target_is_fixed_for_the_phase() -> void:
	var shipment := Hijacks.target(_run)
	var item: ItemDef = shipment.item
	assert_not_null(item)
	assert_eq(item.kind, ItemDef.Kind.TRADE_GOOD)
	assert_between(int(shipment.quantity), Hijacks.MIN_QUANTITY, Hijacks.MAX_QUANTITY)
	assert_eq(Hijacks.target(_run), shipment)


func test_success_puts_free_goods_in_the_bag() -> void:
	var shipment := Hijacks.target(_run)
	var item: ItemDef = shipment.item
	var expected := Hijacks.haul(_run, shipment)
	var taken := Hijacks.attempt(_run, shipment, Hijacks.Approach.QUIET, 0.0)
	assert_eq(taken, expected)
	assert_eq(Inventory.count(_run, item.id), expected)
	assert_eq(int(_run.cost_basis[item.id]), 0, "stolen goods cost nothing")
	assert_eq(_run.heat, Hijacks.HEAT[Hijacks.Approach.QUIET])
	assert_false(Encounters.has_pending(_run))


func test_free_goods_lower_the_average_price_paid() -> void:
	var shipment := Hijacks.target(_run)
	var item: ItemDef = shipment.item
	Inventory.add_units(_run, item.id, 2)
	_run.cost_basis[item.id] = 100
	var taken := Hijacks.attempt(_run, shipment, Hijacks.Approach.LOUD, 0.0)
	assert_eq(int(_run.cost_basis[item.id]), roundi(200.0 / (2 + taken)))


func test_failure_brings_heat_and_the_police() -> void:
	var shipment := Hijacks.target(_run)
	var taken := Hijacks.attempt(_run, shipment, Hijacks.Approach.LOUD, 0.99)
	assert_eq(taken, 0)
	assert_eq(_run.heat, Hijacks.HEAT[Hijacks.Approach.LOUD] + Hijacks.FAILED_HEAT)
	assert_eq(_run.pending_encounter.type, Encounters.POLICE)


func test_loud_succeeds_more_often_than_quiet() -> void:
	var roll := 0.6
	var quiet_run := RunState.new()
	quiet_run.price_seed = _run.price_seed
	assert_eq(Hijacks.attempt(quiet_run, Hijacks.target(quiet_run), Hijacks.Approach.QUIET, roll), 0)
	assert_gt(Hijacks.attempt(_run, Hijacks.target(_run), Hijacks.Approach.LOUD, roll), 0)


func test_one_attempt_per_phase() -> void:
	var shipment := Hijacks.target(_run)
	Hijacks.attempt(_run, shipment, Hijacks.Approach.QUIET, 0.0)
	assert_true(Hijacks.attempted(_run))
	assert_eq(Hijacks.attempt(_run, shipment, Hijacks.Approach.QUIET, 0.0), 0)
	Calendar.advance_phase(_run)
	assert_false(Hijacks.attempted(_run))


func test_haul_is_limited_by_bag_space() -> void:
	var shipment := Hijacks.target(_run)
	var item: ItemDef = shipment.item
	Inventory.add_units(_run, &"burner_sims", Inventory.capacity(_run) - item.slots)
	assert_eq(Hijacks.haul(_run, shipment), 1)
	Inventory.add_units(_run, &"burner_sims", item.slots)
	assert_false(Hijacks.can_attempt(_run, shipment))
