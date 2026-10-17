class_name StreetTalk

## Conversations with the characters the player meets in a district.

const REPAY: StringName = &"repay"
const BORROW: StringName = &"borrow"
const PAY: StringName = &"pay"
const BUY_OUT: StringName = &"buy_out"
const DEAL: StringName = &"deal"
const LEAVE: StringName = &"leave"
const RAMOS: StringName = &"officer"
const LENDING_HINT := "Due back in %d days. Street dealers skip out 1 in 4, middle class 1 in 8, wealthy 1 in 20. The Shark collects half of a skipped loan."


static func talk_to(character: CharacterDef) -> void:
	match character.role:
		CharacterDef.Role.LENDER:
			_talk_to_lender(character)
		CharacterDef.Role.INFORMANT:
			_talk_to_informant(character)
		CharacterDef.Role.RIVAL:
			if character.id == Loan.VEX_LENDER:
				if Campaign.is_act_two(GameState.run):
					VexTalk.play_enforcer(character)
				else:
					VexTalk.play(character)
			else:
				_talk_turf(character, character.line)
		CharacterDef.Role.POLICE:
			_talk_to_police(character)
		CharacterDef.Role.LIEUTENANT:
			FamilyTalk.talk_to(character)
		CharacterDef.Role.HACKER:
			_talk_to_hacker(character)
		_:
			var choices: Array[DialogueChoice] = [_leave()]
			GameOverlay.talk(character, character.line, choices, _end, character.blurb)


static func _talk_to_lender(shark: CharacterDef) -> void:
	var run := GameState.run
	if run.shark_bought:
		_talk_lending(shark)
		return
	if Loan.is_with_vex(run):
		var leave: Array[DialogueChoice] = [_leave()]
		GameOverlay.talk(shark, "I am retired. Your debt is Vex's business now. Pay her, not me.", leave, _end)
		return
	var due_day := run.next_due_day - 1
	var line: String
	var choices: Array[DialogueChoice] = []
	if run.debt <= 0:
		line = "You're clear with me. Need another loan? My rates are fair. Mostly."
	elif Loan.amount_due(run) > 0:
		line = "You owe me %s. I want %s by the end of day %d." % [Format.money(run.debt), Format.money(Loan.amount_due(run)), due_day]
	else:
		line = "You owe me %s. This week is covered. Next payment is set on day %d." % [Format.money(run.debt), due_day]
	if not run.career and run.missed_weeks > 0:
		line += " Missed %d of %d in a row. Then I sell your debt to someone less patient." % [run.missed_weeks, Loan.MAX_MISSED_WEEKS]
	if run.career:
		choices.append(DialogueChoice.new(BORROW, "Borrow or repay"))
	elif run.debt > 0:
		choices.append(DialogueChoice.new(REPAY, "Repay"))
	if Lending.can_buy_out(run):
		line += " Or buy me out. %s and the whole book is yours." % Format.money(Lending.BUYOUT_PRICE)
		choices.append(DialogueChoice.new(BUY_OUT, "Buy him out (%s)" % Format.money(Lending.BUYOUT_PRICE), run.cash >= Lending.BUYOUT_PRICE))
	choices.append(_leave())
	var hint := "His trust in you: %s." % SharkTrust.level_name(run) if not run.career else ""
	GameOverlay.talk(shark, line, choices, _on_lender_choice.bind(shark), hint)


static func _on_lender_choice(choice: StringName, shark: CharacterDef) -> void:
	if choice == BUY_OUT:
		var choices: Array[DialogueChoice] = [DialogueChoice.new(DEAL, "Deal"), DialogueChoice.new(LEAVE, "Not now", true, true)]
		var line := "%s and I retire from the desk. I'll walk a step behind you, no wage. Dealers come to you for money after that." % Format.money(Lending.BUYOUT_PRICE)
		GameOverlay.talk(shark, line, choices, _on_buy_out_choice.bind(shark), "Borrowing ends. Lending to dealers opens here.")
		return
	GameOverlay.end_talk()
	if choice == REPAY:
		GameOverlay.open_loan(LoanSheet.Mode.REPAY)
	elif choice == BORROW:
		GameOverlay.open_loan(LoanSheet.Mode.REPAY if Loan.amount_due(GameState.run) > 0 else LoanSheet.Mode.BORROW)


static func _on_buy_out_choice(choice: StringName, shark: CharacterDef) -> void:
	if choice != DEAL:
		GameOverlay.end_talk()
		return
	if not GameState.buy_out_shark():
		GameOverlay.say("Come back with the money.", TripTalk.continue_only(), TripTalk.end)
		return
	AudioService.play_sfx(Sfx.FAVOUR_TAKEN)
	var ramos_pages := Ramos.join_player(GameState.run)
	GameState.save_run()
	var then := func(_choice: StringName) -> void: _show_pages(ramos_pages, 0, _talk_lending.bind(shark))
	GameOverlay.talk(shark, "Pleasure doing business, boss. The book is yours. Ramos comes with it.", TripTalk.continue_only(), then)


