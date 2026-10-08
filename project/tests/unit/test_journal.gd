extends GutTest

const BAR: StringName = &"tran_bar"

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	_run.price_seed = 777
	_run.cash = 100000


func _take_order() -> Dictionary:
	var offer: Dictionary = Orders.board(_run, BAR)[0]
	assert_eq(Orders.accept(_run, offer), Orders.Result.OK)
	return _run.orders[0]


func test_delivered_order_is_logged_as_completed() -> void:
	var order := _take_order()
	var before := Jobs.deadlines(_run)
	Inventory.add_units(_run, StringName(order.item), int(order.quantity))
	assert_true(Orders.deliver(_run, order))
	Journal.record_finished(_run, before)
	assert_eq(Journal.entries(_run, false).size(), 1)
	assert_eq(Journal.entries(_run, true).size(), 0)


func test_dropped_order_is_logged_as_failed() -> void:
	var order := _take_order()
	var before := Jobs.deadlines(_run)
	Orders.drop(_run, order)
	Journal.record_finished(_run, before)
	assert_eq(Journal.entries(_run, true).size(), 1)
	assert_true(_run.failed_job_ids.is_empty())


func test_expired_order_is_logged_as_failed() -> void:
	var order := _take_order()
	var before := Jobs.deadlines(_run)
	var stamp := int(order.due) + 1
	_run.day = floori(float(stamp) / RunState.Phase.size()) + 1
	_run.phase = (stamp % RunState.Phase.size()) as RunState.Phase
	Orders.expire(_run)
	Journal.record_finished(_run, before)
	assert_eq(Journal.entries(_run, true).size(), 1)


func test_journal_is_capped_and_survives_a_save() -> void:
	for index in Journal.MAX_ENTRIES + 5:
		var before: Array[Dictionary] = [{ "id": "job:%d" % index, "title": "Job %d" % index, "place": "", "due": 99 }]
		Journal.record_finished(_run, before)
	assert_eq(_run.journal.size(), Journal.MAX_ENTRIES)
	assert_eq(str(_run.journal[0].title), "Job %d" % (Journal.MAX_ENTRIES + 4))
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(_run.to_dict())))
	assert_eq(restored.journal, _run.journal)
