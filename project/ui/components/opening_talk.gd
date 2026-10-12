class_name OpeningTalk

## Plays once when a run starts: how the character ended up owing the Shark, his terms, then 午夜兔子 waiting
## outside the office.

const NEXT: StringName = &"next"
const SKIP: StringName = &"skip"
const PROMISE: StringName = &"promise"
const ASK: StringName = &"ask"

const SHARK: StringName = &"shark"
const FRIEND: StringName = &"midnight_rabbit"

const PROMISE_REPLY := "Everyone says that. Show me."
const ASK_REPLY := "Then your debt goes to someone less patient than me. There is always someone."


static func should_play(run: RunState) -> bool:
	return not run.opening_done


static func play() -> void:
	_show_origin(0)


## The story, then the scene that follows it. Empty when the character has none.
static func _origin(run: RunState) -> Array[Dictionary]:
	var pages: Array[Dictionary] = []
	var player := Content.player(run.player_id)
	if player == null or player.origin_story.is_empty():
		return pages
	pages.append({ "speaker": player, "line": player.origin_story })
	for entry in player.origin_lines:
		var speaker_id := str(entry.get("speaker", ""))
		var speaker: SpeakerDef = player if speaker_id == PlayerDef.ORIGIN_PLAYER else Content.speaker(StringName(speaker_id))
		if speaker != null:
			pages.append({ "speaker": speaker, "line": str(entry.get("line", "")) })
	return pages


static func _show_origin(index: int) -> void:
	var origin := _origin(GameState.run)
	if index >= origin.size():
		_show_term(0)
		return
	var page: Dictionary = origin[index]
	var choices: Array[DialogueChoice] = [DialogueChoice.new(NEXT, "Next", true, false, true), DialogueChoice.new(SKIP, "Skip", true, true)]
	GameOverlay.talk(page.speaker, str(page.line), choices, _on_origin.bind(index))


static func _on_origin(choice: StringName, index: int) -> void:
	if choice == SKIP:
		_finish()
	else:
		_show_origin(index + 1)


static func _terms() -> Array[Dictionary]:
	return [
		{ "line": "Sit. Tea? No? Then let us talk about what you owe me." },
		{
			"line": "You owe me %s. You have %s. That is a start, not an answer." % [Format.money(RunState.STARTING_DEBT), Format.money(RunState.STARTING_CASH)],
			"hint": "The top bar shows your cash and debt.",
		},
		{
			"line": "You pay me every week. Pay on time and the number does not grow. Miss a week and it grows, and my men come to remind you.",
			"hint": "First payment: %s by the end of day %d. Tap your debt on the top bar to pay." % [Format.money(Loan.FIRST_PAYMENT), Loan.PAYMENT_PERIOD_DAYS],
		},
		{ "line": "Sometimes I will ask a favour. A package, a word in someone's ear. Do not refuse me, and do not be late." },
		{ "line": "Do this well and we may talk about more than a debt. Do it badly and I will find someone who does it well." },
	]


static func _outro(run: RunState) -> Array[Dictionary]:
	return [
		{ "speaker": Content.speaker(FRIEND), "line": "You good?" },
		{ "speaker": Content.player(run.player_id), "line": "A hundred grand." },
		{ "speaker": Content.speaker(FRIEND), "line": "Then we start tonight. I know someone who knows the market better than both of us." },
	]


static func _show_term(index: int) -> void:
	var terms := _terms()
	var term: Dictionary = terms[index]
	var choices: Array[DialogueChoice] = []
	if index == terms.size() - 1:
		choices.append(DialogueChoice.new(PROMISE, "I'll pay."))
		choices.append(DialogueChoice.new(ASK, "And if I can't?"))
	else:
		choices.append(DialogueChoice.new(NEXT, "Next", true, false, true))
	choices.append(DialogueChoice.new(SKIP, "Skip", true, true))
	GameOverlay.talk(Content.speaker(SHARK), str(term.line), choices, _on_term.bind(index), str(term.get("hint", "")))


static func _on_term(choice: StringName, index: int) -> void:
	match choice:
		SKIP:
			_finish()
		NEXT:
			_show_term(index + 1)
		_:
			var reply := PROMISE_REPLY if choice == PROMISE else ASK_REPLY
			GameOverlay.say(reply, _continue_choices(), func(_id: StringName) -> void: _show_outro(0))


static func _show_outro(index: int) -> void:
	var outro := _outro(GameState.run)
	if index >= outro.size():
		_finish()
		return
	var page: Dictionary = outro[index]
	GameOverlay.talk(page.speaker, str(page.line), _continue_choices(), func(_id: StringName) -> void: _show_outro(index + 1))


static func _continue_choices() -> Array[DialogueChoice]:
	return [DialogueChoice.new(NEXT, "Next", true, false, true)]


static func _finish() -> void:
	GameOverlay.end_talk()
	GameState.finish_opening()
