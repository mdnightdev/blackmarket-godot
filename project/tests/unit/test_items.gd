extends GutTest


func test_goods_and_gear_load() -> void:
	assert_between(Content.items(ItemDef.Kind.TRADE_GOOD).size(), 60, 75)
	assert_eq(Content.items(ItemDef.Kind.EQUIPMENT).size(), 6)


func test_items_are_sorted_cheapest_first() -> void:
	var goods := Content.items(ItemDef.Kind.TRADE_GOOD)
	for index in range(1, goods.size()):
		assert_true(goods[index - 1].base_price <= goods[index].base_price)


func test_every_item_has_name_icon_and_description() -> void:
	for kind: ItemDef.Kind in [ItemDef.Kind.TRADE_GOOD, ItemDef.Kind.EQUIPMENT]:
		for item in Content.items(kind):
			var label := String(item.id)
			assert_false(item.display_name.is_empty(), label)
			assert_false(item.description.is_empty(), label)
			assert_not_null(item.icon, label)


func test_every_gear_item_does_something() -> void:
	for item in Content.items(ItemDef.Kind.EQUIPMENT):
		assert_false(Gear.describe(item).is_empty(), String(item.id))


func test_every_market_district_has_a_dealer() -> void:
	for district in Content.districts():
		if district.venues.has(&"market"):
			assert_not_null(Content.dealer_in(district.id), String(district.id))


func test_dealers_stock_real_categories() -> void:
	var categories := {}
	for item in Content.items(ItemDef.Kind.TRADE_GOOD):
		categories[item.category] = true
	for dealer in Content.dealers():
		assert_not_null(Content.district(dealer.district_id), String(dealer.id))
		assert_false(dealer.stock_categories.is_empty(), String(dealer.id))
		for category in dealer.stock_categories:
			assert_true(categories.has(category), "%s stocks %s" % [dealer.id, category])
