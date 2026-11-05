class_name StreetEvents

const EVENT_CHANCE := 0.18
const MIN_MUGGING_CASH := 100
## A mugging takes the event's cash_fraction of the player's cash as the usual amount, within these bounds.
const MUGGING_LOW := 0.02
const MUGGING_HIGH := 0.12
const MAX_MUGGING := 2500
## Strength lead over a street crew before skills and crew.
const FIGHT_EDGE := 0.05
const FIGHT_LOSS_MULTIPLIER := 1.5
const LUCKY_FIND_MAX_PRICE := 500


## Price shifts are stored as { district, category, multiplier, from, until } with inclusive phase stamps.
static func price_multiplier(run: RunState, district_id: StringName, category: StringName, phase_stamp: int) -> float:
	var factor := 1.0
	for shift in run.market_shifts:
		if _shift_matches(shift, district_id, phase_stamp) and shift.category == String(category):
			factor *= shift.multiplier
	return factor


static func active_shifts(run: RunState, district_id: StringName) -> Array[Dictionary]:
	var stamp := Calendar.stamp(run)
	var list: Array[Dictionary] = []
	for shift in run.market_shifts:
		if _shift_matches(shift, district_id, stamp):
			list.append(shift)
	return list


static func headline(shift: Dictionary) -> String:
	var percent := roundi(absf(float(shift.multiplier) - 1.0) * 100.0)
	var direction := "up" if float(shift.multiplier) >= 1.0 else "down"
	return "%s prices %s %d%%" % [String(shift.category).capitalize(), direction, percent]


static func prune(run: RunState) -> void:
	var stamp := Calendar.stamp(run)
	run.market_shifts = run.market_shifts.filter(func(shift: Dictionary) -> bool: return int(shift.until) >= stamp)


static func sanitize_shift(source: Dictionary) -> Dictionary:
	return {
		"district": str(source.get("district", "")),
		"category": str(source.get("category", "")),
		"multiplier": clampf(float(source.get("multiplier", 1.0)), 0.2, 3.0),
		"from": int(source.get("from", 0)),
		"until": int(source.get("until", -1)),
	}


## Picks a weighted event that can actually happen right now and resolves its targets.
## Returns an encounter dictionary, or an empty one when nothing fits.
static func roll_event(run: RunState, events: Array[EventDef], rng: RandomNumberGenerator) -> Dictionary:
	var options: Array[Dictionary] = []
	var weights: Array[int] = []
	for event in events:
		if run.day < event.min_day:
			continue
		var encounter := prepare(run, event, rng)
		if not encounter.is_empty():
			options.append(encounter)
			weights.append(event.weight)
	if options.is_empty():
		return {}
	var pick := rng.randi_range(1, weights.reduce(func(sum: int, weight: int) -> int: return sum + weight, 0))
	for index in options.size():
		pick -= weights[index]
		if pick <= 0:
			return options[index]
	return options.back()


static func prepare(run: RunState, event: EventDef, rng: RandomNumberGenerator) -> Dictionary:
	var encounter := {
		"type": Encounters.EVENT,
		"event": String(event.id),
		"effect": event.effect,
		"title": event.title,
		"speaker": String(event.speaker),
	}
	var details := {}
	match event.effect:
		EventDef.Effect.PRICE_SHIFT:
			details = _prepare_shift(run, event, rng)
		EventDef.Effect.MUGGING:
			if rng.randf() < Crew.mugging_factor(run):
				details = _prepare_mugging(run, event, rng)
		EventDef.Effect.LUCKY_FIND:
			details = _prepare_find(run, event, rng)
	if details.is_empty():
		return {}
	encounter.merge(details)
	encounter.body = event.body.format(details.get("text", {}))
	encounter.erase("text")
	return encounter


static func apply_shift(run: RunState, encounter: Dictionary) -> void:
	run.market_shifts.append(sanitize_shift(encounter))


