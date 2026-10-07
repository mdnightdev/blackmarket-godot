class_name StreetTalk

## Conversations with the characters the player meets in a district.

const REPAY: StringName = &"repay"
const BORROW: StringName = &"borrow"
const PAY: StringName = &"pay"
const LEAVE: StringName = &"leave"


static func talk_to(character: CharacterDef) -> void:
	match character.role:
		CharacterDef.Role.LENDER:
			_talk_to_lender(character)
		CharacterDef.Role.INFORMANT:
			_talk_to_informant(character)
		_:
			var choices: Array[DialogueChoice] = [_leave()]
			GameOverlay.talk(character, character.line, choices, _end, character.blurb)


static func _talk_to_lender(shark: CharacterDef) -> void:
	var run := GameState.run
	var due_day := run.next_due_day - 1
	var line: String
	var choices: Array[DialogueChoice] = []
	if run.debt <= 0:
		line = "You're clear with me. Need another loan? My rates are fair. Mostly."
	elif Loan.amount_due(run) > 0:
		line = "You owe me %s. I want %s by the end of day %d." % [Format.money(run.debt), Format.money(Loan.amount_due(run)), due_day]
		choices.append(DialogueChoice.new(REPAY, "Repay"))
	else:
		line = "You owe me %s. This week is covered. Next payment is set on day %d." % [Format.money(run.debt), due_day]
		choices.append(DialogueChoice.new(REPAY, "Repay early"))
	choices.append(DialogueChoice.new(BORROW, "Borrow"))
	choices.append(_leave())
	GameOverlay.talk(shark, line, choices, _on_lender_choice)


static func _on_lender_choice(choice: StringName) -> void:
	GameOverlay.end_talk()
	if choice == REPAY:
		GameOverlay.open_loan(LoanSheet.Mode.REPAY)
	elif choice == BORROW:
		GameOverlay.open_loan(LoanSheet.Mode.BORROW)


static func _talk_to_informant(informant: CharacterDef) -> void:
	var price := Format.money(Informant.TIP_PRICE)
	var line := "Want to know where the cops walk next phase? %s, cash." % price
	var choices: Array[DialogueChoice] = [
		DialogueChoice.new(PAY, "Pay %s" % price, Informant.can_afford_tip(GameState.run)),
		DialogueChoice.new(LEAVE, "Not now", true, true),
	]
	GameOverlay.talk(informant, line, choices, _on_informant_choice, informant.blurb)


static func _on_informant_choice(choice: StringName) -> void:
	if choice != PAY:
		GameOverlay.end_talk()
		return
	var patrols := GameState.buy_police_tip()
	var done: Array[DialogueChoice] = [_leave()]
	GameOverlay.say(_describe_patrols(patrols), done, _end)


static func _describe_patrols(patrols: Dictionary) -> String:
	if patrols.is_empty():
		return "No cash, no talk."
	var sightings: Array[String] = []
	for officer: CharacterDef in patrols:
		var district := Content.district(patrols[officer])
		sightings.append("%s will be in %s." % [officer.display_name, district.display_name if district != null else "town"])
	return "%s You didn't hear it from me." % " ".join(sightings)


static func _leave() -> DialogueChoice:
	return DialogueChoice.new(LEAVE, "Leave", true, true)


static func _end(_choice: StringName) -> void:
	GameOverlay.end_talk()
