extends GutTest

var _run: RunState
var _no_events: Array[EventDef] = []


func before_each() -> void:
	_run = RunState.new()


func _start_day(day: int) -> void:
	_run.day = day
	Encounters.after_time_passes(_run, true, false, RandomNumberGenerator.new(), _no_events)


func test_clearing_the_debt_wins() -> void:
	_run.district_id = &"downtown"
	_run.cash = 10_000
	Loan.repay(_run, RunState.STARTING_DEBT)
	assert_true(Campaign.update_outcome(_run))
	assert_eq(_run.outcome, RunState.Outcome.WON)
	assert_true(Campaign.is_over(_run))


func test_endless_mode_continues_after_a_win() -> void:
	_run.debt = 0
	Campaign.update_outcome(_run)
	Campaign.continue_endless(_run)
	assert_false(Campaign.is_over(_run))
	_run.debt = 2000
	_start_day(RunState.CAMPAIGN_DAYS + 5)
	assert_eq(_run.outcome, RunState.Outcome.WON)
	assert_false(Campaign.is_over(_run))


func test_owing_after_the_last_day_loses() -> void:
	_start_day(RunState.CAMPAIGN_DAYS)
	assert_eq(_run.outcome, RunState.Outcome.ONGOING)
	_start_day(RunState.CAMPAIGN_DAYS + 1)
	assert_eq(_run.outcome, RunState.Outcome.LOST)
	assert_true(Campaign.is_over(_run))
	assert_true(_run.pending_encounter.is_empty())


func test_endless_needs_a_win() -> void:
	_run.day = RunState.CAMPAIGN_DAYS + 1
	Campaign.update_outcome(_run)
	Campaign.continue_endless(_run)
	assert_false(_run.endless)
	assert_true(Campaign.is_over(_run))


func test_net_worth_counts_goods_and_stash() -> void:
	Inventory.add_units(_run, &"burner_phones", 2)
	_run.stash[&"fake_ids"] = 1
	assert_eq(Campaign.net_worth(_run), RunState.STARTING_CASH - RunState.STARTING_DEBT + 200 + 180)


func test_trades_and_profit_are_tracked() -> void:
	var phones := Content.item(&"burner_phones")
	Trade.buy(_run, phones, 4, 100)
	Trade.sell(_run, phones, 3, 150)
	assert_eq(_run.trades, 2)
	assert_eq(_run.profit, 150)


func test_outcome_survives_a_save() -> void:
	_run.debt = 0
	Campaign.update_outcome(_run)
	Campaign.continue_endless(_run)
	_run.busts = 2
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(_run.to_dict())))
	assert_eq(restored.outcome, RunState.Outcome.WON)
	assert_true(restored.endless)
	assert_eq(restored.busts, 2)
