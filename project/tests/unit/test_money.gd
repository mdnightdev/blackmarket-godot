extends GutTest

var _run: RunState
var _shop: BusinessDef
var _wash: BusinessDef


func before_each() -> void:
	_run = RunState.new()
	_run.career = true
	_run.cash = 500000
	_run.clean = 10000
	_run.district_id = &"old_market"
	Story.mark(_run, War.VEX_FELL)
	_shop = Content.business(&"corner_shop")
	_wash = Content.business(&"car_wash")
	_run.street_cred = int(StreetCred.RANKS[_shop.min_rank - 1].cred)
	Corners.take_all(_run, &"old_market")


func test_seizure_severity_distribution_and_50_percent_cap() -> void:
	var low := Money.roll_seizure(0.0)
	assert_eq(low.level, 1)
	assert_almost_eq(low.share, 0.10, 0.001)

	var mid := Money.roll_seizure(0.50)
	assert_true(mid.level >= 6 and mid.level <= 8)
	assert_true(mid.share >= 0.30 and mid.share <= 0.35)

	var max_seizure := Money.roll_seizure(0.99)
	assert_eq(max_seizure.level, 10)
	assert_almost_eq(max_seizure.share, 0.50, 0.001, "harshness is hard-capped at 50%")


func test_business_daily_revenue_uses_10_15_25_rates() -> void:
	# $100,000 Corner Shop
	assert_eq(Businesses.daily_revenue(_shop, 0.1), 10000, "10% off-peak")
	assert_eq(Businesses.daily_revenue(_shop, 0.5), 15000, "15% stable")
	assert_eq(Businesses.daily_revenue(_shop, 0.9), 25000, "25% peak")

	# $200,000 custom asset
	var big_asset := BusinessDef.new()
	big_asset.price = 200000
	assert_eq(Businesses.daily_revenue(big_asset, 0.1), 20000, "10% off-peak on 200k")
	assert_eq(Businesses.daily_revenue(big_asset, 0.5), 30000, "15% stable on 200k generates exactly 30k")
	assert_eq(Businesses.daily_revenue(big_asset, 0.9), 50000, "25% peak on 200k")


func test_businesses_generate_clean_revenue_in_morning() -> void:
	assert_eq(Businesses.buy(_run, _shop, &"old_market"), Businesses.Result.OK)
	var entry: Dictionary = _run.businesses.back()
	assert_true(Businesses.is_open(_run, entry))
	var clean_before := _run.clean

	var report := Businesses.morning(_run, [0.5])
	assert_gt(report.clean_revenue, 0)
	assert_eq(_run.clean, clean_before + report.clean_revenue)


func test_laundering_3_day_pipeline() -> void:
	assert_eq(Businesses.buy(_run, _shop, &"old_market"), Businesses.Result.OK)
	var entry: Dictionary = _run.businesses.back()

	var free_cap := Money.launder_capacity_free(_run, entry)
	assert_eq(free_cap, _shop.effective_launder_capacity())

	# Start laundering $5,000 at Corner Shop (20% fee)
	_run.cash = 10000
	_run.clean = 0
	assert_true(Money.start_laundering(_run, entry, 5000))
	assert_eq(_run.cash, 5000)
	assert_eq(_run.laundering.size(), 1)
	assert_eq(_run.laundering[0].days_left, 3)

	# Day 1 morning advance: days_left becomes 2
	var day1 := Money.advance_laundering(_run)
	assert_eq(day1.completed_batches, 0)
	assert_eq(_run.clean, 0)
	assert_eq(_run.laundering[0].days_left, 2)

	# Day 2 morning advance: days_left becomes 1
	var day2 := Money.advance_laundering(_run)
	assert_eq(day2.completed_batches, 0)
	assert_eq(_run.clean, 0)
	assert_eq(_run.laundering[0].days_left, 1)

	# Day 3 morning advance: completes, 20% fee deducted ($5000 - $1000 = $4000 clean)
	var day3 := Money.advance_laundering(_run)
	assert_eq(day3.completed_batches, 1)
	assert_eq(day3.cleaned_clean, 4000)
	assert_eq(_run.clean, 4000)
	assert_true(_run.laundering.is_empty())


func test_raid_on_front_seizes_dirty_cash_on_the_books() -> void:
	assert_eq(Businesses.buy(_run, _shop, &"old_market"), Businesses.Result.OK)
	var entry: Dictionary = _run.businesses.back()
	Money.start_laundering(_run, entry, 4000)

	# Raid front with 30% seizure share
	var seized := Money.raid_front(_run, &"old_market", _shop.id, 0.30)
	assert_eq(seized, 1200)
	assert_eq(_run.laundering[0].dirty_amount, 2800)


