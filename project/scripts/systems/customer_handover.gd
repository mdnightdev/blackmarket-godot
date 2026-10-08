class_name CustomerHandover

## The card shown on arriving where a customer waits and the bag holds the whole order. A haggler who asks
## for less at the handover answers with a second card: take the lower price or hold firm.

const TYPE := "handover"
const OFFER_STAGE := "offer"
const COUNTER_STAGE := "counter"
const HAND_OVER: StringName = &"handover_give"
const NOT_NOW: StringName = &"handover_later"
const TAKE_COUNTER: StringName = &"handover_take"
const HOLD_FIRM: StringName = &"handover_hold"


static func start(run: RunState, order: Dictionary) -> Dictionary:
	var customer := Content.customer(StringName(str(order.customer)))
	var line := " \"%s\"" % customer.line if customer != null else ""
	return {
		"type": TYPE,
		"stage": OFFER_STAGE,
		"speaker": String(run.player_id),
		"title": "Handover",
		"body": "%s is here for %s at %s each.%s" % [Customers.customer_name(order), Customers.goods_label(order), Format.money(int(order.unit_price)), line],
		"order": str(order.id),
		"total": Customers.total(order),
	}


static func counter(run: RunState, order: Dictionary) -> Dictionary:
	var counter_total := int(order.counter_price) * int(order.quantity)
	return {
		"type": TYPE,
		"stage": COUNTER_STAGE,
		"speaker": String(run.player_id),
		"title": "Counter offer",
		"body": "%s wants to pay %s instead of the %s you agreed." % [Customers.customer_name(order), Format.money(counter_total), Format.money(Customers.total(order))],
		"order": str(order.id),
		"total": Customers.total(order),
		"counter_total": counter_total,
	}


static func choices(run: RunState, encounter: Dictionary) -> Array[Encounters.Choice]:
	var list: Array[Encounters.Choice] = []
	if str(encounter.get("stage", "")) == COUNTER_STAGE:
		list.append(Encounters.Choice.new(TAKE_COUNTER, "Take %s" % Format.money(int(encounter.counter_total))))
		list.append(Encounters.Choice.new(HOLD_FIRM, "Hold firm at %s (%s)" % [Format.money(int(encounter.total)), Odds.reading(Customers.hold_firm_chance(run))]))
		return list
	var order := Customers.find(run, str(encounter.get("order", "")))
	list.append(Encounters.Choice.new(HAND_OVER, "Hand over for %s" % Format.money(int(encounter.total)), not order.is_empty() and Customers.can_hand_over(run, order)))
	list.append(Encounters.Choice.new(NOT_NOW, "Not now"))
	return list


## Applies the answer. Returns the outcome text, empty when the card can simply close.
## The roll must be in the range [0, 1).
static func resolve(run: RunState, encounter: Dictionary, choice: StringName, roll: float) -> String:
	var order := Customers.find(run, str(encounter.get("order", "")))
	if order.is_empty():
		return ""
	var result := {}
	match choice:
		HAND_OVER:
			result = Customers.hand_over(run, order, roll)
			if bool(result.get("haggled", false)):
				run.pending_encounter = counter(run, order)
		TAKE_COUNTER:
			result = Customers.answer_haggle(run, order, true, roll)
		HOLD_FIRM:
			result = Customers.answer_haggle(run, order, false, roll)
	return describe(result)


## The result line followed by any daily task the sale finished.
static func describe(result: Dictionary) -> String:
	var text := str(result.get("line", ""))
	for task: Dictionary in result.get("tasks", []):
		text += " Task done: %s." % DailyTasks.describe(task)
	return text


## Clears a waiting handover card for the order, for when the player answers it from a screen instead.
static func dismiss(run: RunState, order_id: String) -> void:
	if str(run.pending_encounter.get("type", "")) == TYPE and str(run.pending_encounter.get("order", "")) == order_id:
		run.pending_encounter = {}
