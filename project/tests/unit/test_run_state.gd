extends GutTest


func test_new_run_uses_starting_values() -> void:
	var state := RunState.new()
	assert_eq(state.day, 1)
	assert_eq(state.phase, RunState.Phase.MORNING)
	assert_eq(state.cash, RunState.STARTING_CASH)
	assert_eq(state.debt, RunState.STARTING_DEBT)
	assert_eq(state.district_id, RunState.STARTING_DISTRICT)
	assert_true(state.inventory.is_empty())


func test_round_trip_through_json_keeps_every_field() -> void:
	var state := RunState.new()
	state.day = 7
	state.phase = RunState.Phase.EVENING
	state.cash = 48210
	state.debt = 1200
	state.heat = 35
	state.campaign_days = 60
	state.district_id = &"docks"
	state.inventory = {&"burner_phone": 3, &"forged_passport": 1}
	state.player_id = &"jin"

	var json := JSON.stringify(state.to_dict())
	var restored := RunState.from_dict(JSON.parse_string(json))

	assert_eq(restored.player_id, &"jin")
	assert_eq(restored.day, 7)
	assert_eq(restored.phase, RunState.Phase.EVENING)
	assert_eq(restored.cash, 48210)
	assert_eq(restored.debt, 1200)
	assert_eq(restored.heat, 35)
	assert_eq(restored.campaign_days, 60)
	assert_eq(restored.district_id, &"docks")
	assert_eq(restored.inventory, {&"burner_phone": 3, &"forged_passport": 1})


func test_round_trip_keeps_market_state() -> void:
	var state := RunState.new()
	state.price_seed = 98765
	state.stash = {&"vault_keys": 4}
	state.cost_basis = {&"vault_keys": 760}
	state.gear = [&"scooter", &"messenger_bag"]
	state.walked_out = {&"docks": 0, &"slums": 9}

	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())))

	assert_eq(restored.price_seed, 98765)
	assert_eq(restored.stash, {&"vault_keys": 4})
	assert_eq(restored.cost_basis, {&"vault_keys": 760})
	assert_eq(restored.gear, [&"scooter", &"messenger_bag"] as Array[StringName])
	assert_eq(restored.walked_out, {&"docks": 0, &"slums": 9})


func test_from_dict_drops_duplicate_gear() -> void:
	var restored := RunState.from_dict({"gear": ["scooter", "scooter"]})
	assert_eq(restored.gear.size(), 1)


func test_from_dict_sanitizes_out_of_range_values() -> void:
	var restored := RunState.from_dict({
		"day": 0,
		"phase": 9,
		"debt": -50,
		"heat": 250,
		"inventory": {"burner_phone": 0, "lockpick": -2, "scanner": 1},
	})
	assert_eq(restored.day, 1)
	assert_eq(restored.phase, RunState.Phase.NIGHT)
	assert_eq(restored.debt, 0)
	assert_eq(restored.heat, 100)
	assert_eq(restored.inventory, {&"scanner": 1})


func test_from_empty_dict_gives_fresh_run() -> void:
	var restored := RunState.from_dict({})
	assert_eq(restored.cash, RunState.STARTING_CASH)
	assert_eq(restored.day, 1)
