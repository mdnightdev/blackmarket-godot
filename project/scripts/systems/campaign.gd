class_name Campaign

const CAREER_START := "career_start"
const SHARK: StringName = &"shark"


## Ends the run when the deadline passes with debt still owed. Returns true when the run was lost.
static func update_outcome(run: RunState) -> bool:
	if run.outcome != RunState.Outcome.ONGOING or run.career:
		return false
	if run.day <= run.campaign_days:
		return false
	run.outcome = RunState.Outcome.LOST
	run.pending_encounter = {}
	return true


## Clearing the debt in Act 1 starts the career. Returns true when it started now.
static func start_career_if_cleared(run: RunState) -> bool:
	if run.career or run.debt > 0 or run.outcome != RunState.Outcome.ONGOING:
		return false
	run.career = true
	run.pending_encounter = {
		"type": CAREER_START,
		"speaker": String(SHARK),
		"title": "Paid in full",
		"body": "Every cent, and early. I don't forget people who pay. The city is bigger than one debt. Build a crew, buy a front, take the streets. My door stays open if you need more money.",
	}
	return true


static func is_over(run: RunState) -> bool:
	return run.outcome == RunState.Outcome.LOST


static func net_worth(run: RunState) -> int:
	var total := run.cash + run.stashed_cash - run.debt
	for counts: Dictionary in [run.inventory, run.stash]:
		for item_id: StringName in counts:
			var item := Content.item(item_id)
			if item != null:
				total += item.base_price * int(counts[item_id])
	return total
