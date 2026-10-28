extends GutTest

var _run: RunState
var _phones: ItemDef


func before_each() -> void:
	_run = RunState.new()
	Corners.take_all(_run, &"slums")
	_phones = Content.item(&"burner_phones")


func test_bags_add_capacity() -> void:
	assert_eq(Inventory.capacity(_run), Inventory.BASE_CAPACITY)
	_run.gear.append(&"messenger_bag")
	_run.gear.append(&"duffel_bag")
	assert_eq(Inventory.capacity(_run), Inventory.BASE_CAPACITY + 40)


func test_used_space_counts_item_slots() -> void:
	_run.inventory = {&"burner_phones": 3, &"ghost_pistol": 2}
	assert_eq(Inventory.used(_run), 7)
	assert_eq(Inventory.free_space(_run), Inventory.BASE_CAPACITY - 7)


func test_full_bag_is_not_over_capacity() -> void:
	_run.inventory = {&"burner_phones": Inventory.BASE_CAPACITY}
	assert_eq(Inventory.over_capacity(_run), 0)


func test_losing_a_bag_leaves_goods_over_capacity() -> void:
	_run.gear.append(&"messenger_bag")
	_run.inventory = {&"burner_phones": Inventory.BASE_CAPACITY + 5}
	assert_eq(Inventory.over_capacity(_run), 0)
	_run.gear.clear()
	assert_eq(Inventory.over_capacity(_run), 5)
	assert_eq(Inventory.free_space(_run), 0)


func test_stash_needs_lockbox_and_a_held_district() -> void:
	_run.district_id = &"slums"
	assert_false(Inventory.can_use_stash(_run))
	_run.stash_level = 1
	assert_true(Inventory.can_use_stash(_run))
	_run.district_id = &"old_market"
	assert_false(Inventory.can_use_stash(_run))


func test_moving_goods_between_bag_and_stash() -> void:
	_run.district_id = &"slums"
	_run.stash_level = 1
	_run.inventory = {&"burner_phones": 5}
	assert_true(Inventory.move_to_stash(_run, _phones, 3))
	assert_eq(Inventory.count(_run, _phones.id), 2)
	assert_eq(Inventory.stashed(_run, _phones.id), 3)
	assert_true(Inventory.take_from_stash(_run, _phones, 3))
	assert_eq(Inventory.count(_run, _phones.id), 5)
	assert_false(_run.stash.has(_phones.id))


func test_cannot_move_more_than_held() -> void:
	_run.district_id = &"slums"
	_run.stash_level = 1
	_run.inventory = {&"burner_phones": 2}
	assert_false(Inventory.move_to_stash(_run, _phones, 3))
	assert_eq(Inventory.count(_run, _phones.id), 2)


func test_taking_from_stash_respects_bag_space() -> void:
	_run.district_id = &"slums"
	_run.stash_level = 1
	_run.inventory = {&"burner_phones": Inventory.BASE_CAPACITY - 1}
	_run.stash = {&"burner_sims": 5}
	assert_eq(Inventory.max_from_stash(_run, Content.item(&"burner_sims")), 1)


func test_order_reservation_counts_active_contracts() -> void:
	_run.orders = [
		{"item": "burner_phones", "quantity": 4},
		{"item": "ghost_pistol", "quantity": 2},
	]
	_run.customer_orders = [
		{"item": "burner_phones", "quantity": 3},
	]
	_run.favours = [
		{"item": "burner_phones", "quantity": 1},
	]
	assert_eq(Inventory.reserved_for_orders(_run, &"burner_phones"), 8)
	assert_eq(Inventory.reserved_for_orders(_run, &"ghost_pistol"), 2)
	assert_eq(Inventory.reserved_for_orders(_run, &"ammo_9mm"), 0)


func test_sellable_count_protects_reserved_goods() -> void:
	_run.orders = [{"item": "burner_phones", "quantity": 5}]
	_run.inventory = {&"burner_phones": 7}
	assert_eq(Inventory.sellable_count(_run, &"burner_phones"), 2)

	_run.inventory = {&"burner_phones": 5}
	assert_eq(Inventory.sellable_count(_run, &"burner_phones"), 0)

	_run.inventory = {&"burner_phones": 3}
	assert_eq(Inventory.sellable_count(_run, &"burner_phones"), 0)
