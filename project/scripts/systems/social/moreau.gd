class_name Moreau

## Detective Moreau suspects the player but knows nothing in Act 1. She watches, pays more attention once the
## player buys the Shark out, and starts recording when Vex falls. Her file itself opens in Act 2.

enum Stage { WATCHING, ATTENTION, RECORDING }

const ID: StringName = &"detective"
## How much more often she walks the districts where the player holds corners once she pays attention.
const ATTENTION_WEIGHT := 3.0
const WATCHLIST := "moreau_watchlist"
const BUYOUT_REMARK := "moreau_buyout_remark"

const PASSING_LINES: Array[String] = [
	"New face. I remember new faces.",
	"Nice bag. Heavy, for someone your size.",
]
const BUYOUT_LINE := "The Shark sold his chair. To you? Interesting choice for someone who sells phones out of a bag."
const AROUND_LINE := "I'll be around. I'm always around."


static func stage(run: RunState) -> Stage:
	if Story.has(run, WATCHLIST):
		return Stage.RECORDING
	if run.shark_bought:
		return Stage.ATTENTION
	return Stage.WATCHING


static func watches_player(run: RunState, character: CharacterDef) -> bool:
	return character.id == ID and stage(run) != Stage.WATCHING


## What she says when the player walks up to her. Marks one-time remarks as heard.
static func line(run: RunState) -> String:
	if stage(run) == Stage.WATCHING:
		return PASSING_LINES[Calendar.stamp(run) % PASSING_LINES.size()]
	if run.shark_bought and Story.mark(run, BUYOUT_REMARK):
		return BUYOUT_LINE
	return AROUND_LINE
