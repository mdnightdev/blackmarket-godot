class_name StockedOrders
extends RefCounted

## Remembers which accepted customer orders already have every unit in the bag, so each one is announced
## once when it fills up. An order that was already full when first seen never gets announced.

var _stocked: Dictionary = {}


func clear() -> void:
	_stocked.clear()


## Returns the ids of the orders that filled up since the last check.
func check(run: RunState) -> Array[String]:
	var filled: Array[String] = []
	var current := {}
	for order in run.customer_orders:
		var id := str(order.id)
		var stocked := Customers.is_stocked(run, order)
		var was_stocked: bool = _stocked.get(id, stocked)
		if stocked and not was_stocked:
			filled.append(id)
		current[id] = stocked or was_stocked
	_stocked = current
	return filled
