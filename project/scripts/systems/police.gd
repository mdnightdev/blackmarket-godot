class_name Police

const BASE_STOP_CHANCE := 0.02
const HEAT_STOP_CHANCE := 0.25
const CARGO_RISK_SCALE := 2000.0
const MAX_CARGO_STOP_CHANCE := 0.08
const MAX_STOP_CHANCE := 0.35

const MIN_BRIBE := 100
const BRIBE_FRACTION := 0.15

const BASE_ESCAPE_CHANCE := 0.6
const ESCAPE_HEAT_SCALE := 250.0
const MIN_ESCAPE_CHANCE := 0.3
const MAX_ESCAPE_CHANCE := 0.75
const VEHICLE_ESCAPE_BONUS := 0.1

const ESCAPED_HEAT := 10
const CAUGHT_HEAT := 15
const COMPLY_HEAT_DROP := 15
const RAID_HEAT_AFTER := 50


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


static func bribe_cost(run: RunState) -> int:
	return maxi(MIN_BRIBE, roundi(carried_value(run) * BRIBE_FRACTION))


static func escape_chance(run: RunState) -> float:
	var chance := clampf(BASE_ESCAPE_CHANCE - run.heat / ESCAPE_HEAT_SCALE, MIN_ESCAPE_CHANCE, MAX_ESCAPE_CHANCE)
	if Gear.fare_discount(run) > 0.0:
		chance += VEHICLE_ESCAPE_BONUS
	return chance + Skills.escape_bonus(run) + Crew.escape_bonus(run)


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


## Returns true when the player got away.
static func run_for_it(run: RunState, roll: float) -> bool:
	if roll < escape_chance(run):
		Heat.add(run, ESCAPED_HEAT)
		return true
	seize_bag(run)
	Heat.add(run, CAUGHT_HEAT)
	run.busts += 1
	StreetCred.add(run, StreetCred.BUSTED)
	return false


## Hands over a smuggling crate if one is carried, otherwise half of the riskiest stack, rounded up.
## Returns { crate = true }, the confiscated item and quantity, or an empty dictionary.
static func comply(run: RunState) -> Dictionary:
	Heat.add(run, -COMPLY_HEAT_DROP)
	if Smuggling.seize(run):
		return { "crate": true }
	var item := riskiest_item(run)
	if item == null:
		return {}
	var quantity := ceili(Inventory.count(run, item.id) / 2.0)
	Inventory.discard(run, item.id, quantity)
	return { "item": item, "quantity": quantity }


static func raid(run: RunState) -> void:
	seize_bag(run)
	run.heat = RAID_HEAT_AFTER
	run.busts += 1
	StreetCred.add(run, StreetCred.BUSTED)


static func seize_bag(run: RunState) -> void:
	Smuggling.seize(run)
	for item_id: StringName in run.inventory.keys():
		Inventory.discard(run, item_id, Inventory.count(run, item_id))
