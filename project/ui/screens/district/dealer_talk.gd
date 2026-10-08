class_name DealerTalk

## A word with a dealer on the street before trading: trade, ask what they pay best for, or walk on.

const TRADE: StringName = &"trade"
const ASK: StringName = &"ask"
const LEAVE: StringName = &"leave"
const NAMED_GOODS := 2

static var _dealer: DealerDef


static func talk_to(dealer: DealerDef) -> void:
	_dealer = dealer
	var choices: Array[DialogueChoice] = [
		DialogueChoice.new(TRADE, "Trade"),
		DialogueChoice.new(ASK, "What are you paying for?"),
		DialogueChoice.new(LEAVE, "Leave", true, true),
	]
	GameOverlay.talk(dealer, dealer.greeting, choices, _on_choice)


## The goods this dealer pays the most for right now, best first.
static func best_buys(run: RunState, dealer: DealerDef) -> Array[ItemDef]:
	var goods := Content.items(ItemDef.Kind.TRADE_GOOD)
	goods.sort_custom(func(a: ItemDef, b: ItemDef) -> bool:
		return Market.sell_price(run, dealer, a) / float(a.base_price) > Market.sell_price(run, dealer, b) / float(b.base_price))
	return goods.slice(0, NAMED_GOODS)


static func _on_choice(choice: StringName) -> void:
	match choice:
		TRADE:
			GameOverlay.end_talk()
			GameState.trading_with = _dealer.id
			SceneRouter.go_to(SceneRouter.MARKET_SCREEN)
		ASK:
			var run := GameState.run
			var named: PackedStringArray = []
			for item in best_buys(run, _dealer):
				named.append("%s at %s" % [item.display_name, Format.money(Market.sell_price(run, _dealer, item))])
			var line := "Today I pay best for %s. Bring me those." % " and ".join(named)
			var choices: Array[DialogueChoice] = [
				DialogueChoice.new(TRADE, "Trade"),
				DialogueChoice.new(LEAVE, "Leave", true, true),
			]
			GameOverlay.say(line, choices, _on_choice)
		_:
			GameOverlay.end_talk()
