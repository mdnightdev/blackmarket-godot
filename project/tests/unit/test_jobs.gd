extends GutTest

const BAR: StringName = &"tran_bar"

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	_run.price_seed = 777
	_run.cash = 100000


func _take_order(due: int) -> void:
	var offer: Dictionary = Orders.board(_run, BAR)[0].duplicate()
	offer.due = due
	_run.orders.append(offer)


func test_order_due_next_phase_is_soon_but_not_last() -> void:
	var stamp := Calendar.stamp(_run)
	_take_order(stamp + 1)
	assert_eq(Jobs.due_soon(_run).size(), 1)
	assert_true(Jobs.in_last_phase(_run).is_empty())


func test_order_due_this_phase_is_in_last_phase() -> void:
	_take_order(Calendar.stamp(_run))
	var last := Jobs.in_last_phase(_run)
	assert_eq(last.size(), 1)
	assert_string_contains(str(last[0].title), "for ")


func test_far_and_expired_orders_are_not_flagged() -> void:
	var stamp := Calendar.stamp(_run)
	_take_order(stamp + 3)
	_take_order(stamp - 1)
	assert_true(Jobs.due_soon(_run).is_empty())
	assert_true(Jobs.in_last_phase(_run).is_empty())
