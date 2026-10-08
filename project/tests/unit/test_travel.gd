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


func test_open_destination_has_no_lock_reason() -> void:
	assert_false(Travel.is_locked(_run, _destination))
	assert_eq(Travel.lock_reason(_run, _destination), "")


func test_check_locks_destination_above_players_rank() -> void:
	_destination.min_rank = 4
	assert_eq(Travel.check(_run, _destination), Travel.Check.LOCKED)
	assert_eq(Travel.lock_reason(_run, _destination), "Needs Hustler rank")
	_run.street_cred = int(StreetCred.RANKS[3].cred)
	assert_eq(Travel.check(_run, _destination), Travel.Check.OK)


func test_check_locks_destination_above_players_power() -> void:
	_destination.min_power = 2
	assert_eq(Travel.check(_run, _destination), Travel.Check.LOCKED)
	assert_eq(Travel.lock_reason(_run, _destination), "Needs Power 2")
	_run.turf[&"docks"] = Turf.HOLD_SHARE
	_run.turf[&"old_market"] = Turf.HOLD_SHARE
	assert_eq(Travel.check(_run, _destination), Travel.Check.OK)


func test_lock_reason_lists_every_unmet_gate() -> void:
	_destination.min_rank = 4
	_destination.min_power = 2
	assert_eq(Travel.lock_reason(_run, _destination), "Needs Hustler rank and Power 2")


func test_lock_is_checked_before_the_fare() -> void:
	_destination.min_rank = 4
	_run.cash = 0
	assert_eq(Travel.check(_run, _destination), Travel.Check.LOCKED)


func test_current_district_is_never_locked() -> void:
	_destination.id = _run.district_id
	_destination.min_rank = 4
	assert_eq(Travel.check(_run, _destination), Travel.Check.ALREADY_HERE)


func test_north_port_starts_locked() -> void:
	assert_eq(Travel.check(_run, Content.district(&"north_port")), Travel.Check.LOCKED)


func test_travel_pays_fare_and_moves_player() -> void:
	Travel.travel(_run, _destination)
	assert_eq(_run.cash, RunState.STARTING_CASH - 60)
	assert_eq(_run.district_id, &"docks")


func test_travel_spends_a_minute_of_the_phase() -> void:
	assert_eq(Travel.travel(_run, _destination), 0.0)
	assert_eq(_run.phase, RunState.Phase.MORNING)
	assert_eq(_run.phase_seconds_left, Calendar.PHASE_SECONDS - Travel.TRIP_SECONDS)


func test_travel_reports_time_past_the_end_of_the_phase() -> void:
	_run.phase_seconds_left = 20.0
	assert_eq(Travel.travel(_run, _destination), Travel.TRIP_SECONDS - 20.0)
	assert_eq(_run.phase_seconds_left, 0.0)
	assert_eq(_run.phase, RunState.Phase.MORNING, "the caller moves the phase on")


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


func test_arrival_mid_phase_adds_travel_heat_only() -> void:
	Inventory.add_units(_run, &"burner_phones", 10)
	Encounters.after_arrival(_run, RandomNumberGenerator.new())
	assert_eq(_run.heat, Heat.for_travel(_run))
	assert_false(Encounters.has_pending(_run), "police stay away in the first days")
