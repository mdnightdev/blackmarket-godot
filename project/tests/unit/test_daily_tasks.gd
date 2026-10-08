extends GutTest

const OLD_MARKET: StringName = &"old_market"
const DOCKS: StringName = &"docks"
const DAYS_CHECKED := 40

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	_run.price_seed = 777


func test_deal_fills_the_board_once_per_day() -> void:
	assert_true(DailyTasks.deal(_run))
	assert_eq(_run.daily_tasks.size(), DailyTasks.COUNT)
	assert_eq(_run.tasks_day, _run.day)
	var dealt := _run.daily_tasks.duplicate(true)
	assert_false(DailyTasks.deal(_run), "already dealt today")
	assert_eq(_run.daily_tasks, dealt)


func test_same_seed_and_day_deal_the_same_tasks() -> void:
	var other := RunState.new()
	other.price_seed = _run.price_seed
	for day in range(1, DAYS_CHECKED):
		_run.day = day
		other.day = day
		DailyTasks.deal(_run)
		DailyTasks.deal(other)
		assert_eq(other.daily_tasks, _run.daily_tasks, "day %d" % day)


func test_other_seeds_deal_other_tasks() -> void:
	var other := RunState.new()
	other.price_seed = _run.price_seed + 1
	var differs := false
	for day in range(1, DAYS_CHECKED):
		_run.day = day
		other.day = day
		DailyTasks.deal(_run)
		DailyTasks.deal(other)
		differs = differs or other.daily_tasks != _run.daily_tasks
	assert_true(differs)


func test_new_day_deals_fresh_tasks() -> void:
	DailyTasks.deal(_run)
	DailyTasks.record_delivery(_run)
	_run.day += 1
	assert_true(DailyTasks.deal(_run))
	assert_eq(_run.tasks_day, _run.day)
	for task in _run.daily_tasks:
		assert_true(str(task.id).ends_with(":%d" % (_run.day - 1)), task.id)
		assert_eq(int(task.progress), 0)
		assert_false(bool(task.done))


func test_tasks_have_distinct_kinds_and_valid_entries() -> void:
	var kinds_seen := {}
	for day in range(1, DAYS_CHECKED):
		_run.day = day
		DailyTasks.deal(_run)
		var kinds := {}
		for task in _run.daily_tasks:
			assert_false(kinds.has(task.kind), "day %d repeats %s" % [day, task.kind])
			kinds[task.kind] = true
			kinds_seen[task.kind] = true
			assert_eq(DailyTasks.sanitize(task), task)
			assert_false(DailyTasks.describe(task).is_empty(), task.id)
	assert_eq(kinds_seen.size(), DailyTasks.KINDS.size(), "every kind shows up")


func test_dealt_targets_follow_the_rules() -> void:
	for day in range(1, DAYS_CHECKED):
		_run.day = day
		DailyTasks.deal(_run)
		for task in _run.daily_tasks:
			match StringName(task.kind):
				DailyTasks.SELL_VALUE:
					assert_eq(int(task.target), DailyTasks.sell_target(day))
					assert_true(Content.district(StringName(task.district)).venues.has(DailyTasks.MARKET_VENUE), task.district)
				DailyTasks.DELIVER_JOB:
					assert_between(int(task.target), 1, DailyTasks.MAX_DELIVERIES)
				DailyTasks.VISIT:
					assert_ne(StringName(task.district), _run.district_id)
					assert_eq(int(task.target), 1)
				_:
					assert_eq(int(task.target), 1)
					assert_eq(task.district, "")


func test_locked_districts_are_never_picked() -> void:
	for day in range(1, DAYS_CHECKED):
		_run.day = day
		DailyTasks.deal(_run)
		for task in _run.daily_tasks:
			if not str(task.district).is_empty():
				var district := Content.district(StringName(task.district))
				assert_false(Travel.is_locked(_run, district), task.id)


func test_sell_target_scales_with_day() -> void:
	assert_eq(DailyTasks.sell_target(1), 1700)
	assert_eq(DailyTasks.sell_target(2), 1800)
	assert_eq(DailyTasks.sell_target(10), 3000)


func test_reward_grows_with_the_day() -> void:
	for day in [1, 5]:
		_run.day = day
		assert_eq(DailyTasks.reward(_run), DailyTasks.MIN_REWARD)
	_run.day = 10
	assert_eq(DailyTasks.reward(_run), 300)
	_run.day = 30
	assert_eq(DailyTasks.reward(_run), 900)


func test_sales_count_only_in_the_named_district() -> void:
	var task := _give(DailyTasks.SELL_VALUE, 2400, OLD_MARKET)
	assert_true(DailyTasks.record_sale(_run, DOCKS, 5000).is_empty())
	assert_eq(int(task.progress), 0)
	assert_true(DailyTasks.record_sale(_run, OLD_MARKET, 900).is_empty())
	assert_eq(int(task.progress), 900)
	var cash_before := _run.cash
	var completed := DailyTasks.record_sale(_run, OLD_MARKET, 2000)
	assert_eq(completed, [task] as Array[Dictionary])
	assert_true(bool(task.done))
	assert_eq(int(task.progress), 2400, "progress stops at the target")
	assert_eq(_run.cash, cash_before + DailyTasks.reward(_run))
	assert_eq(_run.street_cred, StreetCred.TASK_DONE)


