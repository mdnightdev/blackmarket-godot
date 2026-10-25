class_name Collections

## The debtor from a collection errand, met on arriving in their district. Talking works on a big name,
## leaning on them works more often but draws heat and annoys the family that runs the street,
## and letting some slide is a sure but smaller take. Every answer closes the errand.

const TYPE := "collection"
const TALK: StringName = &"collection_talk"
const LEAN: StringName = &"collection_lean"
const SLIDE: StringName = &"collection_slide"
const TALK_EDGE := 0.0
const LEAN_EDGE := 0.2
## Share of what is owed that comes in after a failed talk or lean, and when the player lets the rest slide.
const FAIL_SHARE := 0.4
const SLIDE_SHARE := 0.6
const LEAN_HEAT := 10
const LEAN_STANDING_LOSS := 3
const DEBTOR_LINES: Array[String] = [
	"Business is dead. Tell him I need another week.",
	"I paid him last month. Check his books, not my pockets.",
	"Look around. Does this place look like money to you?",
	"I have some of it. Not all. Nobody has all of it.",
	"He sent you? Fine. Sit down before you break something.",
]


static func start(run: RunState, errand: Dictionary) -> Dictionary:
	var rng := Odds.rng_for(run, &"collection")
	var debtor := str(errand.debtor)
	return {
		"type": TYPE,
		"speaker": String(run.player_id),
		"title": "Collection",
		"body": "%s owes %s %s. \"%s\"" % [debtor, Errands.creditor(errand), Format.money(int(errand.owed)), DEBTOR_LINES[rng.randi_range(0, DEBTOR_LINES.size() - 1)]],
		"errand": str(errand.id),
		"debtor": debtor,
		"owed": int(errand.owed),
	}


static func talk_chance(run: RunState) -> float:
	return Odds.contest(TALK_EDGE + Talk.cred_edge(run))


static func lean_chance(run: RunState) -> float:
	return Odds.contest(LEAN_EDGE + Talk.cred_edge(run))


static func choices(run: RunState, encounter: Dictionary) -> Array[Encounters.Choice]:
	var debtor := str(encounter.debtor)
	var slide := roundi(int(encounter.owed) * SLIDE_SHARE)
	var list: Array[Encounters.Choice] = [
		Encounters.Choice.new(TALK, "Talk %s into paying (%s)" % [debtor, Odds.reading(talk_chance(run))]),
		Encounters.Choice.new(LEAN, "Lean on %s (%s)" % [debtor, Odds.reading(lean_chance(run))]),
		Encounters.Choice.new(SLIDE, "Take %s and let the rest slide" % Format.money(slide)),
	]
	return list


## Applies the answer and pays the player's cut. The roll must be in the range [0, 1).
static func resolve(run: RunState, encounter: Dictionary, choice: StringName, roll: float = 0.0) -> String:
	var errand := Errands.find(run, str(encounter.get("errand", "")))
	if errand.is_empty():
		return ""
	var debtor := str(encounter.debtor)
	var owed := int(encounter.owed)
	var share := FAIL_SHARE
	var line := ""
	match choice:
		TALK:
			if roll < talk_chance(run):
				share = 1.0
				line = "%s hears you out and counts out the full %s." % [debtor, Format.money(owed)]
			else:
				line = "%s talks you in circles. You leave with %s." % [debtor, Format.money(roundi(owed * share))]
		LEAN:
			Heat.add(run, LEAN_HEAT)
			_upset_family(run, StringName(str(errand.district)))
			if roll < lean_chance(run):
				share = 1.0
				line = "One hand on the collar is enough. %s pays the full %s." % [debtor, Format.money(owed)]
			else:
				line = "%s takes the shove and still only finds %s." % [debtor, Format.money(roundi(owed * share))]
		SLIDE:
			share = SLIDE_SHARE
			line = "You take %s from %s and let the rest slide." % [Format.money(roundi(owed * share)), debtor]
		_:
			return ""
	var paid := Errands.complete(run, errand, share)
	if int(paid.cash) <= 0 and int(paid.debt) <= 0:
		return "%s %s" % [line, Errands.describe_payout(paid)]
	return "%s Your cut: %s." % [line, Errands.describe_payout(paid)]


static func _upset_family(run: RunState, district_id: StringName) -> void:
	for family in Content.families():
		if family.home_districts.has(district_id):
			Families.shift(run, family.id, -LEAN_STANDING_LOSS)
