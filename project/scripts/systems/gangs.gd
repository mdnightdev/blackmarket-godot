class_name Gangs

## Street crews fighting the player for turf, see GangDef. A crew only comes for the player on its own turf: in the
## district its boss is working, when the crew holds the bigger share of it. The stronger its hold, the more often
## it comes, and the gang's style decides how. Crossing the crew angers the boss, and at full anger the crew hunts
## the player down wherever they are.

const GATE := "gang_gate"
const HUNT := "gang_hunt"
const HUNT_CHANCE := 0.5
## The crew hunts the player at this anger.
const MAX_ANGER := 3
const IGNORE_LOSS := 6
const THREAT_STANDING_COST := 5
const FIGHT_GAIN := 10
const FIGHT_LOSS := 10
const FIGHT_LOSS_HEAT := 10
const ANGER_AFTER_PAYING := 1
const ANGER_AFTER_BEATING := MAX_ANGER - 1
## A mugging crew asks for this share of the cash carried, and takes twice as much from a player it beats.
const MUGGING_SHARE := 0.15
const BEATEN_MUGGING_FACTOR := 2.0
const ESCAPED_HEAT := 10
## An informer crew's tip-off brings the police with this much extra heat.
const TIP_OFF_HEAT := 15

const BRIBE: StringName = &"gang_bribe"
const THREATEN: StringName = &"gang_threaten"
const IGNORE: StringName = &"gang_ignore"
const PAY: StringName = &"gang_pay"
const FIGHT: StringName = &"gang_fight"
const RUN: StringName = &"gang_run"

## Saves from before gangs were data only knew Vex.
const LEGACY_GANG: StringName = &"vex"
const LEGACY_TYPES := { "vex_gate": GATE, "vex_hunt": HUNT }


## Gangs still in the city, in catalog order.
static func active(run: RunState) -> Array[GangDef]:
	var list: Array[GangDef] = []
	for gang in Content.gangs():
		if not is_gone(run, gang):
			list.append(gang)
	return list


static func is_gone(run: RunState, gang: GangDef) -> bool:
	return gang == null or run.gangs_gone.has(gang.id)


static func anger(run: RunState, gang: GangDef) -> int:
	return int(run.gang_anger.get(gang.id, 0))


static func set_anger(run: RunState, gang: GangDef, value: int) -> void:
	run.gang_anger[gang.id] = clampi(value, 0, MAX_ANGER)


## The gang whose turf the district is, or null.
static func owner(district_id: StringName) -> GangDef:
	for gang in Content.gangs():
		if gang.turf.has(district_id):
			return gang
	return null


static func for_boss(character_id: StringName) -> GangDef:
	for gang in Content.gangs():
		if gang.boss == character_id:
			return gang
	return null


## The gang an encounter belongs to. Old saves only had Vex.
static func of_encounter(encounter: Dictionary) -> GangDef:
	return Content.gang(StringName(str(encounter.get("gang", LEGACY_GANG))))


## Where the boss is this phase, empty once the gang has left the city.
static func boss_location(run: RunState, gang: GangDef, stamp: int) -> StringName:
	var boss := Content.character(gang.boss)
	return Roster.character_location(run, boss, stamp) if boss != null else &""


## The gang whose boss is working the district this phase, or null.
static func in_district(run: RunState, district_id: StringName, stamp: int) -> GangDef:
	for gang in active(run):
		if boss_location(run, gang, stamp) == district_id:
			return gang
	return null


## Queues a hunt or a corner tax when one is due. One roll per gang for each, in catalog order.
static func queue_encounter(run: RunState, rng: RandomNumberGenerator) -> bool:
	for gang in active(run):
		if hunt_due(run, gang, rng.randf()):
			run.pending_encounter = hunt(run, gang)
			return true
	for gang in active(run):
		if gate_due(run, gang, rng.randf()):
			run.pending_encounter = gate(run, gang)
			return true
	return false


static func gate_due(run: RunState, gang: GangDef, roll: float) -> bool:
	if is_gone(run, gang) or anger(run, gang) >= MAX_ANGER:
		return false
	return roll < gate_chance(run, gang)


static func gate_chance(run: RunState, gang: GangDef) -> float:
	var location := boss_location(run, gang, Calendar.stamp(run))
	if location != run.district_id or owner(location) != gang:
		return 0.0
	var crew_lead := Turf.STARTING_SHARE - Turf.share(run, location)
	return gang.max_gate_chance * maxf(0.0, crew_lead) / Turf.STARTING_SHARE


