class_name SharkTrust

## How much the Shark trusts the player while they work off the debt. Paying on time and doing his errands
## raises it, refusing or failing him lowers it. At the floor he sells the debt (see DebtSale).
## The player only ever sees the level name, never the number.

const START := 50
const MAX := 100
const LEVEL_SIZE := 20
const LEVEL_NAMES: Array[String] = ["Fed up", "Wary", "Neutral", "Warm", "Trusted"]

const PAID_ON_TIME := 4
const PAID_EARLY := 8
const MISSED_WEEK := -15
const ERRAND_DONE := 3
const ERRAND_DECLINED := -6
const ERRAND_FAILED := -10
const BUSTED := -5

## Covering the week at least this many days before it is due counts as early.
const EARLY_DAYS := 2
## The inheritance talk comes once this share of the starting debt is left and no week was ever missed.
const PROMISE_DEBT_SHARE := 0.5

const LETTER := "shark_letter"
const PROMISE := "shark_promise"
const SPEAKER: StringName = &"shark"


static func applies(run: RunState) -> bool:
	return run.lender == Loan.LENDER


static func add(run: RunState, amount: int) -> void:
	if applies(run):
		run.shark_trust = clampi(run.shark_trust + amount, 0, MAX)


static func level(run: RunState) -> int:
	return clampi(floori(float(run.shark_trust) / LEVEL_SIZE), 0, LEVEL_NAMES.size() - 1)


static func level_name(run: RunState) -> String:
	return LEVEL_NAMES[level(run)]


static func at_floor(run: RunState) -> bool:
	return run.shark_trust <= 0


static func paid_early(run: RunState) -> bool:
	return run.covered_day > 0 and run.covered_day <= run.next_due_day - 1 - EARLY_DAYS


## Called on the due day before the next period starts. The first early payment of Act 1 earns a letter.
static func settle_week(run: RunState, paid: bool) -> void:
	if not applies(run):
		return
	if not paid:
		add(run, MISSED_WEEK)
		return
	var early := paid_early(run)
	add(run, PAID_EARLY if early else PAID_ON_TIME)
	if early and not run.career and not run.shark_letter_sent and not Encounters.has_pending(run):
		run.shark_letter_sent = true
		run.pending_encounter = {
			"type": LETTER,
			"speaker": String(SPEAKER),
			"title": "A letter from the Shark",
			"body": "Early. Few people do that. I see potential in you. Do not make me wrong.",
		}


## Queues the inheritance talk once half the debt is gone without a single missed week. Returns true when queued.
static func check_promise(run: RunState) -> bool:
	if run.career or not applies(run) or run.inheritance_promised or run.missed_total > 0:
		return false
	if run.debt <= 0 or run.debt > RunState.STARTING_DEBT * PROMISE_DEBT_SHARE or Encounters.has_pending(run):
		return false
	run.inheritance_promised = true
	run.pending_encounter = {
		"type": PROMISE,
		"speaker": String(SPEAKER),
		"title": "Two cups of tea",
		"body": "Half. On time, every week. Do you know how rare that is? I am old. My business is not. One day someone sits in this chair. I would like it to be someone who pays on time. Finish the debt. Then we talk about the chair.",
	}
	return true
