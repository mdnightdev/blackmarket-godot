extends GutTest

var _run: RunState


func before_each() -> void:
	_run = RunState.new()


func test_new_runs_start_as_nobody() -> void:
	assert_eq(StreetCred.rank(_run), 1)
	assert_eq(StreetCred.rank_name(1), "Nobody")


func test_ranks_follow_the_thresholds() -> void:
	assert_eq(StreetCred.rank_for(49), 1)
	assert_eq(StreetCred.rank_for(50), 2)
	assert_eq(StreetCred.rank_for(300), 4)
	assert_eq(StreetCred.rank_for(StreetCred.MAX), StreetCred.max_rank())
	assert_eq(StreetCred.next_rank_cred(1), 50)
	assert_eq(StreetCred.next_rank_cred(StreetCred.max_rank()), -1)


func test_cred_is_clamped() -> void:
	StreetCred.add(_run, -50)
	assert_eq(_run.street_cred, 0)
	StreetCred.add(_run, StreetCred.MAX + 500)
	assert_eq(_run.street_cred, StreetCred.MAX)


func test_sales_earn_capped_cred() -> void:
	assert_eq(StreetCred.add_from_sale(_run, 499), 0)
	assert_eq(StreetCred.add_from_sale(_run, 1000), 2)
	assert_eq(StreetCred.add_from_sale(_run, 50_000), StreetCred.MAX_SALE_GAIN)
	assert_eq(_run.street_cred, 2 + StreetCred.MAX_SALE_GAIN)


func test_trading_cred_has_a_daily_cap() -> void:
	for sale in 20:
		StreetCred.add_from_sale(_run, 5000)
	assert_eq(_run.street_cred, StreetCred.DAILY_TRADING_CAP)
	_run.day += 1
	assert_eq(StreetCred.add_from_sale(_run, 5000), StreetCred.MAX_SALE_GAIN)


func test_selling_goods_raises_cred() -> void:
	var phones := Content.item(&"burner_phones")
	Trade.buy(_run, phones, 10, 100)
	Trade.sell(_run, phones, 10, 150)
	assert_eq(_run.street_cred, StreetCred.MAX_SALE_GAIN)


func test_getting_busted_costs_cred() -> void:
	_run.street_cred = 100
	Police.arrest(_run)
	assert_eq(_run.street_cred, 100 + StreetCred.BUSTED)


func test_cred_survives_a_save() -> void:
	_run.street_cred = 420
	_run.cred_day = 3
	_run.trading_cred_today = 12
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(_run.to_dict())))
	assert_eq(restored.street_cred, 420)
	assert_eq(restored.cred_day, 3)
	assert_eq(restored.trading_cred_today, 12)
