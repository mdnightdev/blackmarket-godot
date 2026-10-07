extends GutTest

var _run: RunState
var _destination: DistrictDef


func before_each() -> void:
	_run = RunState.new()
	_destination = DistrictDef.new()
	_destination.id = &"docks"
	_destination.travel_cost = 60


func test_check_allows_affordable_trip() -> void:
	assert_eq(Travel.check(_run, _destination), Travel.Check.OK)


func test_check_rejects_current_district() -> void:
	_destination.id = _run.district_id
	assert_eq(Travel.check(_run, _destination), Travel.Check.ALREADY_HERE)


func test_check_rejects_trip_player_cannot_afford() -> void:
	_run.cash = 59
	assert_eq(Travel.check(_run, _destination), Travel.Check.NOT_ENOUGH_CASH)


func test_check_allows_spending_exact_fare() -> void:
	_run.cash = 60
	assert_eq(Travel.check(_run, _destination), Travel.Check.OK)


func test_travel_pays_fare_and_moves_player() -> void:
	Travel.travel(_run, _destination)
	assert_eq(_run.cash, RunState.STARTING_CASH - 60)
	assert_eq(_run.district_id, &"docks")


func test_travel_spends_one_phase() -> void:
	assert_false(Travel.travel(_run, _destination))
	assert_eq(_run.phase, RunState.Phase.NOON)


func test_vehicles_discount_the_fare() -> void:
	_run.gear.append(&"scooter")
	assert_eq(Travel.fare(_run, _destination), 36)
	Travel.travel(_run, _destination)
	assert_eq(_run.cash, RunState.STARTING_CASH - 36)


func test_fare_discount_is_capped() -> void:
	_run.gear.append(&"scooter")
	_run.gear.append(&"smuggler_van")
	_destination.travel_cost = 100
	assert_eq(Travel.fare(_run, _destination), 20)


func test_check_uses_discounted_fare() -> void:
	_run.gear.append(&"scooter")
	_run.cash = 40
	assert_eq(Travel.check(_run, _destination), Travel.Check.OK)


func test_travel_at_night_starts_new_day() -> void:
	_run.phase = RunState.Phase.NIGHT
	assert_true(Travel.travel(_run, _destination))
	assert_eq(_run.day, 2)
