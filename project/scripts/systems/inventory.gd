class_name Inventory

const BASE_CAPACITY := 20


static func count(run: RunState, item_id: StringName) -> int:
	return int(run.inventory.get(item_id, 0))


static func stashed(run: RunState, item_id: StringName) -> int:
	return int(run.stash.get(item_id, 0))


static func capacity(run: RunState) -> int:
	return BASE_CAPACITY + Gear.capacity_bonus(run) + Skills.capacity_bonus(run) + Crew.capacity_bonus(run)


static func used(run: RunState) -> int:
	return _slots_used(run.inventory) + Smuggling.slots_used(run)


static func free_space(run: RunState) -> int:
	return maxi(0, capacity(run) - used(run))


## Slots carried beyond capacity, for when capacity shrinks or a save loads a heavier bag.
static func over_capacity(run: RunState) -> int:
	return maxi(0, used(run) - capacity(run))


static func stash_used(run: RunState) -> int:
	return _slots_used(run.stash)


static func stash_free_space(run: RunState) -> int:
	return maxi(0, Safehouse.stash_capacity(run) - stash_used(run))


## The stash lives in the safehouse, so it can only be reached from a district the player holds.
static func can_use_stash(run: RunState) -> bool:
	return Safehouse.stash_capacity(run) > 0 and Safehouse.is_open(run)


static func max_to_stash(run: RunState, item: ItemDef) -> int:
	return mini(count(run, item.id), floori(float(stash_free_space(run)) / item.slots))


static func max_from_stash(run: RunState, item: ItemDef) -> int:
	return mini(stashed(run, item.id), floori(float(free_space(run)) / item.slots))


static func move_to_stash(run: RunState, item: ItemDef, quantity: int) -> bool:
	if not can_use_stash(run) or quantity <= 0 or quantity > max_to_stash(run, item):
		return false
	_add(run.inventory, item.id, -quantity)
	_add(run.stash, item.id, quantity)
	return true


static func take_from_stash(run: RunState, item: ItemDef, quantity: int) -> bool:
	if not can_use_stash(run) or quantity <= 0 or quantity > max_from_stash(run, item):
		return false
	_add(run.stash, item.id, -quantity)
	_add(run.inventory, item.id, quantity)
	return true


static func add_units(run: RunState, item_id: StringName, quantity: int) -> void:
	_add(run.inventory, item_id, quantity)


## Removes carried units and forgets the price paid once none are held anywhere.
static func discard(run: RunState, item_id: StringName, quantity: int) -> void:
	_add(run.inventory, item_id, -quantity)
	if count(run, item_id) == 0 and stashed(run, item_id) == 0 and Businesses.total_stocked(run, item_id) == 0:
		run.cost_basis.erase(item_id)


static func _add(counts: Dictionary, item_id: StringName, quantity: int) -> void:
	var total := int(counts.get(item_id, 0)) + quantity
	if total > 0:
		counts[item_id] = total
	else:
		counts.erase(item_id)


static func _slots_used(counts: Dictionary) -> int:
	var total := 0
	for item_id: StringName in counts:
		var item := Content.item(item_id)
		total += counts[item_id] * (item.slots if item != null else 1)
	return total
