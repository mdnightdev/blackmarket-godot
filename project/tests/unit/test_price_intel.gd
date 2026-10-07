extends GutTest

var _run: RunState
var _goods: Array[ItemDef]
var _phones: ItemDef
var _nadia: DealerDef
var _ernesto: DealerDef


func before_each() -> void:
	_run = RunState.new()
	_run.price_seed = 4321
	_goods = Content.items(ItemDef.Kind.TRADE_GOOD)
	_phones = Content.item(&"burner_phones")
	_nadia = Content.dealer(&"nadia")
	_ernesto = Content.dealer(&"ernesto")


func test_record_stores_every_trade_good_once_per_dealer() -> void:
	assert_true(PriceIntel.record(_run, _nadia, _goods))
	assert_eq(_run.price_sightings.size(), _goods.size())
	assert_false(PriceIntel.record(_run, _nadia, _goods), "same phase, same prices, nothing to save")
	assert_eq(_run.price_sightings.size(), _goods.size())


func test_record_uses_the_prices_shown_at_the_market() -> void:
	PriceIntel.record(_run, _ernesto, _goods)
	var sale := PriceIntel.best_sale(_run, _phones, _nadia)
	assert_eq(int(sale.sell), Market.sell_price(_run, _ernesto, _phones))
	assert_eq(sale.district, String(Market.trading_district(_run, _ernesto, Calendar.stamp(_run))))


func test_unstocked_goods_have_no_purchase_price() -> void:
	PriceIntel.record(_run, _ernesto, _goods)
	for item in _goods:
		var purchase := PriceIntel.best_purchase(_run, item, _nadia)
		assert_eq(purchase.is_empty(), not _ernesto.sells(item), String(item.id))


func test_best_sale_ignores_the_current_dealer() -> void:
	PriceIntel.record(_run, _nadia, _goods)
	assert_true(PriceIntel.best_sale(_run, _phones, _nadia).is_empty())
	assert_false(PriceIntel.best_sale(_run, _phones, _ernesto).is_empty())


func test_best_sale_picks_the_highest_offer() -> void:
	_run.price_sightings = [
		_sighting("ernesto", 120, 0),
		_sighting("sapo", 180, 0),
		_sighting("wei", 150, 0),
	]
	assert_eq(PriceIntel.best_sale(_run, _phones, _nadia).dealer, "sapo")


func test_best_purchase_picks_the_lowest_asking() -> void:
	_run.price_sightings = [
		_sighting("ernesto", 100, 0, 140),
		_sighting("sapo", 100, 0, 0),
		_sighting("wei", 100, 0, 120),
	]
	assert_eq(PriceIntel.best_purchase(_run, _phones, _nadia).dealer, "wei")


func test_old_sightings_are_ignored_and_pruned() -> void:
	_run.day = 4
	var now := Calendar.stamp(_run)
	_run.price_sightings = [
		_sighting("ernesto", 500, now - PriceIntel.MAX_AGE_PHASES - 1),
		_sighting("wei", 150, now - PriceIntel.MAX_AGE_PHASES),
	]
	assert_eq(PriceIntel.best_sale(_run, _phones, _nadia).dealer, "wei")
	PriceIntel.prune(_run)
	assert_eq(_run.price_sightings.size(), 1)


func test_new_visit_replaces_the_dealers_old_sightings() -> void:
	PriceIntel.record(_run, _ernesto, _goods)
	Calendar.advance_phase(_run)
	PriceIntel.record(_run, _ernesto, _goods)
	assert_eq(_run.price_sightings.size(), _goods.size())
	assert_eq(int(PriceIntel.best_sale(_run, _phones, _nadia).stamp), Calendar.stamp(_run))


func test_age_text() -> void:
	_run.day = 2
	var now := Calendar.stamp(_run)
	assert_eq(PriceIntel.age_text(_run, {"stamp": now}), "this phase")
	assert_eq(PriceIntel.age_text(_run, {"stamp": now - 1}), "last phase")
	assert_eq(PriceIntel.age_text(_run, {"stamp": now - 3}), "3 phases ago")


func test_sightings_survive_save_and_load() -> void:
	PriceIntel.record(_run, _ernesto, _goods)
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(_run.to_dict())))
	assert_eq(restored.price_sightings, _run.price_sightings)
	assert_false(PriceIntel.record(restored, _ernesto, _goods), "a reload does not count as new intel")


func test_sanitize_fixes_bad_entries() -> void:
	var clean := PriceIntel.sanitize_sighting({"item": "burner_phones", "buy": -5, "sell": "90"})
	assert_eq(clean.buy, 0)
	assert_eq(clean.sell, 90)
	assert_lt(int(clean.stamp), -PriceIntel.MAX_AGE_PHASES, "entries without a stamp count as expired")


func _sighting(dealer_id: String, sell: int, stamp: int, buy := 0) -> Dictionary:
	return {"item": "burner_phones", "dealer": dealer_id, "district": "docks", "buy": buy, "sell": sell, "stamp": stamp}
