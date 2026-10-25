class_name Tutorial

## Lexie's street lessons. Each one plays once, the first time the player runs into that situation in Act 1.
## She has to be met first, in Old Market, and the player can switch the lessons off for the rest of the run.

const SPEAKER: StringName = &"lexie"
const NEXT: StringName = &"next"
const SKIP: StringName = &"skip"

const MEETING := "meeting"
const FIRST_BUY := "first_buy"
const FIRST_SALE := "first_sale"
const HOT := "hot"
const POLICE_STOP := "police_stop"
const CUSTOMER_ORDER := "customer_order"
const SHARK_ERRAND := "shark_errand"
const PAYMENT_DUE := "payment_due"
const PAYMENT_MADE := "payment_made"

const MEETING_DISTRICT: StringName = &"old_market"
## The payment lesson comes this many days before the due day, while paying still counts as early.
const PAYMENT_WARNING_DAYS := 3

const LINES := {
	MEETING: [
		"Rabbit says you owe the Shark. Everyone in here owes someone. Sit, I'll be quick.",
		"Rule one. You make money in the gap between two prices. Buy where it's cheap, sell where they need it.",
		"Auntie's my aunt, by the way. She asked me to keep you alive. I keep her books, so I'm cheaper than a bodyguard.",
	],
	FIRST_BUY: ["Your bag holds what it holds. Fill it with the thing that has the biggest gap, not the thing you like."],
	FIRST_SALE: ["That's profit. Now do it a hundred more times without getting caught."],
	HOT: ["People saw you. For a while you're hot. Cops look twice. Lie low, or move somewhere they don't know your face."],
	POLICE_STOP: [
		"Brandt. Moreau's junior. Young, hungry, wants a promotion, and you look like one.",
		"Ramos takes envelopes. Brandt takes names. Don't be the easiest one on his beat.",
	],
	CUSTOMER_ORDER: ["Customers don't respect new faces. Small orders, late payers. Deliver anyway. Respect comes from showing up."],
	SHARK_ERRAND: ["Never say no to him. He remembers who said no."],
	PAYMENT_DUE: ["Pay early if you can. He notices. He notices everything."],
	PAYMENT_MADE: ["You'll be fine. Probably. Come by the bar, I hear everything Auntie hears."],
}

const HINTS := {
	MEETING: "Tap a dealer to trade. The City button takes you to other districts.",
	FIRST_BUY: "Bag space and cash are on the top bar.",
	HOT: "Heat shows on the top bar. Trading stays quiet, running and fighting do not. Watched means Brandt follows you, Wanted means he raids.",
	SHARK_ERRAND: "Tap a banner to answer. Offers you miss wait in the Jobs tab.",
	PAYMENT_DUE: "Tap your debt on the top bar to pay from anywhere.",
}


static func is_on(run: RunState) -> bool:
	return run.opening_done and not run.tutorial_completed and not run.career


## Queues a lesson unless it already played. Nothing but the meeting plays before the player has met Lexie.
static func note(run: RunState, lesson: String) -> void:
	if not is_on(run) or run.lessons_seen.has(lesson) or run.lessons_queued.has(lesson):
		return
	if lesson != MEETING and not _met(run):
		return
	run.lessons_queued.append(lesson)


## Queues the lessons that can be read straight off the run. Buying and selling are noted where they happen.
static func observe(run: RunState) -> void:
	if not is_on(run):
		return
	if run.district_id == MEETING_DISTRICT:
		note(run, MEETING)
	if run.heat >= Heat.NOTICED:
		note(run, HOT)
	if str(run.pending_encounter.get("type", "")) == Encounters.POLICE:
		note(run, POLICE_STOP)
	if not run.customer_offers.is_empty() or not run.customer_orders.is_empty():
		note(run, CUSTOMER_ORDER)
	if run.errand_offers.any(func(offer: Dictionary) -> bool: return Errands.is_from_shark(offer)):
		note(run, SHARK_ERRAND)
	if _payment_close(run):
		note(run, PAYMENT_DUE)
	if run.covered_day > 0:
		note(run, PAYMENT_MADE)


static func next_lesson(run: RunState) -> String:
	if not is_on(run) or run.lessons_queued.is_empty():
		return ""
	return run.lessons_queued[0]


static func lines(lesson: String) -> Array:
	return LINES.get(lesson, [])


static func hint(lesson: String) -> String:
	return HINTS.get(lesson, "")


static func finish_lesson(run: RunState, lesson: String) -> void:
	run.lessons_queued.erase(lesson)
	if not run.lessons_seen.has(lesson):
		run.lessons_seen.append(lesson)


static func switch_off(run: RunState) -> void:
	run.tutorial_completed = true
	run.lessons_queued.clear()


static func choices(last_line: bool) -> Array[DialogueChoice]:
	return [
		DialogueChoice.new(NEXT, "Got it" if last_line else "Next", true, false, true),
		DialogueChoice.new(SKIP, "Skip tips", true, true),
	]


static func _met(run: RunState) -> bool:
	return run.lessons_seen.has(MEETING) or run.lessons_queued.has(MEETING)


static func _payment_close(run: RunState) -> bool:
	var days_left := run.next_due_day - 1 - run.day
	return run.debt > 0 and Loan.amount_due(run) > 0 and days_left <= PAYMENT_WARNING_DAYS
