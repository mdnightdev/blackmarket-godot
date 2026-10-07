class_name Safehouse

## The player's hideout in the Slums: a stash that raids never touch, and a place to lie low.

const VENUE: StringName = &"safehouse"
const UPGRADE_ICON := preload("res://assets/items/safehouse_lockbox.jpg")
const LIE_LOW_ICON := preload("res://assets/items/lie_low.jpg")
const UPGRADES: Array[Dictionary] = [
	{ "name": "Lockbox", "capacity": 80, "price": 2000 },
	{ "name": "Strongroom", "capacity": 160, "price": 6000 },
	{ "name": "Vault", "capacity": 300, "price": 15000 },
]
## Heat lost on top of the normal cooling when the player spends a phase here.
const LIE_LOW_HEAT := 15


static func is_here(run: RunState) -> bool:
	var district := Content.district(run.district_id)
	return district != null and district.venues.has(VENUE)


static func stash_capacity(run: RunState) -> int:
	return 0 if run.stash_level <= 0 else int(UPGRADES[run.stash_level - 1].capacity)


static func stash_name(run: RunState) -> String:
	return "" if run.stash_level <= 0 else str(UPGRADES[run.stash_level - 1].name)


## The next upgrade on offer, empty once the vault is built.
static func next_upgrade(run: RunState) -> Dictionary:
	return {} if run.stash_level >= UPGRADES.size() else UPGRADES[run.stash_level]


static func can_upgrade(run: RunState) -> bool:
	var upgrade := next_upgrade(run)
	return is_here(run) and not upgrade.is_empty() and run.cash >= int(upgrade.price)


static func buy_upgrade(run: RunState) -> bool:
	if not can_upgrade(run):
		return false
	run.cash -= int(next_upgrade(run).price)
	run.stash_level += 1
	return true


static func lie_low(run: RunState) -> bool:
	if not is_here(run):
		return false
	Heat.add(run, -LIE_LOW_HEAT)
	return true
