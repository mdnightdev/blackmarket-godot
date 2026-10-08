extends GutTest

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	_run.price_seed = 2468


func test_best_buys_names_the_goods_paid_best_relative_to_value() -> void:
	var dealer := Content.dealer_in(_run.district_id)
	var best := DealerTalk.best_buys(_run, dealer)
	assert_eq(best.size(), DealerTalk.NAMED_GOODS)
	var top_ratio := Market.sell_price(_run, dealer, best[0]) / float(best[0].base_price)
	for item in Tiers.goods(dealer.tier):
		assert_true(Market.sell_price(_run, dealer, item) / float(item.base_price) <= top_ratio + 0.0001, item.id)
