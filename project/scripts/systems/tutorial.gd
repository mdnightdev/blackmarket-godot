class_name Tutorial

const SPEAKER: StringName = &"shark"
const NEXT: StringName = &"next"
const SKIP: StringName = &"skip"


static func should_show(run: RunState) -> bool:
	return not run.tutorial_completed and run.tutorial_step < pages().size()


static func page(run: RunState) -> Dictionary:
	return pages()[clampi(run.tutorial_step, 0, pages().size() - 1)]


static func advance(run: RunState) -> void:
	run.tutorial_step += 1
	if run.tutorial_step >= pages().size():
		finish(run)


static func finish(run: RunState) -> void:
	run.tutorial_step = pages().size()
	run.tutorial_completed = true


static func choices(run: RunState) -> Array[DialogueChoice]:
	var last := run.tutorial_step >= pages().size() - 1
	var list: Array[DialogueChoice] = [DialogueChoice.new(NEXT, "Got it" if last else "Next")]
	if not last:
		list.append(DialogueChoice.new(SKIP, "Skip tutorial", true, true))
	return list


static func pages() -> Array[Dictionary]:
	return [
		{
			"line": "You owe me %s. Pay me every week. The first week is %s. Miss %d weeks in a row and we are done." % [Format.money(RunState.STARTING_DEBT), Format.money(Loan.FIRST_PAYMENT), Loan.MAX_MISSED_WEEKS],
			"hint": "The top bar shows your cash and debt. Pay at my office in Downtown.",
		},
		{
			"line": "You will run errands for me. When I have work, your phone buzzes. Part of the pay comes off your debt.",
			"hint": "Tap a banner to answer. Offers you miss wait in the Jobs tab.",
		},
		{
			"line": "Customers will text you too. Buy the goods cheap, carry them over, keep the difference. Some of them pay badly. Do the sums.",
			"hint": "Tap a dealer to trade. The City button takes you to other districts.",
		},
	]
