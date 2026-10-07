class_name Campaign


## Settles the run once the debt is cleared or the deadline passes. Returns true when the outcome changed.
static func update_outcome(run: RunState) -> bool:
	if run.outcome != RunState.Outcome.ONGOING:
		return false
	if run.debt <= 0:
		run.outcome = RunState.Outcome.WON
	elif run.day > run.campaign_days:
		run.outcome = RunState.Outcome.LOST
	else:
		return false
	run.pending_encounter = {}
	return true


static func is_over(run: RunState) -> bool:
	return run.outcome == RunState.Outcome.LOST or (run.outcome == RunState.Outcome.WON and not run.endless)


static func net_worth(run: RunState) -> int:
	var total := run.cash - run.debt
	for counts: Dictionary in [run.inventory, run.stash]:
		for item_id: StringName in counts:
			var item := Content.item(item_id)
			if item != null:
				total += item.base_price * int(counts[item_id])
	return total


static func continue_endless(run: RunState) -> void:
	if run.outcome == RunState.Outcome.WON:
		run.endless = true
