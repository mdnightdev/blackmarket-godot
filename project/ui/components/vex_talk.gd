class_name VexTalk

## Vex while she runs Old Market in Act 1. One line per meeting, picked by what the player has done. No muscle yet.

const NEXT: StringName = &"next"
const MET := "vex_met"
const HEARD_EARLY_PAYMENT := "vex_early_payment"
## From this street rank on the player sells enough to bother her.
const COMFORTABLE_RANK := 3

const FIRST_LINES: Array[String] = [
	"New face, full bag. In my market. You know what that means?",
	"It means you pay me, or you sell somewhere I can't see you.",
]
const EARLY_PAYMENT_LINE := "The Shark likes you. The Shark likes a lot of people. Until he doesn't."
const COMFORTABLE_LINE := "You're getting comfortable. Comfortable people get cut."
const SMALL_LINE := "Cute. Keep it small and I'll pretend I didn't see."
const HINT := "Vex runs Old Market and taxes every corner in it."


## What she says this time. Marks one-time lines as heard.
static func lines(run: RunState) -> Array[String]:
	if Story.mark(run, MET):
		return FIRST_LINES.duplicate()
	if run.shark_letter_sent and Story.mark(run, HEARD_EARLY_PAYMENT):
		return [EARLY_PAYMENT_LINE]
	if StreetCred.rank(run) >= COMFORTABLE_RANK:
		return [COMFORTABLE_LINE]
	return [SMALL_LINE]


static func play(vex: CharacterDef) -> void:
	var pages := lines(GameState.run)
	GameState.save_run()
	_show(vex, pages, 0)


static func _show(vex: CharacterDef, pages: Array[String], index: int) -> void:
	if index >= pages.size():
		GameOverlay.end_talk()
		return
	var choices: Array[DialogueChoice] = [DialogueChoice.new(NEXT, "Next", true, false, true)]
	var hint := HINT if index == pages.size() - 1 else ""
	GameOverlay.talk(vex, pages[index], choices, func(_choice: StringName) -> void: _show(vex, pages, index + 1), hint)
