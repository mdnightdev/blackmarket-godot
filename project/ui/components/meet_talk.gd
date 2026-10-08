class_name MeetTalk

## The client offers a choice: the player travels to them for the full price, or they come part of the way for less.
## A meeting right here hands over at once through on_here. A spot further on books the trip there.

const TRAVEL: StringName = &"travel"
const LATER: StringName = &"later"
const SPOT_PREFIX := "meet:"


## full_total is what the order pays at the client's door, meeting_total what it pays on the way.
## line replaces the default pitch.
static func open(client: SpeakerDef, order_id: String, client_district: DistrictDef, full_total: int, meeting_total: int, on_here: Callable, line := "") -> void:
	var run := GameState.run
	var choices: Array[DialogueChoice] = [DialogueChoice.new(TRAVEL, "Go to %s" % client_district.display_name)]
	for spot in Meetings.spots(run, client_district.id):
		var label := "Meet here" if spot == run.district_id else "Meet in %s" % Content.district(spot).display_name
		choices.append(DialogueChoice.new(StringName(SPOT_PREFIX + spot), label))
	choices.append(DialogueChoice.new(LATER, "Later", true, true))
	var pitch := line if not line.is_empty() else "Bring it to me in %s and it is %s. If I come out to you, %s." % [
		client_district.display_name, Format.money(full_total), Format.money(meeting_total),
	]
	var hint := "Meeting halfway pays %d%%. Some buyers use a meeting to rip you off." % roundi(Meetings.PAY_SHARE * 100)
	GameOverlay.talk(client, pitch, choices, _on_choice.bind(order_id, client_district.id, on_here), hint)


static func _on_choice(choice: StringName, order_id: String, client_district: StringName, on_here: Callable) -> void:
	GameOverlay.end_talk()
	if choice == LATER:
		return
	var destination := client_district
	if String(choice).begins_with(SPOT_PREFIX):
		destination = StringName(String(choice).trim_prefix(SPOT_PREFIX))
		if not GameState.agree_meeting(order_id, destination):
			return
	if destination == GameState.run.district_id:
		on_here.call()
		return
	GameState.travelling_to = destination
	SceneRouter.go_to(SceneRouter.MAP_SCREEN)
