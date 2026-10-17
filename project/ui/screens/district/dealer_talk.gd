class_name DealerTalk

## Direct dealer routing: opens MarketScreen directly without intrusive dialogue cards.

const NAMED_GOODS := 2


static func talk_to(dealer: DealerDef) -> void:
	if dealer == null:
		return
	GameState.trading_with = dealer.id
	SceneRouter.go_to(SceneRouter.MARKET_SCREEN)


## The goods this dealer pays the most for right now, best first.
static func best_buys(run: RunState, dealer: DealerDef) -> Array[ItemDef]:
	var goods := Tiers.goods(dealer.tier)
	goods.sort_custom(func(a: ItemDef, b: ItemDef) -> bool:
		return Market.sell_price(run, dealer, a) / float(a.base_price) > Market.sell_price(run, dealer, b) / float(b.base_price))
	return goods.slice(0, NAMED_GOODS)
