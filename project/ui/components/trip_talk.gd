class_name TripTalk

## Asks the player to travel somewhere now. Travel books the trip and opens the map, where it plays out and
## charges the fare. A trip that cannot go ahead says why, and the job keeps running either way.

const TRAVEL: StringName = &"travel"
const LATER: StringName = &"later"
const CONTINUE: StringName = &"continue"


## line replaces the default "Head to <district> now?" question.
static func offer(destination: DistrictDef, line := "") -> void:
	var run := GameState.run
	var player := Content.player(run.player_id)
	var fare := Format.money(Travel.fare(run, destination))
	match Travel.check(run, destination):
		Travel.Check.OK:
			var choices: Array[DialogueChoice] = [
				DialogueChoice.new(TRAVEL, "Travel"),
				DialogueChoice.new(LATER, "Later", true, true),
			]
			var question := line if not line.is_empty() else "Head to %s now?" % destination.display_name
			GameOverlay.talk(player, question, choices, _on_trip_choice.bind(destination.id), "Fare %s" % fare)
		Travel.Check.NOT_ENOUGH_CASH:
			var short_line := "The fare to %s is %s and I am short. I will go when I have it." % [destination.display_name, fare]
			GameOverlay.talk(player, short_line, continue_only(), end, "The job stays in your Jobs tab.")
		Travel.Check.LOCKED:
			var locked_line := "%s is closed to me for now." % destination.display_name
			GameOverlay.talk(player, locked_line, continue_only(), end, Travel.lock_reason(run, destination))
		_:
			GameOverlay.end_talk()


static func continue_only() -> Array[DialogueChoice]:
	var choices: Array[DialogueChoice] = [DialogueChoice.new(CONTINUE, "Continue", true, true)]
	return choices


static func end(_choice: StringName) -> void:
	GameOverlay.end_talk()


static func _on_trip_choice(choice: StringName, district_id: StringName) -> void:
	GameOverlay.end_talk()
	if choice != TRAVEL:
		return
	GameState.travelling_to = district_id
	SceneRouter.go_to(SceneRouter.MAP_SCREEN)
