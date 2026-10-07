extends GutTest


func test_buy_offer_inside_tolerance_is_accepted() -> void:
	var response := Haggle.respond(1000, 920, true, 0.1)
	assert_eq(response.outcome, Haggle.Outcome.ACCEPTED)
	assert_eq(response.price, 920)


func test_greedy_buy_offer_gets_counter_at_dealer_limit() -> void:
	var response := Haggle.respond(1000, 850, true, 0.1)
	assert_eq(response.outcome, Haggle.Outcome.COUNTERED)
	assert_eq(response.price, 900)


func test_insulting_buy_offer_ends_the_talk() -> void:
	assert_eq(Haggle.respond(1000, 750, true, 0.1).outcome, Haggle.Outcome.WALKED)


func test_sell_offers_mirror_buy_offers() -> void:
	assert_eq(Haggle.respond(1000, 1080, false, 0.1).outcome, Haggle.Outcome.ACCEPTED)
	var counter := Haggle.respond(1000, 1150, false, 0.1)
	assert_eq(counter.outcome, Haggle.Outcome.COUNTERED)
	assert_eq(counter.price, 1100)
	assert_eq(Haggle.respond(1000, 1300, false, 0.1).outcome, Haggle.Outcome.WALKED)


func test_offer_range_limits_haggling() -> void:
	assert_eq(Haggle.offer_range(1000, true), Vector2i(700, 1000))
	assert_eq(Haggle.offer_range(1000, false), Vector2i(1000, 1300))


func test_tools_widen_and_risk_narrows_tolerance() -> void:
	var run := RunState.new()
	var dealer := Content.dealer_in(&"old_market")
	var safe := Content.item(&"burner_sims")
	var risky := Content.item(&"ghost_passports")
	var base := Haggle.tolerance(run, dealer, safe)
	assert_lt(Haggle.tolerance(run, dealer, risky), base)
	run.gear.append(&"jewellers_loupe")
	assert_almost_eq(Haggle.tolerance(run, dealer, safe), base + 0.05, 0.0001)


func test_tolerance_never_drops_below_minimum() -> void:
	var run := RunState.new()
	var dealer := DealerDef.new()
	dealer.haggle_tolerance = 0.0
	var item := ItemDef.new()
	item.risk = 100
	assert_eq(Haggle.tolerance(run, dealer, item), Haggle.MIN_TOLERANCE)


func test_mood_labels() -> void:
	assert_eq(Haggle.mood_label(0.2), "Relaxed")
	assert_eq(Haggle.mood_label(0.1), "Wary")
	assert_eq(Haggle.mood_label(0.05), "Tense")
