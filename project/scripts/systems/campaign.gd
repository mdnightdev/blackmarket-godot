class_name Campaign

const CAREER_START := "career_start"
const SHARK: StringName = &"shark"


## Clearing the debt in Act 1 starts the career. Returns true when it started now.
static func start_career_if_cleared(run: RunState) -> bool:
	if run.career or run.debt > 0 or run.outcome != RunState.Outcome.ONGOING:
		return false
	run.career = true
	if Loan.is_with_vex(run):
		run.pending_encounter = {
			"type": CAREER_START,
			"speaker": String(Loan.VEX_LENDER),
			"title": "Paid in full",
			"body": "Paid. Double, like I said. You're off my book. Don't get comfortable in my market.",
		}
		return true
	run.pending_encounter = {
		"type": CAREER_START,
		"speaker": String(SHARK),
		"title": "Paid in full",
		"body": "Paid. In full. You are no longer my debtor. You may still work for me. Now it is a choice. Choices pay better. And the chair is still there. %s. When you are ready." % Format.money(Lending.BUYOUT_PRICE),
	}
	return true


## Act 2 opens once Vex kneels: crew, businesses, heists and the turf war outside Old Market.
static func is_act_two(run: RunState) -> bool:
	return Story.has(run, War.VEX_FELL)


## Careers saved before Act 1 had a story keep everything they built, so they start in Act 2 with Old Market held.
static func skip_act_one(run: RunState) -> void:
	Corners.take_all(run, Corners.HOME)
	Story.mark(run, Armory.UNLOCK_FLAG)
	Story.mark(run, War.VEX_FELL)


## Only saves from before the debt could be sold can be lost. New runs never end.
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
