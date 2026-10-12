class_name VoroninTalk

## What Voronin says when the player walks onto Pier 9.

const MET := "voronin_met"
const CALLED_RELIABLE := "voronin_reliable"
const MET_AS_PARTNER := "voronin_partner"
const KADE: StringName = &"kade"

const BANNED_LINE := "No work for you today. You know why."
const FIRST_LINE := "You want work? Crates go out, money comes back. Do not open them, and do not lose them."
const FIRST_LINE_KADE := "The courier who lost my crate. The Shark says you are his problem now. Good. Then lose his crates, not mine."
const RELIABLE_LINE := "Ten crates, ten deliveries. You know how many runners I have had who can count to ten?"
const PARTNER_LINE := "So now I pay you instead of the old man. Tell me why I should not just stop paying."
const LOST_CRATE_LINE := "The river does not give crates back. Neither do I give second chances quickly. Come back tomorrow."


## Marks one-time lines as heard.
static func greeting(run: RunState, voronin: CharacterDef) -> String:
	if Smuggling.is_banned(run):
		return BANNED_LINE
	if run.shark_bought and Story.mark(run, MET_AS_PARTNER):
		Story.mark(run, MET)
		return PARTNER_LINE
	if Story.mark(run, MET):
		return FIRST_LINE_KADE if run.player_id == KADE else FIRST_LINE
	if run.crate_streak >= Smuggling.RELIABLE_STREAK and Story.mark(run, CALLED_RELIABLE):
		return RELIABLE_LINE
	return voronin.line
