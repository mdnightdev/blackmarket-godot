extends GutTest

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	_run.price_seed = 2468
	_run.tutorial_completed = true
	_run.cash = 5000


func _crate_ping(twist := JobPings.Twist.NONE) -> Dictionary:
	var offer: Dictionary = Smuggling.board(_run).filter(func(entry: Dictionary) -> bool:
		return StringName(str(entry.destination)) != _run.district_id)[0]
	return _ping(JobPings.CRATE, offer, twist)


func _ping(source: String, offer: Dictionary, twist := JobPings.Twist.NONE) -> Dictionary:
	var ping := {
		"id": str(offer.id),
		"source": source,
		"offer": offer.duplicate(),
		"twist": JobPings.Twist.NONE,
		"expires_stamp": Calendar.stamp(_run) + JobPings.OFFER_PHASES - 1,
	}
	if twist != JobPings.Twist.NONE:
		JobPings.apply_twist(_run, ping, twist)
	return ping


func _order_offer() -> Dictionary:
	for entry in JobPings.candidates(_run):
		if entry.source == JobPings.ORDER:
			return entry.offer
	return {}


func _post_over_days(days: int) -> Array[Dictionary]:
	var posted: Array[Dictionary] = []
	for day in range(1, days + 1):
		_run.day = day
		for phase in RunState.Phase.size():
			_run.phase = phase as RunState.Phase
			JobPings.expire(_run)
			posted.append_array(JobPings.post(_run))
	return posted


func test_no_pings_during_the_tutorial() -> void:
	_run.tutorial_completed = false
	assert_true(_post_over_days(5).is_empty())


func test_pings_come_in_and_never_pile_up() -> void:
	var posted := _post_over_days(10)
	assert_gt(posted.size(), 0)
	var ids: Array[String] = []
	for ping in posted:
		assert_true(JobPings.SOURCES.has(str(ping.source)))
		assert_false(ids.has(str(ping.id)), "each board entry rings once")
		ids.append(str(ping.id))
		assert_not_null(JobPings.sender(ping))
		assert_not_null(JobPings.destination(ping))
		assert_gt(JobPings.total_pay(ping), 0)
	assert_lte(_run.job_pings.size(), JobPings.MAX_OPEN)


func test_crate_ping_is_handed_over_where_the_player_stands() -> void:
	_run.district_id = &"downtown"
	var ping := _crate_ping()
	_run.job_pings.append(ping)
	assert_eq(JobPings.accept(_run, str(ping.id)), JobPings.Result.OK)
	assert_true(Smuggling.is_carrying(_run))
	assert_true(_run.job_pings.is_empty())


func test_hot_job_raises_pay_and_heat() -> void:
	var plain := _crate_ping()
	var hot := _crate_ping(JobPings.Twist.HOT)
	assert_gt(JobPings.total_pay(hot), JobPings.total_pay(plain))
	_run.job_pings.append(hot)
	assert_eq(JobPings.accept(_run, str(hot.id)), JobPings.Result.OK)
	assert_eq(_run.heat, JobPings.HOT_HEAT)


func test_fragile_crate_is_marked() -> void:
	var ping := _crate_ping(JobPings.Twist.FRAGILE)
	assert_true(bool(ping.offer.fragile))


func test_rush_order_is_due_sooner() -> void:
	var offer := _order_offer()
	if offer.is_empty():
		fail_test("no reachable bar order to ping")
		return
	var ping := _ping(JobPings.ORDER, offer, JobPings.Twist.RUSH)
	assert_lte(int(ping.offer.due), Calendar.stamp(_run) + JobPings.RUSH_PHASES)
	assert_gt(int(ping.offer.price), int(offer.price))


func test_big_client_doubles_the_lot() -> void:
	var offer := _order_offer()
	if offer.is_empty():
		fail_test("no reachable bar order to ping")
		return
	var ping := _ping(JobPings.ORDER, offer, JobPings.Twist.BIG_CLIENT)
	assert_eq(int(ping.offer.quantity), int(offer.quantity) * JobPings.BIG_CLIENT_QUANTITY)


func test_unanswered_pings_expire() -> void:
	_run.job_pings.append(_crate_ping())
	_run.phase = RunState.Phase.NIGHT
	JobPings.expire(_run)
	assert_true(_run.job_pings.is_empty())
	assert_eq(JobPings.accept(_run, "missing"), JobPings.Result.GONE)


func test_declining_drops_the_ping() -> void:
	var ping := _crate_ping()
	_run.job_pings.append(ping)
	assert_true(JobPings.decline(_run, str(ping.id)))
	assert_true(_run.job_pings.is_empty())


func test_pings_survive_a_save() -> void:
	var ping := _crate_ping(JobPings.Twist.FRAGILE)
	_run.job_pings.append(ping)
	_run.seen_pings.append(str(ping.id))
	var loaded := RunState.from_dict(_run.to_dict())
	assert_eq(loaded.job_pings.size(), 1)
	assert_eq(int(loaded.job_pings[0].twist), JobPings.Twist.FRAGILE)
	assert_true(bool(loaded.job_pings[0].offer.fragile))
	assert_eq(loaded.seen_pings, _run.seen_pings)
