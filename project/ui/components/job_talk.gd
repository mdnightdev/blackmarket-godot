class_name JobTalk

## Phone pings for bar orders, family deliveries and crates: accept, decline or leave it, then the trip to the job.

const ACCEPT: StringName = &"accept"
const DECLINE: StringName = &"decline"
const LATER: StringName = &"later"

const REFUSALS := {
	JobPings.Result.GONE: "Too slow. That job is gone.",
	JobPings.Result.BUSY: "You already have one of mine running. Finish it first.",
	JobPings.Result.TOO_BIG: "Your bag can't take it. Make room and call me back.",
	JobPings.Result.BANNED: "Voronin won't work with you right now.",
}


static func open(ping_id: String) -> void:
	var ping := JobPings.find(GameState.run, ping_id)
	var sender := JobPings.sender(ping) if not ping.is_empty() else null
	if sender == null:
		return
	var hint := "Answer by the end of next phase or it goes to someone else."
	var twist := int(ping.twist)
	if JobPings.TWIST_HINTS.has(twist):
		hint = JobPings.TWIST_HINTS[twist]
	var choices: Array[DialogueChoice] = [
		DialogueChoice.new(ACCEPT, "Accept"),
		DialogueChoice.new(DECLINE, "Decline"),
		DialogueChoice.new(LATER, "Later", true, true),
	]
	GameOverlay.talk(sender, JobPings.pitch(ping), choices, _on_choice.bind(ping_id), hint)


static func _on_choice(choice: StringName, ping_id: String) -> void:
	match choice:
		ACCEPT:
			_accept(ping_id)
		DECLINE:
			GameState.decline_ping(ping_id)
			GameOverlay.end_talk()
		_:
			GameOverlay.end_talk()


static func _accept(ping_id: String) -> void:
	var ping := JobPings.find(GameState.run, ping_id)
	var destination := JobPings.destination(ping) if not ping.is_empty() else null
	var result := GameState.accept_ping(ping_id)
	if result != JobPings.Result.OK:
		GameOverlay.say(REFUSALS[result], TripTalk.continue_only(), TripTalk.end)
		return
	AudioService.play_sfx(Sfx.FAVOUR_TAKEN)
	if destination == null or destination.id == GameState.run.district_id:
		GameOverlay.end_talk()
		return
	TripTalk.offer(destination)
