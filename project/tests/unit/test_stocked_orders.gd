extends GutTest

const ITEM: StringName = &"street_meds"
const QUANTITY := 4

var _run: RunState
var _watch: StockedOrders


func before_each() -> void:
	_run = RunState.new()
	_watch = StockedOrders.new()


func _order(id: String) -> Dictionary:
	var order := Customers.sanitize({
		"id": id,
		"customer": "rosa_delgado",
		"item": String(ITEM),
		"quantity": QUANTITY,
		"unit_price": 200,
		"district": "old_market",
		"temperament": CustomerDef.Temperament.FAIR,
	})
	_run.customer_orders.append(order)
	return order


func test_an_order_is_announced_once_when_it_fills_up() -> void:
	_order("customer:1")
	assert_true(_watch.check(_run).is_empty())
	Inventory.add_units(_run, ITEM, QUANTITY - 1)
	assert_true(_watch.check(_run).is_empty(), "still short")
	Inventory.add_units(_run, ITEM, 1)
	var filled := _watch.check(_run)
	assert_eq(filled.size(), 1)
	assert_eq(filled[0], "customer:1")
	assert_true(_watch.check(_run).is_empty(), "only once")
	Inventory.discard(_run, ITEM, 1)
	_watch.check(_run)
	Inventory.add_units(_run, ITEM, 1)
	assert_true(_watch.check(_run).is_empty(), "not again after topping back up")


func test_orders_full_when_first_seen_are_not_announced() -> void:
	Inventory.add_units(_run, ITEM, QUANTITY)
	_order("customer:1")
	assert_true(_watch.check(_run).is_empty())


func test_closed_orders_are_forgotten() -> void:
	_order("customer:1")
	_watch.check(_run)
	_run.customer_orders.clear()
	_watch.check(_run)
	Inventory.add_units(_run, ITEM, QUANTITY)
	_order("customer:1")
	assert_true(_watch.check(_run).is_empty(), "a new order under an old id starts fresh")
	_watch.clear()
	assert_true(_watch.check(_run).is_empty())
