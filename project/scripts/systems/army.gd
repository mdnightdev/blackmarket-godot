class_name Army

## The player's fighters, in three tiers: Lunatics from Auntie Tran, the Guards and the Black Hand trained by 午夜兔子.
## The outfit has a number of slots, bought as training expansions in the Gym, and the player splits them between the
## tiers. Men are only paid for at training sessions, which fill every tier back up to its slots and heal the wounded.
## run.army maps a Tier to a count per State. The dead live only in run.fallen.

enum Tier { LUNATICS, GUARDS, BLACK_HAND }
enum State { ACTIVE, WOUNDED }

const TIER_NAMES := {
	Tier.LUNATICS: "Lunatics",
	Tier.GUARDS: "The Guards",
	Tier.BLACK_HAND: "Black Hand",
}
## Lunatics and Guards multiply the power of the weapon they carry. The Black Hand bring their own.
const SKILL := {
	Tier.LUNATICS: 1.0,
	Tier.GUARDS: 2.5,
}
const BLACK_HAND_POWER := 25.0
## How likely a man of the tier is to be hit, and how likely a hit is to kill him.
const EXPOSURE := {
	Tier.LUNATICS: 1.0,
	Tier.GUARDS: 0.6,
	Tier.BLACK_HAND: 0.25,
}
const LETHALITY := {
	Tier.LUNATICS: 1.0,
	Tier.GUARDS: 0.75,
	Tier.BLACK_HAND: 0.5,
}
## Paid at a training session for every hundred empty slots filled.
const REPLACE_PRICES := {
	Tier.LUNATICS: 250,
	Tier.GUARDS: 1500,
	Tier.BLACK_HAND: 15000,
}
const DEPLOY_ORDER: Array[Tier] = [Tier.BLACK_HAND, Tier.GUARDS, Tier.LUNATICS]
## Weapons go to the Guards first, then the Lunatics.
const ARMED_ORDER: Array[Tier] = [Tier.GUARDS, Tier.LUNATICS]
## Training expansions. Each sets how many men the outfit keeps and how many go into one fight.
const EXPANSIONS: Array[Dictionary] = [
	{ "name": "Small operation", "capacity": 1000, "deploy": 300, "price": 0 },
	{ "name": "Established gang", "capacity": 3000, "deploy": 1000, "price": 25000 },
	{ "name": "Crime syndicate", "capacity": 10000, "deploy": 3000, "price": 100000 },
	{ "name": "Major organization", "capacity": 25000, "deploy": 7500, "price": 300000 },
	{ "name": "Powerful family", "capacity": 50000, "deploy": 15000, "price": 750000 },
	{ "name": "Kingpin", "capacity": 100000, "deploy": 30000, "price": 2000000 },
]
const STARTING_SPLIT := { Tier.LUNATICS: 800, Tier.GUARDS: 200, Tier.BLACK_HAND: 0 }
## Saves written before this scale kept a tenth of the men. They are multiplied up on load.
const WAR_SCALE := 10

enum Result { OK, MAX_LEVEL, NOT_ENOUGH_CASH }


static func count(run: RunState, tier: Tier, state: State = State.ACTIVE) -> int:
	return int(run.army.get(tier, {}).get(state, 0))


static func add(run: RunState, tier: Tier, state: State, amount: int) -> void:
	var states: Dictionary = run.army.get(tier, {})
	states[state] = maxi(0, int(states.get(state, 0)) + amount)
	run.army[tier] = states


static func move(run: RunState, tier: Tier, from: State, to: State, amount: int) -> void:
	var moved := mini(amount, count(run, tier, from))
	add(run, tier, from, -moved)
	add(run, tier, to, moved)


static func active(run: RunState) -> int:
	var sum := 0
	for tier in Tier.values():
		sum += count(run, tier)
	return sum


static func wounded(run: RunState) -> int:
	var sum := 0
	for tier in Tier.values():
		sum += count(run, tier, State.WOUNDED)
	return sum


## Every living man of the tier, fit or wounded. All tiers when tier is -1.
static func total(run: RunState, tier: int = -1) -> int:
	var sum := 0
	for each_tier in Tier.values():
		if tier < 0 or each_tier == tier:
			sum += count(run, each_tier) + count(run, each_tier, State.WOUNDED)
	return sum


static func fallen(run: RunState, tier: int = -1) -> int:
	if tier >= 0:
		return int(run.fallen.get(tier, 0))
	var sum := 0
	for each_tier: int in run.fallen:
		sum += int(run.fallen[each_tier])
	return sum


static func expansion(run: RunState) -> Dictionary:
	return EXPANSIONS[run.army_level]


static func capacity(run: RunState) -> int:
	return int(expansion(run).capacity)


