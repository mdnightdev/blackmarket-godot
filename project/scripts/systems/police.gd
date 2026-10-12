class_name Police

## Officer Brandt, Moreau's junior, makes the stops and leads the raids. See Ramos for the one exception.
const BRANDT: StringName = &"brandt"
## How much more often Brandt walks into the player's district once they are watched.
const FOLLOW_WEIGHT := 4.0

const BASE_STOP_CHANCE := 0.02
const HEAT_STOP_CHANCE := 0.25
const CARGO_RISK_SCALE := 2000.0
const MAX_CARGO_STOP_CHANCE := 0.08
const MAX_STOP_CHANCE := 0.25

const MIN_BRIBE := 100
## Share of the carried value an officer asks for: the floor, the usual ask and the rare steep one.
const BRIBE_LOW := 0.06
const BRIBE_USUAL := 0.1
const BRIBE_HIGH := 0.16
## Officers who had to chase the player down ask for more.
const CORNERED_BRIBE_FACTOR := 1.5

## Strength lead in a chase on foot with no heat. Heat makes the police try harder.
const ESCAPE_EDGE := 0.05
const HEAT_ESCAPE_PENALTY := 0.0015
const VEHICLE_ESCAPE_BONUS := 0.1

const ESCAPED_HEAT := 10
const COMPLY_HEAT_DROP := 15

const GRACE_DAYS := 3
const QUIET_PHASES_AFTER_ARREST := 4
const HEAT_AFTER_ARREST := 20
const ARREST_SEIZED_SHARE := 0.5
## In Act 1 a bust takes less, but the Shark hears about it and the questioning eats into the phase.
const ACT_ONE_SEIZED_SHARE := 0.3
const QUESTIONING_SECONDS := 120.0
## Real time in a cell. It keeps counting while the game is closed.
const JAIL_SECONDS := 300.0
## Bail is a share of what the player was carrying when booked, never less than the minimum.
const BAIL_SHARE := 0.5
const MIN_BAIL := 1000


## No stops or raids in the first days of a run, or for a full day after an arrest.
static func is_quiet(run: RunState) -> bool:
	if run.day <= GRACE_DAYS:
		return true
	return run.arrest_stamp >= 0 and Calendar.stamp(run) - run.arrest_stamp <= QUIET_PHASES_AFTER_ARREST


## Police only bother players who are carrying goods. A patrol in the district raises the odds,
## the player's own turf lowers them, and nobody is stopped twice in a row.
static func stop_chance(run: RunState) -> float:
	var cargo_risk := Heat.carried_risk(run)
	if cargo_risk <= 0 or just_stopped(run):
		return 0.0
	var district := Content.district(run.district_id)
	var strictness := district.heat_multiplier if district != null else 1.0
	var patrol := Roster.patrol_multiplier(run, run.district_id, Calendar.stamp(run))
	var chance := BASE_STOP_CHANCE + float(run.heat) / Heat.MAX * HEAT_STOP_CHANCE
	chance += minf(cargo_risk / CARGO_RISK_SCALE, MAX_CARGO_STOP_CHANCE)
	return minf(chance * strictness * patrol * Turf.stop_factor(run, run.district_id) * Crew.stop_factor(run), MAX_STOP_CHANCE)


## True during the phase of a stop and the phase after it.
static func just_stopped(run: RunState) -> bool:
	return run.stop_stamp >= 0 and Calendar.stamp(run) - run.stop_stamp <= 1


static func carried_value(run: RunState) -> int:
	var total := Smuggling.carried_value(run)
	for item_id: StringName in run.inventory:
		var item := Content.item(item_id)
		if item != null:
			total += item.base_price * int(run.inventory[item_id])
	return total


## Rolled once per phase, so asking again in the same phase gets the same answer.
static func bribe_cost(run: RunState) -> int:
	var share := Odds.bell(Odds.rng_for(run, &"bribe"), BRIBE_LOW, BRIBE_USUAL, BRIBE_HIGH)
	return maxi(MIN_BRIBE, roundi(carried_value(run) * share))


static func escape_chance(run: RunState) -> float:
	return Odds.contest(ESCAPE_EDGE + speed_bonus(run) - run.heat * HEAT_ESCAPE_PENALTY)


## What the player brings to any chase: a vehicle, the Wheelman skill and a Driver.
static func speed_bonus(run: RunState) -> float:
	var bonus := Skills.escape_bonus(run) + Crew.escape_bonus(run)
	if Gear.fare_discount(run) > 0.0:
		bonus += VEHICLE_ESCAPE_BONUS
	return bonus


