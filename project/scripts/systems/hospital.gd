class_name Hospital

## Heals the wounded at each training session, as many as there are beds, Black Hand first. Each man healed is paid
## for, so a short purse leaves men waiting for the next session. Nothing brings back the dead.

enum Result { OK, MAX_LEVEL, NOT_ENOUGH_CASH }

const LEVELS: Array[Dictionary] = [
	{ "beds": 200, "price": 0 },
	{ "beds": 600, "price": 15000 },
	{ "beds": 1500, "price": 60000 },
	{ "beds": 4000, "price": 200000 },
	{ "beds": 10000, "price": 500000 },
	{ "beds": 25000, "price": 1500000 },
]
## Per hundred men healed.
const HEAL_PRICES := {
	Army.Tier.LUNATICS: 100,
	Army.Tier.GUARDS: 500,
	Army.Tier.BLACK_HAND: 4000,
}


static func beds(run: RunState) -> int:
	return int(LEVELS[run.hospital_level].beds)


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


## Returns { healed, paid }.
static func heal(run: RunState) -> Dictionary:
	var healed := 0
	var paid := 0
	for tier in Army.DEPLOY_ORDER:
		var price := int(HEAL_PRICES[tier])
		var taken := mini(mini(beds(run) - healed, Army.count(run, tier, Army.State.WOUNDED)), Army.men_for(price, run.cash))
		var cost := Army.price_of(price, taken)
		Army.move(run, tier, Army.State.WOUNDED, Army.State.ACTIVE, taken)
		run.cash -= cost
		healed += taken
		paid += cost
	return { "healed": healed, "paid": paid }


## What healing everyone waiting would cost at the next session, beds allowing.
static func estimate(run: RunState) -> int:
	var sum := 0
	var left := beds(run)
	for tier in Army.DEPLOY_ORDER:
		var taken := mini(left, Army.count(run, tier, Army.State.WOUNDED))
		sum += Army.price_of(int(HEAL_PRICES[tier]), taken)
		left -= taken
	return sum
