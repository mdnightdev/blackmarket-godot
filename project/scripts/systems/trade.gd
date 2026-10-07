class_name Trade

enum Result { OK, INVALID_QUANTITY, NOT_ENOUGH_CASH, NO_SPACE, NOT_ENOUGH_UNITS, ALREADY_OWNED }


static func max_buyable(run: RunState, item: ItemDef, unit_price: int) -> int:
	var affordable := floori(float(run.cash) / unit_price)
	var fits := floori(float(Inventory.free_space(run)) / item.slots)
	return maxi(0, mini(affordable, fits))


static func check_buy(run: RunState, item: ItemDef, quantity: int, unit_price: int) -> Result:
	if quantity <= 0:
		return Result.INVALID_QUANTITY
	if unit_price * quantity > run.cash:
		return Result.NOT_ENOUGH_CASH
	if item.slots * quantity > Inventory.free_space(run):
		return Result.NO_SPACE
	return Result.OK


static func buy(run: RunState, item: ItemDef, quantity: int, unit_price: int) -> Result:
	var result := check_buy(run, item, quantity, unit_price)
	if result != Result.OK:
		return result
	var held := Inventory.count(run, item.id) + Inventory.stashed(run, item.id)
	var paid_before := int(run.cost_basis.get(item.id, 0)) * held
	run.cash -= unit_price * quantity
	Inventory.add_units(run, item.id, quantity)
	run.cost_basis[item.id] = roundi(float(paid_before + unit_price * quantity) / (held + quantity))
	run.trades += 1
	return Result.OK


static func check_sell(run: RunState, item: ItemDef, quantity: int) -> Result:
	if quantity <= 0:
		return Result.INVALID_QUANTITY
	if quantity > Inventory.count(run, item.id):
		return Result.NOT_ENOUGH_UNITS
	return Result.OK


static func sell(run: RunState, item: ItemDef, quantity: int, unit_price: int) -> Result:
	var result := check_sell(run, item, quantity)
	if result != Result.OK:
		return result
	var paid := int(run.cost_basis.get(item.id, unit_price))
	run.cash += unit_price * quantity
	run.profit += (unit_price - paid) * quantity
	run.trades += 1
	Inventory.discard(run, item.id, quantity)
	return Result.OK


static func check_gear(run: RunState, item: ItemDef) -> Result:
	if Gear.owns(run, item.id):
		return Result.ALREADY_OWNED
	if item.base_price > run.cash:
		return Result.NOT_ENOUGH_CASH
	return Result.OK


static func buy_gear(run: RunState, item: ItemDef) -> Result:
	var result := check_gear(run, item)
	if result != Result.OK:
		return result
	run.cash -= item.base_price
	run.gear.append(item.id)
	return Result.OK
