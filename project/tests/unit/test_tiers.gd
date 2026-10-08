extends GutTest


func _item(tier: int, display_name := "Burner Phones") -> ItemDef:
	var item := ItemDef.new()
	item.id = StringName("tier_%d" % tier)
	item.display_name = display_name
	item.tier = tier
	return item


func _dealer(tier: int) -> DealerDef:
	var dealer := DealerDef.new()
	dealer.id = &"tier_dealer"
	dealer.tier = tier
	dealer.stock_categories = [&"comms"]
	return dealer


func test_dealers_trade_their_tier_and_the_one_below() -> void:
	var middle := _dealer(Tiers.MIDDLE)
	assert_true(middle.deals_in(_item(Tiers.STREET)))
	assert_true(middle.deals_in(_item(Tiers.MIDDLE)))
	assert_false(middle.deals_in(_item(Tiers.WEALTHY)))


func test_wealthy_dealers_refuse_street_goods_with_a_line() -> void:
	var line := Tiers.refusal(_dealer(Tiers.WEALTHY), _item(Tiers.STREET))
	assert_string_contains(line.to_lower(), "burner phones")
	assert_eq(Tiers.refusal(_dealer(Tiers.WEALTHY), _item(Tiers.MIDDLE)), "")


func test_dealers_only_stock_goods_they_deal_in() -> void:
	var street := _dealer(Tiers.STREET)
	var luxury := _item(Tiers.WEALTHY)
	luxury.category = &"comms"
	assert_false(street.sells(luxury))


func test_tier_goods_lists_match_the_dealer_rule() -> void:
	for tier in [Tiers.STREET, Tiers.MIDDLE, Tiers.WEALTHY]:
		var dealer := _dealer(tier)
		for item in Tiers.goods(tier):
			assert_true(dealer.deals_in(item), item.id)


func test_every_dealer_works_a_district_of_the_same_tier() -> void:
	for dealer in Content.dealers():
		var district := Content.district(dealer.district_id)
		assert_not_null(district, dealer.id)
		assert_eq(dealer.tier, district.tier, dealer.id)
		for stop in dealer.route:
			assert_eq(Content.district(stop).tier, dealer.tier, "%s route %s" % [dealer.id, stop])