static func _show_pages(pages: Array[Dictionary], index: int, then: Callable) -> void:
	if index >= pages.size():
		then.call()
		return
	var page := pages[index]
	var speaker := Content.speaker(StringName(str(page.speaker)))
	GameOverlay.talk(speaker, str(page.line), TripTalk.continue_only(), func(_choice: StringName) -> void: _show_pages(pages, index + 1, then))


static func _talk_lending(shark: CharacterDef) -> void:
	var run := GameState.run
	var requests := Lending.requests(run)
	var line := "Your desk, boss. Nobody wants money today."
	if not requests.is_empty():
		line = "Your desk, boss. %d dealers want money today." % requests.size()
	if not run.dealer_loans.is_empty():
		line += " %s is out on the street right now." % Format.money(Lending.outstanding(run))
	var choices: Array[DialogueChoice] = []
	for request in requests:
		var dealer := Content.dealer(StringName(str(request.dealer)))
		var amount := int(request.amount)
		var label := "Lend %s %s, back %s" % [dealer.display_name, Format.money(amount), Format.money(Lending.repayment(dealer, amount))]
		choices.append(DialogueChoice.new(StringName(str(request.id)), label, run.cash >= amount))
	choices.append(_leave())
	GameOverlay.talk(shark, line, choices, _on_lending_choice.bind(shark), LENDING_HINT % Lending.TERM_DAYS)


static func _on_lending_choice(choice: StringName, shark: CharacterDef) -> void:
	if choice == LEAVE:
		GameOverlay.end_talk()
		return
	match GameState.lend_to_dealer(String(choice)):
		Lending.Result.OK:
			AudioService.play_sfx(Sfx.FAVOUR_TAKEN)
			_talk_lending(shark)
		Lending.Result.NOT_ENOUGH_CASH:
			GameOverlay.say("You don't have that much on you.", TripTalk.continue_only(), TripTalk.end)
		_:
			GameOverlay.say("That one already found the money somewhere else.", TripTalk.continue_only(), TripTalk.end)


static func _talk_to_police(officer: CharacterDef) -> void:
	var run := GameState.run
	var line := officer.line
	if officer.id == Moreau.ID:
		line = Moreau.line(run)
		GameState.save_run()
	elif officer.id == RAMOS:
		line = _ramos_line(run, officer)
	var choices: Array[DialogueChoice] = [_leave()]
	GameOverlay.talk(officer, line, choices, _end, officer.blurb)


## Ramos works for whoever holds the Shark's book.
static func _ramos_line(run: RunState, ramos: CharacterDef) -> String:
	match Ramos.book(run):
		Ramos.Book.NOBODY:
			return "Nobody holds the book now, so anybody can pay me. Envelope first, amigo."
		Ramos.Book.PLAYER:
			if Ramos.is_lying_low(run):
				return "Not here. They're still counting who knew. I'll call you when it's quiet."
			return "Your book, your envelope. Brandt sneezes, you hear it first, amigo."
		Ramos.Book.VEX:
			return "New boss, same envelope. Nothing personal, amigo."
	return ramos.line


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


## The turf summary for the current district, spoken by the player when the gang boss is not around.
static func talk_about_turf() -> void:
	var run := GameState.run
	var district := Content.district(run.district_id)
	var gang := Gangs.owner(run.district_id)
	var line := "I hold %d of the %d corners in %s. %s has the rest. I hold %d of %d districts." % [
		Corners.held_count(run, run.district_id), Corners.of(run.district_id).size(),
		district.display_name if district != null else "town", gang.display_name if gang != null else "Nobody",
		Turf.held_count(run), Turf.contested().size(),
	]
	_talk_turf(Content.player(run.player_id), line)


static func _talk_turf(speaker: SpeakerDef, line: String) -> void:
	var run := GameState.run
	var choices: Array[DialogueChoice] = [_leave()]
	var hint := "Corners are taken by force, never sold into. Scout one first, then hit it. Held corners pay rent and protection every morning."
	if run.district_id != Corners.HOME and not Campaign.is_act_two(run):
		hint = "The fight for these corners waits until Old Market is yours."
	GameOverlay.talk(speaker, line, choices, _end, hint)


static func _leave() -> DialogueChoice:
	return DialogueChoice.new(LEAVE, "Leave", true, true)


static func _end(_choice: StringName) -> void:
	GameOverlay.end_talk()
