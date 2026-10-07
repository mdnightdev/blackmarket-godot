extends GutTest

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	_run.district_id = &"slums"
	_run.cash = 30000


func test_no_stash_until_the_first_upgrade() -> void:
	assert_eq(Safehouse.stash_capacity(_run), 0)
	assert_eq(Safehouse.next_upgrade(_run).name, "Lockbox")
	assert_false(Inventory.can_use_stash(_run))


func test_upgrades_raise_capacity_in_order() -> void:
	var spent := 0
	for upgrade in Safehouse.UPGRADES:
		spent += int(upgrade.price)
		assert_true(Safehouse.buy_upgrade(_run), str(upgrade.name))
		assert_eq(Safehouse.stash_capacity(_run), int(upgrade.capacity))
		assert_eq(Safehouse.stash_name(_run), str(upgrade.name))
	assert_eq(_run.cash, 30000 - spent)
	assert_true(Safehouse.next_upgrade(_run).is_empty())
	assert_false(Safehouse.buy_upgrade(_run), "nothing left to build")


func test_upgrades_need_cash_and_the_safehouse() -> void:
	_run.cash = int(Safehouse.UPGRADES[0].price) - 1
	assert_false(Safehouse.buy_upgrade(_run))
	_run.cash = 30000
	_run.district_id = &"old_market"
	assert_false(Safehouse.buy_upgrade(_run))
	assert_eq(_run.stash_level, 0)


func test_lying_low_cools_heat_beyond_the_normal_decay() -> void:
	_run.heat = 50
	assert_true(Safehouse.lie_low(_run))
	assert_eq(_run.heat, 50 - Safehouse.LIE_LOW_HEAT)


func test_lying_low_only_at_the_safehouse() -> void:
	_run.heat = 50
	_run.district_id = &"old_market"
	assert_false(Safehouse.lie_low(_run))
	assert_eq(_run.heat, 50)


func test_stash_level_survives_a_save() -> void:
	_run.stash_level = 2
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(_run.to_dict())))
	assert_eq(restored.stash_level, 2)


func test_old_lockbox_saves_become_the_first_level() -> void:
	var data := _run.to_dict()
	data.gear = ["messenger_bag", "safehouse_lockbox"]
	data.erase("stash_level")
	var restored := RunState.from_dict(data)
	var expected_gear: Array[StringName] = [&"messenger_bag"]
	assert_eq(restored.stash_level, 1)
	assert_eq(restored.gear, expected_gear)