static func hunt_due(run: RunState, gang: GangDef, roll: float) -> bool:
	return not is_gone(run, gang) and anger(run, gang) >= MAX_ANGER and roll < HUNT_CHANCE


static func gate(run: RunState, gang: GangDef) -> Dictionary:
	var location := boss_location(run, gang, Calendar.stamp(run))
	var district := Content.district(location)
	return {
		"type": GATE,
		"gang": String(gang.id),
		"speaker": String(gang.boss),
		"title": gang.gate_title,
		"body": gang.gate_line % (district.display_name if district != null else "town"),
		"district": String(location),
		"bribe": mugging_cut(run, gang) if gang.style == GangDef.Style.MUGGING else bribe_cost(run, gang),
	}


static func hunt(run: RunState, gang: GangDef) -> Dictionary:
	return {
		"type": HUNT,
		"gang": String(gang.id),
		"speaker": String(gang.boss),
		"title": gang.hunt_title,
		"body": gang.hunt_line,
		"district": String(fight_district(run, gang)),
		"fee": gang.hunt_fee,
	}


static func bribe_cost(run: RunState, gang: GangDef) -> int:
	return gang.bribe_base + gang.bribe_per_anger * anger(run, gang)


static func mugging_cut(run: RunState, gang: GangDef) -> int:
	return maxi(gang.bribe_base, roundi(maxi(0, run.cash) * MUGGING_SHARE))


## The triad family that trusts the player most, or null. Their name is what scares a crew off.
static func backer(run: RunState) -> FamilyDef:
	var best: FamilyDef = null
	for family in Content.families():
		if Families.tier(run, family.id) < Families.Tier.TRUSTED:
			continue
		if best == null or Families.standing(run, family.id) > Families.standing(run, best.id):
			best = family
	return best


## A hunt is fought where the player stands, or over their strongest district of the gang's turf when they
## stand outside it.
static func fight_district(run: RunState, gang: GangDef) -> StringName:
	if owner(run.district_id) == gang:
		return run.district_id
	var strongest: StringName = gang.turf[0]
	for district_id in gang.turf:
		if Turf.share(run, district_id) > Turf.share(run, strongest):
			strongest = district_id
	return strongest


static func choices(run: RunState, encounter: Dictionary) -> Array[Encounters.Choice]:
	var list: Array[Encounters.Choice] = []
	var gang := of_encounter(encounter)
	if gang == null:
		return list
	var district_id := StringName(str(encounter.get("district", run.district_id)))
	var fight := Encounters.Choice.new(FIGHT, "Fight (%s)" % Odds.reading(Turf.fight_chance(run, district_id)))
	if encounter.get("type") == HUNT:
		var fee := int(encounter.fee)
		list.append(Encounters.Choice.new(PAY, "Pay %s" % Format.money(fee), run.cash >= fee))
		list.append(fight)
		return list
	var bribe := int(encounter.bribe)
	match gang.style:
		GangDef.Style.MUGGING:
			list.append(Encounters.Choice.new(BRIBE, "Hand over %s" % Format.money(bribe), run.cash >= bribe))
			list.append(fight)
			list.append(Encounters.Choice.new(RUN, "Run for it (%s)" % Odds.reading(Ambush.escape_chance(run))))
		_:
			var label := "Pay %s to keep quiet" if gang.style == GangDef.Style.INFORMER else "Pay %s"
			list.append(Encounters.Choice.new(BRIBE, label % Format.money(bribe), run.cash >= bribe))
			var family := backer(run)
			if family != null:
				list.append(Encounters.Choice.new(THREATEN, "Threaten with the %s" % family.english_name))
			else:
				list.append(Encounters.Choice.new(THREATEN, "Threaten (needs a triad's trust)", false))
			list.append(Encounters.Choice.new(IGNORE, "Refuse"))
	return list


