class_name RunState
extends RefCounted

enum Phase { MORNING, NOON, EVENING, NIGHT }
enum Outcome { ONGOING, WON, LOST }

const PHASE_NAMES: Array[String] = ["Morning", "Noon", "Evening", "Night"]
const STARTING_CASH := 2000
const STARTING_DEBT := 5000
const CAMPAIGN_DAYS := 30
const STARTING_DISTRICT: StringName = &"old_market"
const DEFAULT_PLAYER: StringName = &"kade"

var player_id: StringName = DEFAULT_PLAYER
var price_seed: int = randi()
var day: int = 1
var phase: Phase = Phase.MORNING
var phase_seconds_left: float = Calendar.PHASE_SECONDS
var cash: int = STARTING_CASH
var debt: int = STARTING_DEBT
var heat: int = 0
var campaign_days: int = CAMPAIGN_DAYS
var district_id: StringName = STARTING_DISTRICT
## Item id to units carried.
var inventory: Dictionary = {}
## Item id to units stored in the safehouse stash.
var stash: Dictionary = {}
## Item id to average price paid per unit, for goods currently held.
var cost_basis: Dictionary = {}
var gear: Array[StringName] = []
## Dealer id to the phase stamp in which that dealer refused to trade.
var walked_out: Dictionary = {}
## Temporary price changes from street events. See StreetEvents for the entry layout.
var market_shifts: Array[Dictionary] = []
## The encounter waiting for the player's answer. Saved so closing the app cannot dodge it.
var pending_encounter: Dictionary = {}

var next_due_day: int = Loan.PAYMENT_PERIOD_DAYS + 1
var period_minimum: int = Loan.minimum_payment(STARTING_DEBT)
var paid_this_period: int = 0

var outcome: Outcome = Outcome.ONGOING
var endless := false
var trades: int = 0
var profit: int = 0
var busts: int = 0


static func phase_name(value: Phase) -> String:
	return PHASE_NAMES[value]


func to_dict() -> Dictionary:
	var saved_gear: Array[String] = []
	for item_id in gear:
		saved_gear.append(String(item_id))
	return {
		"player_id": String(player_id),
		"price_seed": price_seed,
		"day": day,
		"phase": phase,
		"phase_seconds_left": phase_seconds_left,
		"cash": cash,
		"debt": debt,
		"heat": heat,
		"campaign_days": campaign_days,
		"district_id": String(district_id),
		"inventory": _string_keys(inventory),
		"stash": _string_keys(stash),
		"cost_basis": _string_keys(cost_basis),
		"gear": saved_gear,
		"walked_out": _string_keys(walked_out),
		"market_shifts": market_shifts,
		"pending_encounter": pending_encounter,
		"next_due_day": next_due_day,
		"period_minimum": period_minimum,
		"paid_this_period": paid_this_period,
		"outcome": outcome,
		"endless": endless,
		"trades": trades,
		"profit": profit,
		"busts": busts,
	}


static func from_dict(data: Dictionary) -> RunState:
	var state := RunState.new()
	state.player_id = StringName(str(data.get("player_id", state.player_id)))
	state.price_seed = int(data.get("price_seed", state.price_seed))
	state.day = maxi(1, int(data.get("day", state.day)))
	state.phase = clampi(int(data.get("phase", state.phase)), 0, Phase.size() - 1) as Phase
	state.phase_seconds_left = clampf(float(data.get("phase_seconds_left", state.phase_seconds_left)), 0.0, Calendar.PHASE_SECONDS)
	state.cash = int(data.get("cash", state.cash))
	state.debt = maxi(0, int(data.get("debt", state.debt)))
	state.heat = clampi(int(data.get("heat", state.heat)), 0, 100)
	state.campaign_days = maxi(1, int(data.get("campaign_days", state.campaign_days)))
	state.district_id = StringName(str(data.get("district_id", state.district_id)))
	state.inventory = _positive_counts(data.get("inventory"))
	state.stash = _positive_counts(data.get("stash"))
	state.cost_basis = _positive_counts(data.get("cost_basis"))
	state.walked_out = _positive_counts(data.get("walked_out"), 0)

	var saved_gear: Variant = data.get("gear", [])
	if saved_gear is Array:
		for item_id: Variant in saved_gear:
			var gear_id := StringName(str(item_id))
			if not state.gear.has(gear_id):
				state.gear.append(gear_id)

	var saved_shifts: Variant = data.get("market_shifts", [])
	if saved_shifts is Array:
		for shift: Variant in saved_shifts:
			if shift is Dictionary:
				state.market_shifts.append(StreetEvents.sanitize_shift(shift))
	var saved_encounter: Variant = data.get("pending_encounter", {})
	if saved_encounter is Dictionary:
		state.pending_encounter = saved_encounter

	state.next_due_day = maxi(2, int(data.get("next_due_day", state.next_due_day)))
	state.period_minimum = maxi(0, int(data.get("period_minimum", state.period_minimum)))
	state.paid_this_period = maxi(0, int(data.get("paid_this_period", state.paid_this_period)))
	state.outcome = clampi(int(data.get("outcome", state.outcome)), 0, Outcome.size() - 1) as Outcome
	state.endless = bool(data.get("endless", state.endless))
	state.trades = maxi(0, int(data.get("trades", state.trades)))
	state.profit = int(data.get("profit", state.profit))
	state.busts = maxi(0, int(data.get("busts", state.busts)))
	return state


static func _string_keys(source: Dictionary) -> Dictionary:
	var result := {}
	for key: StringName in source:
		result[String(key)] = source[key]
	return result


static func _positive_counts(source: Variant, minimum: int = 1) -> Dictionary:
	var result := {}
	if source is Dictionary:
		for key: Variant in source:
			var value := int(source[key])
			if value >= minimum:
				result[StringName(str(key))] = value
	return result