static func _shift_matches(shift: Dictionary, district_id: StringName, phase_stamp: int) -> bool:
	return shift.district == String(district_id) and int(shift.from) <= phase_stamp and phase_stamp <= int(shift.until)


static func _prepare_shift(run: RunState, event: EventDef, rng: RandomNumberGenerator) -> Dictionary:
	var dealer: DealerDef = null
	var categories: Array[StringName] = []
	match event.scope:
		EventDef.Scope.HERE:
			dealer = Content.dealer_in(run.district_id)
			if dealer != null:
				categories = dealer.stock_categories.duplicate()
		EventDef.Scope.ELSEWHERE:
			var targets := Content.dealers().filter(func(entry: DealerDef) -> bool:
				return entry.is_resident() and entry.district_id != run.district_id \
						and not Travel.is_locked(run, Content.district(entry.district_id)) \
						and (event.category.is_empty() or entry.stock_categories.has(event.category)))
			if not targets.is_empty():
				dealer = targets[rng.randi_range(0, targets.size() - 1)]
				categories = dealer.stock_categories.duplicate()
		EventDef.Scope.CARRIED_HERE:
			dealer = Content.dealer_in(run.district_id)
			if dealer != null:
				categories = _carried_categories(run, dealer)
	if not event.category.is_empty():
		categories = categories.filter(func(cat: StringName) -> bool: return cat == event.category)
	if dealer == null or categories.is_empty():
		return {}

	var category := categories[rng.randi_range(0, categories.size() - 1)]
	var district := Content.district(dealer.district_id)
	var starts := run.day * RunState.Phase.size() if event.starts_next_day else Calendar.stamp(run)
	return {
		"district": String(dealer.district_id),
		"category": String(category),
		"multiplier": event.multiplier,
		"from": starts,
		"until": starts + event.duration_phases - 1,
		"text": { "district": district.display_name, "category": String(category) },
	}


static func _carried_categories(run: RunState, dealer: DealerDef) -> Array[StringName]:
	var categories: Array[StringName] = []
	for item_id: StringName in run.inventory:
		var item := Content.item(item_id)
		if item != null and dealer.sells(item) and not categories.has(item.category):
			categories.append(item.category)
	return categories


## Nobody mugs the player on corners their own crew runs.
static func _prepare_mugging(run: RunState, event: EventDef, rng: RandomNumberGenerator) -> Dictionary:
	if run.cash < MIN_MUGGING_CASH or Turf.holder(run, run.district_id) == Turf.Holder.PLAYER:
		return {}
	var usual := clampf(event.cash_fraction, MUGGING_LOW, MUGGING_HIGH)
	var amount := clampi(roundi(run.cash * Odds.bell(rng, MUGGING_LOW, usual, MUGGING_HIGH)), 1, MAX_MUGGING)
	return { "amount": amount, "text": { "amount": Format.money(amount) } }


static func fight_chance(run: RunState) -> float:
	return Odds.contest(FIGHT_EDGE + fight_bonus(run))


## What the player brings to any fight: the Muscle skill and crew.
static func fight_bonus(run: RunState) -> float:
	return Skills.fight_bonus(run) + Crew.fight_bonus(run)


static func _prepare_find(run: RunState, event: EventDef, rng: RandomNumberGenerator) -> Dictionary:
	var free := Inventory.free_space(run)
	var candidates := Content.tradable_items().filter(func(cand: ItemDef) -> bool:
		return cand.base_price <= LUCKY_FIND_MAX_PRICE and cand.slots <= free)
	if candidates.is_empty():
		return {}
	var item: ItemDef = candidates[rng.randi_range(0, candidates.size() - 1)]
	var quantity := mini(rng.randi_range(event.min_quantity, event.max_quantity), floori(float(free) / item.slots))
	return {
		"item": String(item.id),
		"quantity": quantity,
		"text": { "item": item.display_name, "quantity": quantity },
	}
