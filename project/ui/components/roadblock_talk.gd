class_name RoadblockTalk

## Asks what to do about a roadblock on the way into a district while carrying a crate: risk the search,
## lie low until it lifts or take a detour. on_travel is called with the district to drive to and whether the
## player is pushing through the roadblock.

const PUSH: StringName = &"push"
const WAIT: StringName = &"wait"
const DETOUR: StringName = &"detour"
const BACK: StringName = &"back"


static func open(destination: DistrictDef, on_travel: Callable) -> void:
	var run := GameState.run
	var player := Content.player(run.player_id)
	var detour := Roadblocks.detour(run, destination)
	var choices: Array[DialogueChoice] = [
		DialogueChoice.new(PUSH, "Risk the search (%s)" % Odds.reading(1.0 - Roadblocks.PUSH_RISK)),
		DialogueChoice.new(WAIT, "Lie low until it lifts"),
	]
	if not detour.is_empty():
		choices.append(DialogueChoice.new(DETOUR, _detour_label(detour)))
	choices.append(DialogueChoice.new(BACK, "Not now", true, true))
	var line := "Police roadblock on the road into %s. They are opening trunks." % destination.display_name
	var lifts := "It lifts at %s." % Roadblocks.clears_at(run, destination.id) if Routes.has_recon(run) \
		else "Nobody knows how long it stays up."
	var due := "The crate is due by %s." % Calendar.describe(int(run.crate.due)).to_lower()
	GameOverlay.talk(player, line, choices, _on_choice.bind(destination, detour, on_travel), "%s %s" % [lifts, due])


static func _on_choice(choice: StringName, destination: DistrictDef, detour: Array[StringName], on_travel: Callable) -> void:
	GameOverlay.end_talk()
	match choice:
		PUSH:
			on_travel.call(destination, true)
		WAIT:
			if GameState.wait_out_roadblock(destination.id) and not Encounters.has_pending(GameState.run):
				on_travel.call(destination, false)
		DETOUR:
			if Smuggling.reroute(GameState.run, detour):
				on_travel.call(Content.district(detour[0]), false)


static func _detour_label(stops: Array[StringName]) -> String:
	if stops.size() == 1:
		return "Take the direct road to %s" % Content.district(stops[0]).display_name
	var names: PackedStringArray = []
	for stop: StringName in stops.slice(0, -1):
		names.append(Content.district(stop).display_name)
	return "Detour via %s" % ", ".join(names)