static func riskiest_item(run: RunState) -> ItemDef:
	var riskiest: ItemDef = null
	for item_id: StringName in run.inventory:
		var item := Content.item(item_id)
		if item != null and (riskiest == null or item.risk > riskiest.risk):
			riskiest = item
	return riskiest


static func pay_bribe(run: RunState, cost: int) -> bool:
	if run.cash < cost:
		return false
	run.cash -= cost
	return true


## Returns true when the player got away. A caught player faces the stop again without the option to run.
static func run_for_it(run: RunState, roll: float) -> bool:
	if roll < escape_chance(run):
		Heat.add(run, ESCAPED_HEAT)
		return true
	return false


## Hands over a smuggling crate if one is carried, otherwise the seized share of the riskiest stack, rounded up.
## Returns { crate = true }, the confiscated item and quantity, or an empty dictionary.
static func comply(run: RunState) -> Dictionary:
	Heat.add(run, -COMPLY_HEAT_DROP)
	if Smuggling.seize(run):
		_act_one_bust_cost(run)
		return { "crate": true }
	var item := riskiest_item(run)
	if item == null:
		return {}
	var quantity := ceili(Inventory.count(run, item.id) * seized_share(run))
	Inventory.discard(run, item.id, quantity)
	_act_one_bust_cost(run)
	return { "item": item, "quantity": quantity }


static func seized_share(run: RunState) -> float:
	return ARREST_SEIZED_SHARE if Campaign.is_act_two(run) else ACT_ONE_SEIZED_SHARE


static func _act_one_bust_cost(run: RunState) -> void:
	if Campaign.is_act_two(run):
		return
	SharkTrust.add(run, SharkTrust.BUSTED)
	run.phase_seconds_left = maxf(0.0, run.phase_seconds_left - QUESTIONING_SECONDS)


## now is Unix time in seconds. Leave it negative to use the system clock. A clock turned back never adds time.
static func jail_seconds_left(run: RunState, now := -1.0) -> float:
	if run.jail_until <= 0.0:
		return 0.0
	return clampf(run.jail_until - _now(now), 0.0, JAIL_SECONDS)


static func is_jailed(run: RunState, now := -1.0) -> bool:
	return jail_seconds_left(run, now) > 0.0


## The player sits out JAIL_SECONDS of real time while the game clock runs on. carried is the street value of what
## they were caught with, which sets the bail.
static func go_to_jail(run: RunState, carried: int, now := -1.0) -> void:
	run.jail_until = _now(now) + JAIL_SECONDS
	run.jail_bail = maxi(MIN_BAIL, roundi(carried * BAIL_SHARE))


static func post_bail(run: RunState, now := -1.0) -> bool:
	if not is_jailed(run, now) or run.cash < run.jail_bail:
		return false
	run.cash -= run.jail_bail
	release(run)
	return true


## Returns true once, on the check that finds the time served.
static func release_if_served(run: RunState, now := -1.0) -> bool:
	if run.jail_until <= 0.0 or is_jailed(run, now):
		return false
	release(run)
	return true


static func release(run: RunState) -> void:
	run.jail_until = 0.0
	run.jail_bail = 0


static func _now(now: float) -> float:
	return now if now >= 0.0 else Time.get_unix_time_from_system()


## Takes any crate and the seized share of every stack in the bag, rounded up. Cash is left alone, and so is the
## stash unless the raid knows where it is.
static func arrest(run: RunState, with_stash := false) -> void:
	Smuggling.seize(run)
	for item_id: StringName in run.inventory.keys():
		Inventory.discard(run, item_id, ceili(Inventory.count(run, item_id) * seized_share(run)))
	if with_stash:
		for item_id: StringName in run.stash.keys():
			var left := int(run.stash[item_id]) - ceili(int(run.stash[item_id]) * seized_share(run))
			if left > 0:
				run.stash[item_id] = left
			else:
				run.stash.erase(item_id)
	_act_one_bust_cost(run)
	raided(run)
	run.busts += 1
	StreetCred.add(run, StreetCred.BUSTED)


## Every raid, empty or not, cools the player down and keeps the police away for a while.
static func raided(run: RunState) -> void:
	run.heat = HEAT_AFTER_ARREST
	run.arrest_stamp = Calendar.stamp(run)
