class_name Vex

## Vex's crew never ambushes the player at random. They turn up at the gate of a district the
## player holds, and the player decides how to send them off. Ignoring them makes Vex angrier,
## and at full anger her crew hunts the player down wherever they are.

const GATE := "vex_gate"
const HUNT := "vex_hunt"

const GATE_CHANCE := 0.3
const HUNT_CHANCE := 0.5
## Vex hunts the player at this anger.
const MAX_ANGER := 3
const BRIBE_BASE := 200
const BRIBE_PER_ANGER := 100
const HUNT_FEE := 500
const IGNORE_LOSS := 6
const THREAT_STANDING_COST := 5
const FIGHT_GAIN := 10
const FIGHT_LOSS := 10
const FIGHT_LOSS_HEAT := 10
const ANGER_AFTER_PAYING := 1
const ANGER_AFTER_BEATING := MAX_ANGER - 1

const BRIBE: StringName = &"vex_bribe"
const THREATEN: StringName = &"vex_threaten"
const IGNORE: StringName = &"vex_ignore"
const PAY: StringName = &"vex_pay"
const FIGHT: StringName = &"vex_fight"


## Vex's crew calls when she is in a district the player holds and she is not already hunting them.
static func gate_due(run: RunState, roll: float) -> bool:
	if run.vex_gone or run.vex_anger >= MAX_ANGER:
		return false
	var location := Roster.rival_location(run, Calendar.stamp(run))
	return Turf.holder(run, location) == Turf.Holder.PLAYER and roll < GATE_CHANCE


static func hunt_due(run: RunState, roll: float) -> bool:
	return not run.vex_gone and run.vex_anger >= MAX_ANGER and roll < HUNT_CHANCE


static func gate(run: RunState) -> Dictionary:
	var location := Roster.rival_location(run, Calendar.stamp(run))
	var district := Content.district(location)
	return {
		"type": GATE,
		"speaker": String(Turf.RIVAL),
		"title": "Vex at your gate",
		"body": "My crew is parked outside your place in %s. Give me a reason to move them along." % (district.display_name if district != null else "town"),
		"district": String(location),
		"bribe": bribe_cost(run),
	}


static func hunt(run: RunState) -> Dictionary:
	return {
		"type": HUNT,
		"speaker": String(Turf.RIVAL),
		"title": "Vex found you",
		"body": "You kept leaving my crew out in the cold, so I came to you. Pay for my trouble or settle it here.",
		"district": String(fight_district(run)),
		"fee": HUNT_FEE,
	}


static func bribe_cost(run: RunState) -> int:
	return BRIBE_BASE + BRIBE_PER_ANGER * run.vex_anger


## The triad family that trusts the player most, or null. Their name is what scares Vex off.
static func backer(run: RunState) -> FamilyDef:
	var best: FamilyDef = null
	for family in Content.families():
		if Families.tier(run, family.id) < Families.Tier.TRUSTED:
			continue
		if best == null or Families.standing(run, family.id) > Families.standing(run, best.id):
			best = family
	return best


## A hunt is fought where the player stands, or over their strongest district when they stand outside the turf war.
static func fight_district(run: RunState) -> StringName:
	if Turf.is_contested(run.district_id):
		return run.district_id
	var strongest: StringName = Turf.CONTESTED[0]
	for district_id in Turf.CONTESTED:
		if Turf.share(run, district_id) > Turf.share(run, strongest):
			strongest = district_id
	return strongest


static func choices(run: RunState, encounter: Dictionary) -> Array[Encounters.Choice]:
	var list: Array[Encounters.Choice] = []
	match encounter.get("type"):
		GATE:
			var bribe := int(encounter.bribe)
			list.append(Encounters.Choice.new(BRIBE, "Pay %s to leave" % Format.money(bribe), run.cash >= bribe))
			var family := backer(run)
			if family != null:
				list.append(Encounters.Choice.new(THREATEN, "Threaten with the %s" % family.english_name))
			else:
				list.append(Encounters.Choice.new(THREATEN, "Threaten (needs a triad's trust)", false))
			list.append(Encounters.Choice.new(IGNORE, "Ignore them"))
		HUNT:
			var fee := int(encounter.fee)
			list.append(Encounters.Choice.new(PAY, "Pay %s" % Format.money(fee), run.cash >= fee))
			var district_id := StringName(str(encounter.district))
			list.append(Encounters.Choice.new(FIGHT, "Fight (%d%%)" % roundi(Turf.fight_chance(run, district_id) * 100.0)))
	return list


## Applies the answer. The roll decides a fight and must be in the range [0, 1).
static func resolve(run: RunState, encounter: Dictionary, choice: StringName, roll: float) -> String:
	var district_id := StringName(str(encounter.get("district", run.district_id)))
	var district := Content.district(district_id)
	var place := district.display_name if district != null else "town"
	match choice:
		BRIBE:
			var paid := mini(int(encounter.bribe), maxi(0, run.cash))
			run.cash -= paid
			return "You send %s out to the gate. Her crew takes it and drives off." % Format.money(paid)
		THREATEN:
			var family := backer(run)
			if family == null:
				return ""
			Families.shift(run, family.id, -THREAT_STANDING_COST)
			run.vex_anger = maxi(0, run.vex_anger - 1)
			return "You let it slip that the %s look after you. Vex's crew leaves without a word." % family.english_name
		IGNORE:
			Turf.shift(run, district_id, -IGNORE_LOSS)
			StreetCred.add(run, StreetCred.BACKED_OFF)
			run.vex_anger = mini(MAX_ANGER, run.vex_anger + 1)
			if run.vex_anger >= MAX_ANGER:
				return "They work your corners in %s while you stay inside. Vex is done waiting. She is coming for you." % place
			return "They work your corners in %s while you stay inside. Vex will remember this." % place
		PAY:
			var paid := mini(int(encounter.fee), maxi(0, run.cash))
			run.cash -= paid
			run.vex_anger = ANGER_AFTER_PAYING
			return "You pay %s for her trouble. Vex calls her crew off, for now." % Format.money(paid)
		FIGHT:
			if roll < Turf.fight_chance(run, district_id):
				Turf.shift(run, district_id, FIGHT_GAIN)
				StreetCred.add(run, StreetCred.FIGHT_WON)
				run.vex_anger = 0
				return "Your people hold the street. Vex's crew scatters and she backs off."
			Turf.shift(run, district_id, -FIGHT_LOSS)
			Heat.add(run, FIGHT_LOSS_HEAT)
			run.vex_anger = ANGER_AFTER_BEATING
			return "They beat you down in the street. Vex takes more of %s, and the police heard every punch." % place
	return ""
