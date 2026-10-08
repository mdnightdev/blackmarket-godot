class_name Heat

const MAX := 100
const DECAY_PER_PHASE := 4
const OVERNIGHT_DECAY := 6
const TRADE_RISK_DIVISOR := 40.0
const TRAVEL_RISK_DIVISOR := 100.0


static func carried_risk(run: RunState) -> int:
	var total := Smuggling.carried_risk(run)
	for item_id: StringName in run.inventory:
		var item := Content.item(item_id)
		if item != null:
			total += item.risk * int(run.inventory[item_id])
	return total


static func for_trade(run: RunState, item: ItemDef, quantity: int) -> int:
	var district := Content.district(run.district_id)
	var strictness := district.heat_multiplier if district != null else 1.0
	return ceili(item.risk * quantity * strictness / TRADE_RISK_DIVISOR)


static func for_travel(run: RunState) -> int:
	if Crew.removes_travel_heat(run):
		return 0
	return maxi(0, ceili(carried_risk(run) / TRAVEL_RISK_DIVISOR) - Skills.travel_heat_reduction(run))


static func add(run: RunState, amount: int) -> void:
	run.heat = clampi(run.heat + amount, 0, MAX)


static func cool_down(run: RunState, new_day_started: bool) -> void:
	add(run, -(DECAY_PER_PHASE + Skills.extra_cooling(run) + (OVERNIGHT_DECAY if new_day_started else 0)))


static func is_maxed(run: RunState) -> bool:
	return run.heat >= MAX
