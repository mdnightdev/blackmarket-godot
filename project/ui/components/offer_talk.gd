class_name OfferTalk

## Errand offers from the Shark, or from Vex once she holds the debt: accept, decline or leave it on the phone,
## then the trip to start the job.

const ACCEPT: StringName = &"accept"
const DECLINE: StringName = &"decline"
const LATER: StringName = &"later"

const SHORT_NOTICE := "Tonight. I know it is short notice. That is why I asked you. "
const VEX_TERMS := "Do it, and I don't send anyone to your door. That's the pay."
const SHARK_DECLINED := "I see. Then I will remember that I asked."
const VEX_DECLINED := "Wrong answer. Stay home tonight and see who knocks."


static func open(offer_id: String) -> void:
	var run := GameState.run
	var offer := Errands.find_offer(run, offer_id)
	var sender := Content.character(StringName(str(offer.get("sender", Errands.SENDER))))
	if offer.is_empty() or sender == null:
		return
	var hint := "%d phases to finish once you take it." % int(offer.lead)
	if not Errands.is_from_shark(offer):
		hint += " No pay. Say no and her crew pays you a visit."
	if not Errands.can_accept(run):
		hint = "You already run %d jobs for %s. Finish one first." % [Errands.MAX_ACTIVE, Errands.creditor(offer)]
	var choices: Array[DialogueChoice] = [
		DialogueChoice.new(ACCEPT, "Accept", Errands.can_accept(run)),
		DialogueChoice.new(DECLINE, "Decline"),
		DialogueChoice.new(LATER, "Later", true, true),
	]
	GameOverlay.talk(sender, _pitch(offer), choices, _on_offer_choice.bind(offer_id), hint)


static func _pitch(offer: Dictionary) -> String:
	if not Errands.is_from_shark(offer):
		return _unpaid_pitch(offer)
	var pitch := SHORT_NOTICE if int(offer.lead) == Errands.MIN_LEAD_PHASES else ""
	return pitch + _shark_job(offer)


static func _shark_job(offer: Dictionary) -> String:
	var pay := Format.money(int(offer.pay))
	var pickup := _place_name(offer.pickup_district)
	var drop := _place_name(offer.drop_district)
	if str(offer.kind) == Errands.COLLECTION:
		return "%s in %s is late with %s. Do not hurt him. Just stand where he can see you. Your cut is %s." % [
			str(offer.debtor), _place_name(offer.district), Format.money(int(offer.owed)), pay,
		]
	match str(offer.get("flavor", Errands.PACKAGE)):
		Errands.ENVELOPE:
			return "Officer Ramos is a friend. Friends get envelopes. Pick it up in %s and take it to him in %s, sealed. %s when it lands." % [pickup, drop, pay]
		Errands.PIER:
			return "Voronin has something of mine. Collect it at the pier before the tide and bring it to %s. %s when it lands." % [drop, pay]
	return "I have a package waiting in %s. Take it to %s. %s when it lands." % [pickup, drop, pay]


static func _unpaid_pitch(offer: Dictionary) -> String:
	var job := "Package in %s. Take it to %s." % [_place_name(offer.pickup_district), _place_name(offer.drop_district)]
	if str(offer.kind) == Errands.COLLECTION:
		job = "%s owes me %s. Go to %s and get it." % [str(offer.debtor), Format.money(int(offer.owed)), _place_name(offer.district)]
	return "%s %s" % [job, VEX_TERMS]


static func _on_offer_choice(choice: StringName, offer_id: String) -> void:
	match choice:
		ACCEPT:
			_accept(offer_id)
		DECLINE:
			var offer := Errands.find_offer(GameState.run, offer_id)
			var reply := SHARK_DECLINED if Errands.is_from_shark(offer) else VEX_DECLINED
			GameState.decline_offer(offer_id)
			var sender := Content.character(StringName(str(offer.get("sender", Errands.SENDER))))
			GameOverlay.talk(sender, reply, TripTalk.continue_only(), TripTalk.end)
		_:
			GameOverlay.end_talk()


static func _accept(offer_id: String) -> void:
	if not GameState.accept_offer(offer_id):
		GameOverlay.say("Too slow. That job is gone.", TripTalk.continue_only(), TripTalk.end)
		return
	AudioService.play_sfx(Sfx.FAVOUR_TAKEN)
	var errand := Errands.find(GameState.run, offer_id)
	var destination: DistrictDef = null
	if not errand.is_empty():
		destination = Errands.next_stop(GameState.run, errand)
	if destination == null:
		GameOverlay.end_talk()
		return
	TripTalk.offer(destination)


static func _place_name(district_id: Variant) -> String:
	var district := Content.district(StringName(str(district_id)))
	return district.display_name if district != null else str(district_id)
