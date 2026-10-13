class_name AmbushTalk

## A rival's strike once the countdown is answered: who goes when the player mobilises, the fight, and what 午夜兔子 says
## after. The odds are never shown.

const NEXT: StringName = &"next"
const VETERAN_SKILL := "War veteran"
const AFTER_LINES := {
	"won_delegated": "They came for the corner. They're still lying on it.",
	"won_mobilised": "You held it. Not how I'd have done it, but you held it.",
	"lost_delegated": "I lost it. They'll pay for that corner twice.",
	"lost_mobilised": "We lost it. Next time let me run it.",
}


static func answer(choice: StringName) -> void:
	if choice == RivalStrike.DELEGATE:
		_delegate()
	else:
		_plan()


static func _plan() -> void:
	var corner := Corners.find(StringName(str(GameState.run.pending_encounter.get("corner", ""))))
	var title := "Hold %s" % corner.display_name if corner != null else "Hold the corner"
	var message := "Pick who goes. Fewer men risk fewer lives, and lose more often."
	var rabbit := Content.speaker(RivalStrike.RABBIT)
	GameOverlay.pick_crew(title, message, "Send %d", "Let %s run it" % rabbit.display_name, _fight.bind(false), _delegate)


static func _delegate() -> void:
	_fight(RivalStrike.rabbit_deployment(GameState.run), true)


static func _fight(deployment: Dictionary, delegated: bool) -> void:
	var run := GameState.run
	var carried := Army.issue(run, deployment)
	var result := GameState.defend_ambush(deployment, delegated)
	if result.is_empty():
		GameOverlay.end_talk()
		return
	var corner := Corners.find(StringName(str(result.corner)))
	var teams := WarTalk.sides(result, corner, carried)
	if delegated and not teams[0].has_skill():
		var rabbit := Content.speaker(RivalStrike.RABBIT)
		teams[0].skill_name = VETERAN_SKILL
		teams[0].skill_owner = rabbit.display_name
		teams[0].skill_portrait = rabbit.portrait
	var line := "%s HOLDS" % corner.display_name.to_upper() if bool(result.won) else "%s IS LOST" % corner.display_name.to_upper()
	GameOverlay.play_battle(teams[0], teams[1], line, hash(result), func() -> void: _aftermath(result))


static func _aftermath(result: Dictionary) -> void:
	var key := "%s_%s" % ["won" if bool(result.won) else "lost", "delegated" if bool(result.delegated) else "mobilised"]
	var next: Array[DialogueChoice] = [DialogueChoice.new(NEXT, "Next", true, false, true)]
	GameOverlay.talk(Content.speaker(RivalStrike.RABBIT), str(AFTER_LINES[key]), next, func(_choice: StringName) -> void: GameOverlay.end_talk(), WarTalk.report(result))