## Applies the answer. The roll decides a fight and must be in the range [0, 1).
static func resolve(run: RunState, encounter: Dictionary, choice: StringName, roll: float) -> String:
	var gang := of_encounter(encounter)
	if gang == null:
		return ""
	var district_id := StringName(str(encounter.get("district", run.district_id)))
	var district := Content.district(district_id)
	var place := district.display_name if district != null else "town"
	match choice:
		BRIBE:
			var paid := _take_cash(run, int(encounter.bribe))
			match gang.style:
				GangDef.Style.MUGGING:
					return "You hand over %s. %s melts back into the alleys." % [Format.money(paid), gang.crew_name]
				GangDef.Style.INFORMER:
					return "You pay %s. %s forgets your face, for now." % [Format.money(paid), gang.crew_name]
			return "You hand over %s. %s counts it and lets you work." % [Format.money(paid), gang.crew_name]
		THREATEN:
			var family := backer(run)
			if family == null:
				return ""
			Families.shift(run, family.id, -THREAT_STANDING_COST)
			set_anger(run, gang, anger(run, gang) - 1)
			return "You let it slip that the %s look after you. %s leaves without a word." % [family.english_name, gang.crew_name]
		IGNORE:
			Turf.shift(run, district_id, -IGNORE_LOSS)
			StreetCred.add(run, StreetCred.BACKED_OFF)
			set_anger(run, gang, anger(run, gang) + 1)
			if gang.style == GangDef.Style.INFORMER:
				Heat.add(run, TIP_OFF_HEAT)
				run.pending_encounter = Encounters.police_stop(run)
				return "You walk off. Minutes later a patrol car pulls up. Somebody gave them your description."
			if anger(run, gang) >= MAX_ANGER:
				return "You walk off. %s leans on your people in %s. %s is done waiting and comes looking for you." % [gang.crew_name, place, gang.display_name]
			return "You walk off. %s leans on your people in %s. %s will remember this." % [gang.crew_name, place, gang.display_name]
		PAY:
			var paid := _take_cash(run, int(encounter.fee))
			set_anger(run, gang, ANGER_AFTER_PAYING)
			return "You pay %s for the trouble. %s calls the crew off, for now." % [Format.money(paid), gang.display_name]
		FIGHT:
			if roll < Turf.fight_chance(run, district_id):
				Turf.shift(run, district_id, FIGHT_GAIN)
				StreetCred.add(run, StreetCred.FIGHT_WON)
				set_anger(run, gang, 0)
				return "Your people hold the street. %s scatters and %s backs off." % [gang.crew_name, gang.display_name]
			Turf.shift(run, district_id, -FIGHT_LOSS)
			Heat.add(run, FIGHT_LOSS_HEAT)
			set_anger(run, gang, ANGER_AFTER_BEATING)
			if encounter.get("type") == GATE:
				var taken := _take_cash(run, roundi(int(encounter.bribe) * BEATEN_MUGGING_FACTOR))
				return "They beat you down and empty your pockets of %s. %s takes more of %s." % [Format.money(taken), gang.display_name, place]
			return "They beat you down in the street. %s takes more of %s, and the police heard every punch." % [gang.display_name, place]
		RUN:
			set_anger(run, gang, anger(run, gang) + 1)
			if roll < Ambush.escape_chance(run):
				Heat.add(run, ESCAPED_HEAT)
				return "You lose them in the alleys. %s will not forget it." % gang.display_name
			Turf.shift(run, district_id, -IGNORE_LOSS)
			var lost := _take_cash(run, int(encounter.bribe))
			return "They catch you two streets over and take %s. Word spreads that you ran." % Format.money(lost)
	return ""


static func _take_cash(run: RunState, amount: int) -> int:
	var taken := mini(amount, maxi(0, run.cash))
	run.cash -= taken
	return taken


## Renames encounters saved before gangs were data.
static func migrate_encounter(encounter: Dictionary) -> Dictionary:
	var type := str(encounter.get("type", ""))
	if not LEGACY_TYPES.has(type):
		return encounter
	var migrated := encounter.duplicate()
	migrated.type = LEGACY_TYPES[type]
	migrated.gang = String(LEGACY_GANG)
	return migrated


static func sanitize_anger(source: Variant) -> Dictionary:
	var result := {}
	if source is Dictionary:
		for key: Variant in source:
			var gang_id := StringName(str(key))
			if Content.gang(gang_id) != null:
				result[gang_id] = clampi(int(source[key]), 0, MAX_ANGER)
	return result


static func sanitize_gone(source: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if source is Array:
		for entry: Variant in source:
			var gang_id := StringName(str(entry))
			if Content.gang(gang_id) != null and not result.has(gang_id):
				result.append(gang_id)
	return result
