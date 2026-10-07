class_name Police

const BASE_STOP_CHANCE := 0.03
const HEAT_STOP_CHANCE := 0.35
const CARGO_RISK_SCALE := 2000.0
const MAX_CARGO_STOP_CHANCE := 0.15
const MAX_STOP_CHANCE := 0.6

const MIN_BRIBE := 100
const BRIBE_FRACTION := 0.25

const BASE_ESCAPE_CHANCE := 0.6
const ESCAPE_HEAT_SCALE := 250.0
const MIN_ESCAPE_CHANCE := 0.2
const MAX_ESCAPE_CHANCE := 0.75
const VEHICLE_ESCAPE_BONUS := 0.1

const ESCAPED_HEAT := 10
const CAUGHT_HEAT := 15
const COMPLY_HEAT_DROP := 15
const RAID_HEAT_AFTER := 50


## Police only bother players who are carrying goods. A patrol in the district raises the odds.
static func stop_chance(run: RunState) -> float:
	var cargo_risk := Heat.carried_risk(run)
	if cargo_risk <= 0:
		return 0.0
	var district := Content.district(run.district_id)
	var strictness := district.heat_multiplier if district != null else 1.0
	var patrol := Roster.patrol_multiplier(run, run.district_id, Calendar.stamp(run))
	var chance := BASE_STOP_CHANCE + float(run.heat) / Heat.MAX * HEAT_STOP_CHANCE
	chance += minf(cargo_risk / CARGO_RISK_SCALE, MAX_CARGO_STOP_CHANCE)
	return minf(chance * strictness * patrol, MAX_STOP_CHANCE)


static func carried_value(run: RunState) -> int:
	var total := 0
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
	return chance


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
	return false


## Hands over the riskiest stack. Returns the confiscated item and quantity.
static func comply(run: RunState) -> Dictionary:
	var item := riskiest_item(run)
	Heat.add(run, -COMPLY_HEAT_DROP)
	if item == null:
		return {}
	var quantity := Inventory.count(run, item.id)
	Inventory.discard(run, item.id, quantity)
	return { "item": item, "quantity": quantity }


static func raid(run: RunState) -> void:
	seize_bag(run)
	run.heat = RAID_HEAT_AFTER
	run.busts += 1


static func seize_bag(run: RunState) -> void:
	for item_id: StringName in run.inventory.keys():
		Inventory.discard(run, item_id, Inventory.count(run, item_id))
