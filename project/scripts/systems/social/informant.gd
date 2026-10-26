class_name Informant

const TIP_PRICE := 150


static func can_afford_tip(run: RunState) -> bool:
	return run.cash >= TIP_PRICE


## Police character to the district they patrol next phase.
static func patrols_next_phase(run: RunState) -> Dictionary:
	var next_stamp := Calendar.stamp(run) + 1
	var patrols := {}
	for character in Content.characters():
		if character.role == CharacterDef.Role.POLICE:
			patrols[character] = Roster.character_location(run, character, next_stamp)
	return patrols


## Charges for the tip. Returns the patrols, or an empty dictionary when the player cannot pay.
static func buy_tip(run: RunState) -> Dictionary:
	if not can_afford_tip(run):
		return {}
	run.cash -= TIP_PRICE
	return patrols_next_phase(run)
