class_name OfferTalk

## The Shark's errand offers: accept, decline or leave it on the phone, then the trip to start the job.

const ACCEPT: StringName = &"accept"
const DECLINE: StringName = &"decline"
const LATER: StringName = &"later"
const TRAVEL: StringName = &"travel"
const CONTINUE: StringName = &"continue"


static func open(offer_id: String) -> void:
	var run := GameState.run
	var offer := Errands.find_offer(run, offer_id)
	var sender := Content.character(StringName(str(offer.get("sender", Errands.SENDER))))
	if offer.is_empty() or sender == null:
		return
	var hint := "%d phases to finish once you take it." % int(offer.lead)
	if not Errands.can_accept(run):
		hint = "You already run %d jobs for the Shark. Finish one first." % Errands.MAX_ACTIVE
	var choices: Array[DialogueChoice] = [
		DialogueChoice.new(ACCEPT, "Accept", Errands.can_accept(run)),
		DialogueChoice.new(DECLINE, "Decline"),
		DialogueChoice.new(LATER, "Later", true, true),
	]
	GameOverlay.talk(sender, _pitch(offer), choices, _on_offer_choice.bind(offer_id), hint)


static func _pitch(offer: Dictionary) -> String:
	var pay := Format.money(int(offer.pay))
	if str(offer.kind) == Errands.COLLECTION:
		return "%s owes me %s. Go to %s and get it. Your cut is %s." % [
			str(offer.debtor), Format.money(int(offer.owed)), _place_name(offer.district), pay,
		]
	return "I have a package waiting in %s. Take it to %s. %s when it lands." % [
		_place_name(offer.pickup_district), _place_name(offer.drop_district), pay,
	]


static func _on_offer_choice(choice: StringName, offer_id: String) -> void:
	match choice:
		ACCEPT:
			_accept(offer_id)
		DECLINE:
			GameState.decline_offer(offer_id)
			GameOverlay.end_talk()
		_:
			GameOverlay.end_talk()


static func _accept(offer_id: String) -> void:
	if not GameState.accept_offer(offer_id):
		GameOverlay.say("Too slow. That job is gone.", _continue_only(), _end)
		return
	AudioService.play_sfx(Sfx.FAVOUR_TAKEN)
	var errand := Errands.find(GameState.run, offer_id)
	var destination: DistrictDef = null
	if not errand.is_empty():
		destination = Errands.next_stop(GameState.run, errand)
	if destination == null:
		GameOverlay.end_talk()
		return
	_offer_trip(destination)


## Asks to travel now. A trip that cannot go ahead says why, and the job keeps running either way.
static func _offer_trip(destination: DistrictDef) -> void:
	var run := GameState.run
	var player := Content.player(run.player_id)
	var fare := Format.money(Travel.fare(run, destination))
	match Travel.check(run, destination):
		Travel.Check.OK:
			var choices: Array[DialogueChoice] = [
				DialogueChoice.new(TRAVEL, "Travel"),
				DialogueChoice.new(LATER, "Later", true, true),
			]
			var line := "Head to %s now?" % destination.display_name
			GameOverlay.talk(player, line, choices, _on_trip_choice.bind(destination.id), "Fare %s" % fare)
		Travel.Check.NOT_ENOUGH_CASH:
			var line := "The fare to %s is %s and I am short. I will go when I have it." % [destination.display_name, fare]
			GameOverlay.talk(player, line, _continue_only(), _end, "The job stays in your Jobs tab.")
		Travel.Check.LOCKED:
			var line := "%s is closed to me for now." % destination.display_name
			GameOverlay.talk(player, line, _continue_only(), _end, Travel.lock_reason(run, destination))
		_:
			GameOverlay.end_talk()


static func _on_trip_choice(choice: StringName, district_id: StringName) -> void:
	GameOverlay.end_talk()
	if choice != TRAVEL:
		return
	GameState.travelling_to = district_id
	SceneRouter.go_to(SceneRouter.MAP_SCREEN)


static func _continue_only() -> Array[DialogueChoice]:
	var choices: Array[DialogueChoice] = [DialogueChoice.new(CONTINUE, "Continue", true, true)]
	return choices


static func _end(_choice: StringName) -> void:
	GameOverlay.end_talk()


static func _place_name(district_id: Variant) -> String:
	var district := Content.district(StringName(str(district_id)))
	return district.display_name if district != null else str(district_id)