func test_deliveries_count_up_to_the_target() -> void:
	var task := _give(DailyTasks.DELIVER_JOB, 2)
	assert_true(DailyTasks.record_delivery(_run).is_empty())
	assert_eq(DailyTasks.progress_text(task), "1 / 2")
	assert_eq(DailyTasks.record_delivery(_run).size(), 1)
	assert_true(bool(task.done))


func test_casino_win_completes() -> void:
	var task := _give(DailyTasks.CASINO_WIN, 1)
	assert_eq(DailyTasks.record_casino_win(_run), [task] as Array[Dictionary])


func test_arrival_completes_only_at_the_destination() -> void:
	var task := _give(DailyTasks.VISIT, 1, DOCKS)
	assert_true(DailyTasks.record_arrival(_run, OLD_MARKET).is_empty())
	assert_eq(DailyTasks.record_arrival(_run, DOCKS), [task] as Array[Dictionary])


func test_cool_day_needs_heat_under_the_limit() -> void:
	var task := _give(DailyTasks.END_DAY_COOL, 1)
	_run.heat = DailyTasks.COOL_HEAT
	assert_true(DailyTasks.close_day(_run).is_empty())
	assert_false(bool(task.done))
	_run.heat = DailyTasks.COOL_HEAT - 1
	assert_eq(DailyTasks.close_day(_run), [task] as Array[Dictionary])


func test_hooks_only_touch_their_own_kind() -> void:
	var visit := _give(DailyTasks.VISIT, 1, DOCKS)
	var casino := _give(DailyTasks.CASINO_WIN, 1)
	DailyTasks.record_delivery(_run)
	DailyTasks.record_sale(_run, DOCKS, 10000)
	DailyTasks.close_day(_run)
	assert_eq(int(visit.progress), 0)
	assert_eq(int(casino.progress), 0)


func test_finished_tasks_never_pay_twice() -> void:
	_give(DailyTasks.CASINO_WIN, 1)
	DailyTasks.record_casino_win(_run)
	var cash_before := _run.cash
	var cred_before := _run.street_cred
	assert_true(DailyTasks.record_casino_win(_run).is_empty())
	assert_eq(_run.cash, cash_before)
	assert_eq(_run.street_cred, cred_before)


func test_tasks_from_another_day_are_ignored() -> void:
	var task := _give(DailyTasks.DELIVER_JOB, 1)
	_run.day += 1
	assert_true(DailyTasks.record_delivery(_run).is_empty())
	assert_true(DailyTasks.close_day(_run).is_empty())
	assert_false(bool(task.done))


func test_describe_and_progress_text() -> void:
	var sale := _give(DailyTasks.SELL_VALUE, 2400, OLD_MARKET)
	DailyTasks.record_sale(_run, OLD_MARKET, 900)
	assert_eq(DailyTasks.describe(sale), "Sell $2,400 in Old Market")
	assert_eq(DailyTasks.progress_text(sale), "$900 / $2,400")
	var visit := _give(DailyTasks.VISIT, 1, DOCKS)
	assert_eq(DailyTasks.describe(visit), "Travel to The Docks")
	assert_eq(DailyTasks.progress_text(visit), "0 / 1")
	assert_eq(DailyTasks.describe(_give(DailyTasks.DELIVER_JOB, 2)), "Complete 2 deliveries")
	assert_eq(DailyTasks.describe(_give(DailyTasks.END_DAY_COOL, 1)), "End the day under %d heat" % DailyTasks.COOL_HEAT)
	assert_eq(DailyTasks.describe(_give(DailyTasks.CASINO_WIN, 1)), "Win a casino game")


func test_tasks_survive_save_and_load() -> void:
	DailyTasks.deal(_run)
	DailyTasks.record_delivery(_run)
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(_run.to_dict())))
	assert_eq(restored.tasks_day, _run.tasks_day)
	assert_eq(restored.daily_tasks.size(), _run.daily_tasks.size())
	for index in _run.daily_tasks.size():
		assert_eq(DailyTasks.sanitize(restored.daily_tasks[index]), _run.daily_tasks[index])
	assert_false(DailyTasks.deal(restored), "a reload does not redeal")


func test_sanitize_fixes_bad_entries() -> void:
	assert_true(DailyTasks.sanitize({"kind": "unknown"}).is_empty())
	assert_true(DailyTasks.sanitize({"kind": "visit", "district": "nowhere"}).is_empty())
	var clean := DailyTasks.sanitize({"kind": "casino_win", "target": -2, "progress": 9, "district": "docks"})
	assert_eq(clean.target, 1)
	assert_eq(clean.progress, 1)
	assert_eq(clean.district, "", "kinds without a district drop it")
	assert_false(clean.done)


func _give(kind: StringName, target: int, district_id: StringName = &"") -> Dictionary:
	var task := DailyTasks.sanitize({"id": "%s:%d" % [kind, _run.day - 1], "kind": kind, "target": target, "district": district_id})
	_run.daily_tasks.append(task)
	_run.tasks_day = _run.day
	return task
