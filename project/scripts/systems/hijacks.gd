class_name Hijacks

## One shipment can be hit at Pier 9 each phase. A target is { item, quantity }.

enum Approach { QUIET, LOUD }

const SUCCESS_CHANCE := { Approach.QUIET: 0.45, Approach.LOUD: 0.7 }
const HEAT := { Approach.QUIET: 6, Approach.LOUD: 20 }
## Added on top of the approach heat when the job goes wrong.
const FAILED_HEAT := 20
const MIN_TARGET_VALUE := 1500
const MAX_TARGET_VALUE := 6000
const MIN_QUANTITY := 2
const MAX_QUANTITY := 20


## This phase's shipment. It comes from the run seed, so a reload cannot reroll it.
static func target(run: RunState) -> Dictionary:
	var goods := Tiers.goods(Tiers.STREET)
	if goods.is_empty():
		return {}
	goods.sort_custom(func(a: ItemDef, b: ItemDef) -> bool: return String(a.id) < String(b.id))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run.price_seed, &"hijack", Calendar.stamp(run)])
	var item := goods[rng.randi_range(0, goods.size() - 1)]
	var value := rng.randi_range(MIN_TARGET_VALUE, MAX_TARGET_VALUE)
	return { "item": item, "quantity": clampi(roundi(float(value) / item.base_price), MIN_QUANTITY, MAX_QUANTITY) }


static func attempted(run: RunState) -> bool:
	return run.hijacked_stamp == Calendar.stamp(run)


## Units the player could carry away, limited by free bag space.
static func haul(run: RunState, shipment: Dictionary) -> int:
	var item: ItemDef = shipment.item
	return mini(int(shipment.quantity), floori(float(Inventory.free_space(run)) / item.slots))


static func can_attempt(run: RunState, shipment: Dictionary) -> bool:
	return not shipment.is_empty() and not attempted(run) and haul(run, shipment) > 0


## Returns the units taken, 0 when the job failed. A failed job brings the police straight away.
## The roll must be in the range [0, 1).
static func attempt(run: RunState, shipment: Dictionary, approach: Approach, roll: float) -> int:
	if not can_attempt(run, shipment):
		return 0
	run.hijacked_stamp = Calendar.stamp(run)
	Heat.add(run, HEAT[approach])
	if roll >= SUCCESS_CHANCE[approach]:
		Heat.add(run, FAILED_HEAT)
		if not Encounters.has_pending(run):
			run.pending_encounter = Encounters.police_stop(run)
		return 0
	var item: ItemDef = shipment.item
	var quantity := haul(run, shipment)
	var held := Inventory.count(run, item.id) + Inventory.stashed(run, item.id)
	var paid_before := int(run.cost_basis.get(item.id, 0)) * held
	Inventory.add_units(run, item.id, quantity)
	run.cost_basis[item.id] = roundi(float(paid_before) / (held + quantity))
	StreetCred.add(run, StreetCred.HIJACK_SUCCESS)
	return quantity