static func deploy_cap(run: RunState) -> int:
	return int(expansion(run).deploy)


## The price of the next training expansion, -1 at the top.
static func expansion_price(run: RunState) -> int:
	return int(EXPANSIONS[run.army_level + 1].price) if run.army_level + 1 < EXPANSIONS.size() else -1


## The new slots go to the Lunatics until the player splits them differently.
static func expand(run: RunState) -> Result:
	var price := expansion_price(run)
	if price < 0:
		return Result.MAX_LEVEL
	if run.cash < price:
		return Result.NOT_ENOUGH_CASH
	run.cash -= price
	var added := int(EXPANSIONS[run.army_level + 1].capacity) - capacity(run)
	run.army_level += 1
	run.army_split[Tier.LUNATICS] = slots(run, Tier.LUNATICS) + added
	return Result.OK


## Prices for men are per hundred. A part of a hundred costs its share, rounded up.
static func price_of(per_hundred: int, men: int) -> int:
	return ceili(men * per_hundred / 100.0)


static func men_for(per_hundred: int, cash: int) -> int:
	return floori(cash * 100.0 / per_hundred)


## The Black Hand are kept for special missions. Until Vex falls the only ones are Rabbit's unit, and the player
## cannot give them more slots.
static func black_hand_open(run: RunState) -> bool:
	return Campaign.is_act_two(run)


static func slots(run: RunState, tier: Tier) -> int:
	return int(run.army_split.get(tier, STARTING_SPLIT[tier]))


static func slots_used(run: RunState) -> int:
	var sum := 0
	for tier in Tier.values():
		sum += slots(run, tier)
	return sum


## Gives the tier this many slots, as far as the outfit's capacity allows. Returns the slots it ended up with.
static func set_slots(run: RunState, tier: Tier, amount: int) -> int:
	if tier == Tier.BLACK_HAND and not black_hand_open(run):
		return slots(run, tier)
	var others := slots_used(run) - slots(run, tier)
	var granted := clampi(amount, 0, capacity(run) - others)
	run.army_split[tier] = granted
	return granted


## Makes sure the tier has room for at least this many men, taking the slots from the Lunatics, then the Guards.
static func make_room(run: RunState, tier: Tier, amount: int) -> void:
	var missing := amount - slots(run, tier)
	if missing <= 0:
		return
	var free := capacity(run) - slots_used(run)
	for donor in [Tier.LUNATICS, Tier.GUARDS]:
		if free >= missing or donor == tier:
			continue
		var taken := mini(missing - free, slots(run, donor))
		run.army_split[donor] = slots(run, donor) - taken
		free += taken
	run.army_split[tier] = slots(run, tier) + mini(missing, free)


## Empty slots of the tier waiting for the next session.
static func vacancies(run: RunState, tier: Tier) -> int:
	return maxi(0, slots(run, tier) - total(run, tier))


## The men sent into a fight, best tier first. size -1 sends as many as the expansion allows. The Black Hand stay
## back unless asked for.
static func deployment(run: RunState, size: int = -1, with_black_hand := true) -> Dictionary:
	var ready := active(run) - (0 if with_black_hand else count(run, Tier.BLACK_HAND))
	var left := mini(deploy_cap(run), ready) if size < 0 else mini(size, mini(deploy_cap(run), ready))
	var sent := {}
	for tier in DEPLOY_ORDER:
		if tier == Tier.BLACK_HAND and not with_black_hand:
			continue
		var taken := mini(left, count(run, tier))
		if taken > 0:
			sent[tier] = taken
			left -= taken
	return sent


## The men the player picked tier by tier. Each tier is held to its fit men and the whole to the expansion's limit,
## the best tiers keeping their men first.
static func picked(run: RunState, wanted: Dictionary) -> Dictionary:
	var left := deploy_cap(run)
	var sent := {}
	for tier in DEPLOY_ORDER:
		var taken := mini(left, mini(int(wanted.get(tier, 0)), count(run, tier)))
		if taken > 0:
			sent[tier] = taken
			left -= taken
	return sent


static func deployed_count(deployment: Dictionary) -> int:
	var sum := 0
	for tier: int in deployment:
		sum += int(deployment[tier])
	return sum


## Weapons carried by each armed tier of the deployment, best weapons first. Men left over fight with their hands.
## Returns Tier to a Grade to count, with Grade.NONE for the unarmed.
static func issue(run: RunState, deployment: Dictionary) -> Dictionary:
	var stock := {}
	for grade in Armory.BEST_FIRST:
		stock[grade] = Armory.count(run, grade)
	var carried := {}
	for tier in ARMED_ORDER:
		var left := int(deployment.get(tier, 0))
		if left <= 0:
			continue
		var hands := {}
		for grade in Armory.BEST_FIRST:
			var taken := mini(left, int(stock[grade]))
			if taken > 0:
				hands[grade] = taken
				stock[grade] = int(stock[grade]) - taken
				left -= taken
		hands[Armory.Grade.NONE] = left
		carried[tier] = hands
	return carried


