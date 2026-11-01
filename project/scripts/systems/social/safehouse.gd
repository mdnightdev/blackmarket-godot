class_name Safehouse

## The player's hideout, reachable from any district they hold: a stash raids never touch,
## a cash box nobody can take, and a place to lie low.

static var UPGRADE_ICON: Texture2D:
	get:
		return ItemsAtlas.get_icon(&"safehouse_lockbox")
static var LIE_LOW_ICON: Texture2D:
	get:
		return ItemsAtlas.get_icon(&"lie_low")
const UPGRADES: Array[Dictionary] = [
	{ "name": "Lockbox", "capacity": 80, "price": 2000 },
	{ "name": "Strongroom", "capacity": 160, "price": 6000 },
	{ "name": "Vault", "capacity": 300, "price": 15000 },
]
## Heat lost on top of the normal cooling when the player spends a phase here.
const LIE_LOW_HEAT := 15


static func is_open(run: RunState) -> bool:
	return Turf.holder(run, run.district_id) == Turf.Holder.PLAYER


static func stash_capacity(run: RunState) -> int:
	return 0 if run.stash_level <= 0 else int(UPGRADES[run.stash_level - 1].capacity)


static func stash_name(run: RunState) -> String:
	return "" if run.stash_level <= 0 else str(UPGRADES[run.stash_level - 1].name)


## The next upgrade on offer, empty once the vault is built.
static func next_upgrade(run: RunState) -> Dictionary:
	return {} if run.stash_level >= UPGRADES.size() else UPGRADES[run.stash_level]


static func can_upgrade(run: RunState) -> bool:
	var upgrade := next_upgrade(run)
	return is_open(run) and not upgrade.is_empty() and run.cash >= int(upgrade.price)


static func buy_upgrade(run: RunState) -> bool:
	if not can_upgrade(run):
		return false
	run.cash -= int(next_upgrade(run).price)
	run.stash_level += 1
	return true


static func deposit_cash(run: RunState, amount: int) -> bool:
	if not is_open(run) or amount <= 0 or amount > run.cash:
		return false
	run.cash -= amount
	run.stashed_cash += amount
	return true


static func withdraw_cash(run: RunState, amount: int) -> bool:
	if not is_open(run) or amount <= 0 or amount > run.stashed_cash:
		return false
	run.stashed_cash -= amount
	run.cash += amount
	return true


static func lie_low(run: RunState) -> bool:
	if not is_open(run):
		return false
	Heat.add(run, -LIE_LOW_HEAT)
	return true