func test_clean_to_dirty_bank_withdrawal_and_frenzy() -> void:
	_run.clean = 20000
	_run.cash = 0
	_run.heat = 0
	_run.heat_timer = 0.0

	assert_true(Money.withdraw_clean(_run, 10000))
	assert_eq(_run.clean, 10000)
	assert_eq(_run.cash, 10000)
	assert_gt(_run.heat_timer, 0.0, "large bank withdrawal triggers active frenzy")
	assert_gt(_run.heat, 0, "paper trail adds heat")


func test_carried_dirty_cash_seizure_only_above_threshold() -> void:
	_run.cash = 15000
	var no_seizure := Money.check_carried_seizure(_run, 0.5)
	assert_eq(no_seizure.seized, 0)
	assert_eq(_run.cash, 15000)

	_run.cash = 30000  # $10,000 excess above $20k
	var seizure := Money.check_carried_seizure(_run, 0.0)  # level 1 = 10%
	assert_eq(seizure.seized, 1000)
	assert_eq(_run.cash, 29000)


func test_money_state_survives_save() -> void:
	_run.clean = 75000
	_run.heat_timer = 120.0
	_run.laundering = [
		{ "business": "corner_shop", "district": "old_market", "dirty_amount": 5000, "days_left": 2, "fee": 0.2 }
	]

	var saved := _run.to_dict()
	var loaded := RunState.from_dict(saved)

	assert_eq(loaded.clean, 75000)
	assert_almost_eq(loaded.heat_timer, 120.0, 0.01)
	assert_eq(loaded.laundering.size(), 1)
	assert_eq(loaded.laundering[0].dirty_amount, 5000)
	assert_eq(loaded.laundering[0].days_left, 2)


func test_financial_instrument_ownership_and_free_capacity() -> void:
	assert_false(Money.has_instrument(_run, &"swiss_ledgers"))
	assert_eq(Money.instrument_capacity_free(_run, &"swiss_ledgers"), 0)

	_run.inventory[&"swiss_ledgers"] = 1
	assert_true(Money.has_instrument(_run, &"swiss_ledgers"))
	assert_eq(Money.instrument_capacity_free(_run, &"swiss_ledgers"), 100000)

	_run.cash = 150000
	assert_true(Money.start_instrument_laundering(_run, &"swiss_ledgers", 40000))
	assert_eq(_run.cash, 110000)
	assert_eq(Money.instrument_capacity_free(_run, &"swiss_ledgers"), 60000)
	assert_eq(Money.total_laundering_in_transit(_run), 40000)

	# Cannot exceed remaining cap
	assert_false(Money.start_instrument_laundering(_run, &"swiss_ledgers", 70000))


func test_financial_instrument_pipeline_clearing() -> void:
	# Shell company: 2 days, 10% fee
	_run.stash[&"shell_company"] = 1
	assert_true(Money.has_instrument(_run, &"shell_company"))
	_run.cash = 200000
	_run.clean = 0

	assert_true(Money.start_instrument_laundering(_run, &"shell_company", 100000))
	assert_eq(_run.cash, 100000)
	assert_eq(_run.laundering.size(), 1)
	assert_eq(_run.laundering[0].days_left, 2)

	var d1 := Money.advance_laundering(_run)
	assert_eq(d1.completed_batches, 0)
	assert_eq(_run.clean, 0)
	assert_eq(_run.laundering[0].days_left, 1)

	var d2 := Money.advance_laundering(_run)
	assert_eq(d2.completed_batches, 1)
	assert_eq(d2.cleaned_clean, 90000)
	assert_eq(_run.clean, 90000)
	assert_true(_run.laundering.is_empty())

	# Offshore access: 1 day, 5% fee
	_run.inventory[&"offshore_access"] = 1
	_run.cash = 1000000
	assert_true(Money.start_instrument_laundering(_run, &"offshore_access", 500000))
	assert_eq(_run.cash, 500000)
	assert_eq(_run.laundering.size(), 1)
	assert_eq(_run.laundering[0].days_left, 1)

	var d3 := Money.advance_laundering(_run)
	assert_eq(d3.completed_batches, 1)
	assert_eq(d3.cleaned_clean, 475000)
	assert_eq(_run.clean, 90000 + 475000)
	assert_true(_run.laundering.is_empty())
