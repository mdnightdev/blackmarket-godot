extends GutTest

const BAR: StringName = &"tran_bar"

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	_run.price_seed = 2468


func test_rumor_names_a_dealer_trading_elsewhere() -> void:
	var rumor := Rumors.find(_run, BAR)
	assert_false(rumor.is_empty())
	var dealer: DealerDef = rumor.dealer
	var location := Roster.dealer_location(_run, dealer, Calendar.stamp(_run))
	assert_ne(location, _run.district_id)
	assert_eq(rumor.district, Content.district(location))
	assert_eq(int(rumor.price), Market.sell_price(_run, dealer, rumor.item))


func test_buying_charges_and_adds_price_intel() -> void:
	var rumor := Rumors.buy(_run, BAR)
	assert_false(rumor.is_empty())
	assert_eq(_run.cash, RunState.STARTING_CASH - Rumors.PRICE)
	var sale := PriceIntel.best_sale(_run, rumor.item, null)
	assert_eq(sale.dealer, String(rumor.dealer.id))


func test_one_rumor_per_bar_per_phase() -> void:
	Rumors.buy(_run, BAR)
	assert_true(Rumors.sold_out(_run, BAR))
	assert_true(Rumors.buy(_run, BAR).is_empty())
	assert_false(Rumors.sold_out(_run, &"la_paloma"), "the other bar still sells")
	Calendar.advance_phase(_run)
	assert_false(Rumors.sold_out(_run, BAR))


func test_no_charge_without_cash() -> void:
	_run.cash = Rumors.PRICE - 1
	assert_true(Rumors.buy(_run, BAR).is_empty())
	assert_eq(_run.cash, Rumors.PRICE - 1)


func test_rumors_skip_dealers_already_seen_this_phase() -> void:
	var goods := Content.items(ItemDef.Kind.TRADE_GOOD)
	for dealer in Content.dealers():
		PriceIntel.record(_run, dealer, goods)
	assert_true(Rumors.find(_run, BAR).is_empty())
	var cash := _run.cash
	assert_true(Rumors.buy(_run, BAR).is_empty())
	assert_eq(_run.cash, cash, "nothing new means no charge")


func test_heard_rumors_survive_save_and_load() -> void:
	Rumors.buy(_run, BAR)
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(_run.to_dict())))
	assert_true(Rumors.sold_out(restored, BAR))
