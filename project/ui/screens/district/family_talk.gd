class_name FamilyTalk

## Conversations with the triad lieutenants: the favour board, deliveries and standing.

const DELIVER: StringName = &"deliver"
const LEAVE: StringName = &"leave"
const HOSTILE_LINE := "You have some nerve showing your face here. If you want to make it right, the family has work."
const STRANGER_LINE := "The family does not give work to a stranger still squabbling over Old Market. Settle your own street first."


static func talk_to(lieutenant: CharacterDef) -> void:
	var family := Families.family_of(lieutenant)
	if family == null:
		var choices: Array[DialogueChoice] = [_leave()]
		GameOverlay.talk(lieutenant, lieutenant.line, choices, _end, lieutenant.blurb)
		return
	var favour := Favours.active_for(GameState.run, family.id)
	if favour.is_empty():
		_show_board(lieutenant, family)
	else:
		_ask_for_delivery(lieutenant, family, favour)


static func _show_board(lieutenant: CharacterDef, family: FamilyDef) -> void:
	var run := GameState.run
	var hostile := Families.tier(run, family.id) == Families.Tier.HOSTILE
	var line := HOSTILE_LINE if hostile else lieutenant.line
	var offers := Favours.board(run, family)
	var choices: Array[DialogueChoice] = []
	for index in offers.size():
		var offer := offers[index]
		var possible := run.cash >= int(offer.price) if int(offer.kind) == Favours.Kind.TRIBUTE else Orders.fits_in_bag(run, offer)
		choices.append(DialogueChoice.new(StringName(str(index)), _offer_label(offer), possible))
	if not Campaign.is_act_two(run):
		line = STRANGER_LINE
	elif offers.is_empty():
		line = "Nothing more for you today. Come back tomorrow."
	choices.append(_leave())
	GameOverlay.talk(lieutenant, line, choices, _on_board_choice.bind(family, offers), _standing_hint(family))


static func _on_board_choice(choice: StringName, family: FamilyDef, offers: Array[Dictionary]) -> void:
	if choice == LEAVE:
		GameOverlay.end_talk()
		return
	var offer := offers[int(String(choice))]
	var reply := "That job is gone."
	match GameState.accept_favour(offer):
		Favours.Result.OK:
			if int(offer.kind) == Favours.Kind.TRIBUTE:
				AudioService.play_sfx(Sfx.COINS_OUT)
				reply = "The family thanks you. Your standing is now %s." % _tier_text(family)
			else:
				AudioService.play_sfx(Sfx.FAVOUR_TAKEN)
				var item := Content.item(StringName(offer.item))
				reply = "%d %s, in my hand by %s. Do not make me come looking." % [int(offer.quantity), item.display_name, Calendar.describe(int(offer.due))]
		Favours.Result.NOT_ENOUGH_CASH:
			reply = "Come back when your pockets match your promises."
		Favours.Result.BUSY:
			reply = "Finish the job you already owe me first."
		Favours.Result.TOO_BIG:
			reply = "You could never carry that much. Get a bigger bag."
	var done: Array[DialogueChoice] = [_leave()]
	GameOverlay.say(reply, done, _end)


static func _ask_for_delivery(lieutenant: CharacterDef, family: FamilyDef, favour: Dictionary) -> void:
	var run := GameState.run
	var item := Content.item(StringName(favour.item))
	var quantity := int(favour.quantity)
	var line := "You owe the family %d %s by %s." % [quantity, item.display_name, Calendar.describe(int(favour.due))]
	var choices: Array[DialogueChoice] = [
		DialogueChoice.new(DELIVER, "Hand over %d %s" % [quantity, item.display_name], Favours.can_deliver(run, favour)),
		_leave(),
	]
	var held := mini(Inventory.count(run, item.id), quantity)
	var hint := "You have %d of %d. Pays %s. %s" % [held, quantity, Format.money(Favours.total(favour)), _standing_hint(family)]
	GameOverlay.talk(lieutenant, line, choices, _on_delivery_choice.bind(family, favour), hint)


static func _on_delivery_choice(choice: StringName, family: FamilyDef, favour: Dictionary) -> void:
	if choice != DELIVER:
		GameOverlay.end_talk()
		return
	var reply := "That is not what we agreed."
	if GameState.deliver_favour(favour):
		AudioService.play_sfx(Sfx.FAVOUR_DONE)
		reply = "The family remembers who helps it. %s, as agreed. Your standing is now %s." % [Format.money(Favours.total(favour)), _tier_text(family)]
	var done: Array[DialogueChoice] = [_leave()]
	GameOverlay.say(reply, done, _end)


static func _offer_label(offer: Dictionary) -> String:
	if int(offer.kind) == Favours.Kind.TRIBUTE:
		return "Pay %s tribute" % Format.money(int(offer.price))
	var item := Content.item(StringName(offer.item))
	return "%d %s by %s for %s" % [int(offer.quantity), item.display_name, Calendar.describe(int(offer.due)), Format.money(Favours.total(offer))]


static func _standing_hint(family: FamilyDef) -> String:
	var rival := Content.family(family.rival)
	var rival_text := " and -%d with the %s" % [Favours.RIVAL_LOSS, rival.english_name] if rival != null else ""
	return "%s. Standing: %s. A favour done gives +%d%s. A missed one costs -%d." % [
		family.full_name(), _tier_text(family), Favours.DONE_GAIN, rival_text, Favours.MISSED_LOSS,
	]


static func _tier_text(family: FamilyDef) -> String:
	return Families.tier_name(Families.tier(GameState.run, family.id))


static func _leave() -> DialogueChoice:
	return DialogueChoice.new(LEAVE, "Leave", true, true)


static func _end(_choice: StringName) -> void:
	GameOverlay.end_talk()
