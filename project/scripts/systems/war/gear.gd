class_name Gear

const MAX_FARE_DISCOUNT := 0.8
const MAX_HAGGLE_BONUS := 0.15


static func owns(run: RunState, item_id: StringName) -> bool:
	return run.gear.has(item_id)


static func owned_items(run: RunState) -> Array[ItemDef]:
	var list: Array[ItemDef] = []
	for item_id in run.gear:
		var item := Content.item(item_id)
		if item != null:
			list.append(item)
	return list


static func capacity_bonus(run: RunState) -> int:
	var total := 0
	for item in owned_items(run):
		total += item.capacity_bonus
	return total


## Slots the smallest bag upgrade the player does not own yet would add, 0 once every one is owned.
static func next_capacity_bonus(run: RunState) -> int:
	var smallest := 0
	for item in Content.items(ItemDef.Kind.EQUIPMENT):
		if item.capacity_bonus > 0 and not owns(run, item.id) and (smallest == 0 or item.capacity_bonus < smallest):
			smallest = item.capacity_bonus
	return smallest


static func fare_discount(run: RunState) -> float:
	var best := 0.0
	for item in owned_items(run):
		best = maxf(best, item.fare_discount)
	return minf(best, MAX_FARE_DISCOUNT)


static func haggle_bonus(run: RunState) -> float:
	var total := 0.0
	for item in owned_items(run):
		total += item.haggle_bonus
	return minf(total, MAX_HAGGLE_BONUS)


static func describe(item: ItemDef) -> String:
	var effects: Array[String] = []
	if item.capacity_bonus > 0:
		effects.append("+%d bag slots" % item.capacity_bonus)
	if item.fare_discount > 0.0:
		effects.append("Fares -%d%%" % roundi(item.fare_discount * 100.0))
	if item.haggle_bonus > 0.0:
		effects.append("Haggle +%d%%" % roundi(item.haggle_bonus * 100.0))
	return ", ".join(effects)
