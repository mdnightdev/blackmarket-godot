class_name Talk

## Talking an officer out of a stop instead of paying or running. The odds stay hidden:
## a bigger name helps, heat hurts, and a failed line leaves the player cornered.

const PLAY_DUMB: StringName = &"play_dumb"
const SHOW_ID: StringName = &"show_id"
const NAME_DROP: StringName = &"name_drop"

const FAKE_ID: StringName = &"fake_ids"
## Strength lead for every street cred rank above the first.
const CRED_EDGE_PER_RANK := 0.02
## Officers listen less to a face they keep hearing about.
const HEAT_PENALTY := 0.002
const PLAY_DUMB_EDGE := -0.05
const SHOW_ID_EDGE := 0.1
const NAME_DROP_EDGE := { Families.Tier.TRUSTED: 0.1, Families.Tier.FAMILY: 0.25 }


static func cred_edge(run: RunState) -> float:
	return (StreetCred.rank(run) - 1) * CRED_EDGE_PER_RANK


## The family that trusts the player most, or null when none trusts them yet.
static func friendly_family(run: RunState) -> FamilyDef:
	var best: FamilyDef = null
	for family in Content.families():
		if Families.tier(run, family.id) < Families.Tier.TRUSTED:
			continue
		if best == null or Families.standing(run, family.id) > Families.standing(run, best.id):
			best = family
	return best


## The one line the player can try on an officer: a friendly family's name, then a fake ID, then playing dumb.
static func police_line(run: RunState) -> StringName:
	if friendly_family(run) != null:
		return NAME_DROP
	if Inventory.count(run, FAKE_ID) > 0:
		return SHOW_ID
	return PLAY_DUMB


static func police_label(run: RunState, line: StringName) -> String:
	match line:
		NAME_DROP:
			return "Mention the %s" % friendly_family(run).english_name
		SHOW_ID:
			return "Show a fake ID"
	return "Play dumb"


static func police_chance(run: RunState, line: StringName) -> float:
	var edge := PLAY_DUMB_EDGE
	match line:
		NAME_DROP:
			edge = float(NAME_DROP_EDGE[Families.tier(run, friendly_family(run).id)])
		SHOW_ID:
			edge = SHOW_ID_EDGE
	return Odds.contest(edge + cred_edge(run) - run.heat * HEAT_PENALTY)


## The roll must be in the range [0, 1). A failed line queues a cornered stop.
static func resolve_police(run: RunState, line: StringName, roll: float) -> String:
	if roll < police_chance(run, line):
		match line:
			NAME_DROP:
				return "The name lands. They suddenly remember somewhere else to be."
			SHOW_ID:
				return "They study the ID, hand it back and wave you on."
		return "They squint at you for a long moment, then wave you on."
	run.pending_encounter = Encounters.police_stop(run, true)
	match line:
		NAME_DROP:
			return "They know the name. They just do not care."
		SHOW_ID:
			Inventory.discard(run, FAKE_ID, 1)
			return "They run the ID and it comes back fake. They keep it."
	return "They are not buying it."
