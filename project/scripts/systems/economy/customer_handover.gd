class_name CustomerHandover

## The card shown on arriving where a customer waits and the bag holds the whole order. A haggler who asks
## for less at the handover answers with a second card: take the lower price or hold firm.

const TYPE := "handover"
const OFFER_STAGE := "offer"
const HAND_OVER: StringName = &"handover_give"
const NOT_NOW: StringName = &"handover_later"


static func start(run: RunState, order: Dictionary) -> Dictionary:
	var customer := Content.customer(StringName(str(order.customer)))
	var line := " \"%s\"" % customer.line if customer != null else ""
	var meeting := Customers.is_meeting(run, order)
	var unit_price := Meetings.offered_price(int(order.unit_price)) if meeting else int(order.unit_price)
	var arrival := "came out to meet you" if meeting else "is here"
	return {
		"type": TYPE,
		"stage": OFFER_STAGE,
		"speaker": String(run.player_id),
		"title": "Handover",
		"body": "%s %s for %s at %s each.%s" % [Customers.customer_name(order), arrival, Customers.goods_label(order), Format.money(unit_price), line],
		"order": str(order.id),
		"total": Customers.meeting_total(order) if meeting else Customers.total(order),
	}


static func choices(run: RunState, encounter: Dictionary) -> Array[Encounters.Choice]:
	var list: Array[Encounters.Choice] = []
	var order := Customers.find(run, str(encounter.get("order", "")))
	list.append(Encounters.Choice.new(HAND_OVER, "Hand over for %s" % Format.money(int(encounter.total)), not order.is_empty() and Customers.can_hand_over(run, order)))
	list.append(Encounters.Choice.new(NOT_NOW, "Not now"))
	return list


## Applies the answer. Returns the outcome text, empty when the card can simply close.
## The roll must be in the range [0, 1).
static func resolve(run: RunState, encounter: Dictionary, choice: StringName, roll: float = 0.0) -> String:
	var order := Customers.find(run, str(encounter.get("order", "")))
	if order.is_empty():
		return ""
	var result := {}
	match choice:
		HAND_OVER:
			result = Customers.hand_over(run, order, roll)
	return describe(result)
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
