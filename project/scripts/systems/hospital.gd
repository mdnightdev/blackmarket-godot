class_name Hospital

## Holds the wounded until the player pays to heal them, Black Hand first. A short purse heals as many as it covers.
## When every bed is taken, men hit in a fight die instead of being wounded. Nothing brings back the dead.

enum Result { OK, MAX_LEVEL, NOT_ENOUGH_CASH }

const LEVELS: Array[Dictionary] = [
	{ "beds": 25000, "price": 0 },
	{ "beds": 50000, "price": 150000 },
	{ "beds": 100000, "price": 500000 },
	{ "beds": 200000, "price": 1200000 },
	{ "beds": 300000, "price": 2500000 },
]
## Per thousand men healed.
const HEAL_PRICES := {
	Army.Tier.LUNATICS: 500,
	Army.Tier.GUARDS: 2000,
	Army.Tier.BLACK_HAND: 15000,
}


static func beds(run: RunState) -> int:
	return int(LEVELS[run.hospital_level].beds)


static func free_beds(run: RunState) -> int:
	return maxi(0, beds(run) - Army.wounded(run))


## The price of the next level, -1 at the top.
static func upgrade_price(run: RunState) -> int:
	return int(LEVELS[run.hospital_level + 1].price) if run.hospital_level + 1 < LEVELS.size() else -1


static func upgrade(run: RunState) -> Result:
	var price := upgrade_price(run)
	if price < 0:
		return Result.MAX_LEVEL
	if run.cash < price:
		return Result.NOT_ENOUGH_CASH
	run.cash -= price
	run.hospital_level += 1
	return Result.OK


## Gives the wounded of a fight the free beds, best tier first. The ones left without a bed are counted as dead.
## losses is the result of Army.casualties and is changed in place.
static func admit(run: RunState, losses: Dictionary) -> void:
	var free := free_beds(run)
	for tier in Army.DEPLOY_ORDER:
		if not losses.has(tier):
			continue
		var wounded := int(losses[tier].wounded)
		var admitted := mini(wounded, free)
		free -= admitted
		losses[tier] = { "dead": int(losses[tier].dead) + wounded - admitted, "wounded": admitted }


## Returns { healed, paid }.
static func heal(run: RunState) -> Dictionary:
	var healed := 0
	var paid := 0
	for tier in Army.DEPLOY_ORDER:
		var price := int(HEAL_PRICES[tier])
		var taken := mini(Army.count(run, tier, Army.State.WOUNDED), Army.men_for(price, run.cash))
		var cost := Army.price_of(price, taken)
		Army.move(run, tier, Army.State.WOUNDED, Army.State.ACTIVE, taken)
		run.cash -= cost
		healed += taken
		paid += cost
	return { "healed": healed, "paid": paid }


## What healing every wounded man would cost.
static func estimate(run: RunState) -> int:
	var sum := 0
	for tier in Army.DEPLOY_ORDER:
		sum += Army.price_of(int(HEAL_PRICES[tier]), Army.count(run, tier, Army.State.WOUNDED))
	return sum
