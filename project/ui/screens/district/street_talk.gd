class_name StreetTalk

## Conversations with the characters the player meets in a district.

const REPAY: StringName = &"repay"
const BORROW: StringName = &"borrow"
const PAY: StringName = &"pay"
const MUSCLE: StringName = &"muscle"
const LEAVE: StringName = &"leave"


static func talk_to(character: CharacterDef) -> void:
	match character.role:
		CharacterDef.Role.LENDER:
			_talk_to_lender(character)
		CharacterDef.Role.INFORMANT:
			_talk_to_informant(character)
		CharacterDef.Role.RIVAL:
			_talk_turf(character, character.line)
		CharacterDef.Role.LIEUTENANT:
			FamilyTalk.talk_to(character)
		CharacterDef.Role.HACKER:
			_talk_to_hacker(character)
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


static func _talk_to_hacker(hacker: CharacterDef) -> void:
	var run := GameState.run
	var choices: Array[DialogueChoice] = []
	var line := hacker.line
	var targets := Hacker.targets(run)
	if Hacker.hacked_this_phase(run):
		line = "One job a phase. The trace has to go cold first."
	elif targets.is_empty():
		line = "Nobody is trading anywhere else right now. Nothing to pull."
	else:
		for district in targets:
			choices.append(DialogueChoice.new(district.id, district.display_name, Hacker.can_hack(run)))
	choices.append(DialogueChoice.new(LEAVE, "Not now", true, true))
	var hint := "%s for every dealer's prices in one district, this phase only." % Format.money(Hacker.PRICE)
	GameOverlay.talk(hacker, line, choices, _on_hacker_choice, hint)


static func _on_hacker_choice(choice: StringName) -> void:
	if choice == LEAVE:
		GameOverlay.end_talk()
		return
	var dealers := GameState.buy_price_hack(choice)
	var reply := "No cash, no hack."
	if not dealers.is_empty():
		AudioService.play_sfx(Sfx.PRICE_HACK)
		var tips: Array[String] = []
		for dealer in dealers:
			var item := Market.best_sale(GameState.run, dealer)
			tips.append("%s pays %s for %s." % [dealer.display_name, Format.money(Market.sell_price(GameState.run, dealer, item)), item.display_name])
		reply = "%s The rest is on your phone." % " ".join(tips)
	var done: Array[DialogueChoice] = [_leave()]
	GameOverlay.say(reply, done, _end)


## The turf summary for the current district, spoken by the player when Vex is not around.
static func talk_about_turf() -> void:
	var run := GameState.run
	var district := Content.district(run.district_id)
	var share := Turf.share(run, run.district_id)
	var line := "I run %d%% of the corners in %s. Vex has the rest. I hold %d of %d districts." % [
		share, district.display_name if district != null else "town", Turf.held_count(run), Turf.CONTESTED.size(),
	]
	_talk_turf(Content.player(run.player_id), line)


static func _talk_turf(speaker: SpeakerDef, line: String) -> void:
	var run := GameState.run
	var choices: Array[DialogueChoice] = []
	var hint := "Selling here gains you ground. Held districts pay from %s each morning, more as you level them, keep muggers away and see fewer police." % Format.money(Turf.DAILY_CUT)
	if Turf.is_contested(run.district_id) and not run.vex_gone:
		var cost := Turf.muscle_cost(run)
		choices.append(DialogueChoice.new(MUSCLE, "Send muscle %s" % Format.money(cost), Turf.can_send_muscle(run)))
		hint = "Muscle adds %d%% here and %d heat. Once per phase. %s" % [Turf.MUSCLE_GAIN, Turf.MUSCLE_HEAT, hint]
		if run.muscle_stamp == Calendar.stamp(run):
			hint = "Your crew already went out this phase."
	choices.append(_leave())
	GameOverlay.talk(speaker, line, choices, _on_turf_choice, hint)


static func _on_turf_choice(choice: StringName) -> void:
	if choice != MUSCLE:
		GameOverlay.end_talk()
		return
	var reply := "Not enough cash to pay the crew."
	if GameState.send_muscle():
		AudioService.play_sfx(Sfx.TURF_MUSCLE)
		var run := GameState.run
		reply = "Your crew leans on the corners. You now run %d%% of them." % Turf.share(run, run.district_id)
	var done: Array[DialogueChoice] = [_leave()]
	GameOverlay.say(reply, done, _end, false)


static func _leave() -> DialogueChoice:
	return DialogueChoice.new(LEAVE, "Leave", true, true)


static func _end(_choice: StringName) -> void:
	GameOverlay.end_talk()