static func power(run: RunState, deployment: Dictionary) -> float:
	var sum := int(deployment.get(Tier.BLACK_HAND, 0)) * BLACK_HAND_POWER
	var carried := issue(run, deployment)
	for tier: int in carried:
		for grade: int in carried[tier]:
			sum += int(carried[tier][grade]) * Armory.power_of(grade) * float(SKILL[tier])
	return sum


## The power of the biggest force the player can send right now.
static func strength(run: RunState) -> float:
	return power(run, deployment(run))


## Splits the hits a deployment takes into dead and wounded per tier. hit_share is the share of the force hit and
## death_share the share of the hit who die, both before each tier's own exposure and lethality.
## Returns Tier to { dead, wounded }.
static func casualties(deployment: Dictionary, hit_share: float, death_share: float) -> Dictionary:
	var losses := {}
	for tier: int in deployment:
		var hit := mini(int(deployment[tier]), roundi(int(deployment[tier]) * hit_share * float(EXPOSURE[tier])))
		var dead := mini(hit, roundi(hit * clampf(death_share * float(LETHALITY[tier]), 0.0, 1.0)))
		losses[tier] = { "dead": dead, "wounded": hit - dead }
	return losses


static func sum_losses(losses: Dictionary, key: String) -> int:
	var sum := 0
	for tier: int in losses:
		sum += int(losses[tier][key])
	return sum


## The wounded wait for a training session. The dead are gone with the weapons they carried.
static func take_losses(run: RunState, deployment: Dictionary, losses: Dictionary) -> void:
	var carried := issue(run, deployment)
	for tier: int in losses:
		var dead := int(losses[tier].dead)
		move(run, tier, State.ACTIVE, State.WOUNDED, int(losses[tier].wounded))
		add(run, tier, State.ACTIVE, -dead)
		run.fallen[tier] = fallen(run, tier) + dead
		if dead > 0 and carried.has(tier):
			var share := float(dead) / int(deployment[tier])
			for grade: int in carried[tier]:
				if grade != Armory.Grade.NONE:
					Armory.lose(run, grade, roundi(int(carried[tier][grade]) * share))


static func describe(deployment: Dictionary) -> String:
	var parts: PackedStringArray = []
	for tier in DEPLOY_ORDER:
		if int(deployment.get(tier, 0)) > 0:
			parts.append("%d %s" % [int(deployment[tier]), TIER_NAMES[tier]])
	return ", ".join(parts)


## Saves written before the tiers kept one count of men, all of them Lunatics, plus Rabbit's unit as a story flag.
## Those saves are also older than WAR_SCALE, so the unit is counted at the old scale and multiplied up on load.
static func from_legacy(men: int, unit_hired: bool) -> Dictionary:
	var army := {}
	if men > 0:
		army[Tier.LUNATICS] = { State.ACTIVE: men }
	if unit_hired:
		army[Tier.BLACK_HAND] = { State.ACTIVE: War.RABBIT_UNIT_SIZE / WAR_SCALE }
	return army


## Multiplies every count kept by a save written at a smaller scale.
static func rescale(run: RunState, factor: int) -> void:
	for tier: int in run.army:
		for state: int in run.army[tier]:
			run.army[tier][state] = int(run.army[tier][state]) * factor
	for counts: Dictionary in [run.fallen, run.army_split, run.armory]:
		for key: Variant in counts:
			counts[key] = int(counts[key]) * factor
	for corner_id: String in run.corner_defenders:
		run.corner_defenders[corner_id] = int(run.corner_defenders[corner_id]) * factor


static func sanitize(source: Variant) -> Dictionary:
	var clean := {}
	if not source is Dictionary:
		return clean
	for tier_key: Variant in source:
		var tier := int(str(tier_key))
		var states: Variant = source[tier_key]
		if tier < 0 or tier >= Tier.size() or not states is Dictionary:
			continue
		var clean_states := {}
		for state_key: Variant in states:
			var state := int(str(state_key))
			var amount := int(states[state_key])
			if state >= 0 and state < State.size() and amount > 0:
				clean_states[state] = amount
		if not clean_states.is_empty():
			clean[tier] = clean_states
	return clean


## Tier to a count, for run.fallen and run.army_split.
static func sanitize_counts(source: Variant) -> Dictionary:
	var clean := {}
	if source is Dictionary:
		for key: Variant in source:
			var tier := int(str(key))
			var amount := int(source[key])
			if tier >= 0 and tier < Tier.size() and amount >= 0:
				clean[tier] = amount
	return clean
