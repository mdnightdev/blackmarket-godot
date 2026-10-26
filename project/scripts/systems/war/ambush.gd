class_name Ambush

## Trouble waiting at a stop on a hot run. Police make a normal stop; anyone else wants a cut of the crate.
## Losing a fight or a chase costs part of the cargo, never the whole crate, and tolls and losses together stop at
## Smuggling.MAX_LOSS of the pay.

const TYPE := "ambush"
const PAY: StringName = &"ambush_pay"
const FIGHT: StringName = &"ambush_fight"
const RUN: StringName = &"ambush_run"
const NAME_VORONIN: StringName = &"ambush_name_voronin"
const BACK_OFF: StringName = &"ambush_back_off"
## Toll as a share of the job pay: the floor, the usual ask and the rare steep one.
const TOLL_LOW := 0.05
const TOLL_USUAL := 0.1
const TOLL_HIGH := 0.2
const MIN_TOLL := 100
## Share of the cargo taken after a lost fight or chase.
const SKIM_LOW := 0.1
const SKIM_USUAL := 0.2
const SKIM_HIGH := 0.3
## A family crew is tougher than a street crew.
const FAMILY_EDGE := 0.1
const ESCAPED_HEAT := 10
## Talking works best on a street crew. Families answer to nobody and gangs hate Voronin.
const NAME_EDGE := 0.05
const BACK_OFF_EDGE := 0.15
const THREAT_TALK_PENALTY := { Routes.Threat.FAMILY: 0.1, Routes.Threat.GANG: 0.25 }
## A crew that laughed off Voronin's name asks for more.
const PRESSED_TOLL_FACTOR := 1.5


static func start(run: RunState) -> Dictionary:
	var threat := Routes.threat(run, run.district_id, Calendar.stamp(run))
	if threat == Routes.Threat.POLICE:
		return Encounters.police_stop(run)
	var speaker := String(run.player_id)
	var body := "A crew I have never seen steps out of a doorway. Somebody talked about my crate."
	match threat:
		Routes.Threat.GANG:
			var gang := Gangs.in_district(run, run.district_id, Calendar.stamp(run))
			speaker = String(gang.boss)
			body = gang.ambush_line
		Routes.Threat.FAMILY:
			var family := Families.hostile_family_in(run, run.district_id)
			speaker = String(family.lieutenant)
			body = "This is %s ground. Nothing crosses it without paying the family." % family.english_name
	var rng := Odds.rng_for(run, &"ambush")
	return {
		"type": TYPE,
		"speaker": speaker,
		"title": "Ambush",
		"body": body,
		"threat": threat,
		"toll": _capped_toll(run, roundi(int(run.crate.get("pay", 0)) * Odds.bell(rng, TOLL_LOW, TOLL_USUAL, TOLL_HIGH))),
		"skim": Odds.bell(rng, SKIM_LOW, SKIM_USUAL, SKIM_HIGH),
	}


static func fight_chance(run: RunState, encounter: Dictionary) -> float:
	match int(encounter.get("threat", Routes.Threat.QUIET)):
		Routes.Threat.GANG:
			if Turf.is_contested(run.district_id):
				return Turf.fight_chance(run, run.district_id)
		Routes.Threat.FAMILY:
			return Odds.contest(StreetEvents.FIGHT_EDGE - FAMILY_EDGE + StreetEvents.fight_bonus(run))
	return StreetEvents.fight_chance(run)


## Gangs do not chase harder because of police heat, so only speed counts.
static func escape_chance(run: RunState) -> float:
	return Odds.contest(Police.ESCAPE_EDGE + Police.speed_bonus(run))


static func name_chance(run: RunState, encounter: Dictionary) -> float:
	return Odds.contest(NAME_EDGE + Talk.cred_edge(run) - _talk_penalty(encounter))


static func back_off_chance(encounter: Dictionary) -> float:
	return Odds.contest(BACK_OFF_EDGE - _talk_penalty(encounter))


static func choices(run: RunState, encounter: Dictionary) -> Array[Encounters.Choice]:
	var fee := int(encounter.toll)
	var list: Array[Encounters.Choice] = [
		Encounters.Choice.new(PAY, "Pay %s" % Format.money(fee), run.cash >= fee),
		Encounters.Choice.new(FIGHT, "Fight (%s)" % Odds.reading(fight_chance(run, encounter))),
		Encounters.Choice.new(RUN, "Run for it (%s)" % Odds.reading(escape_chance(run))),
	]
	if not bool(encounter.get("pressed", false)):
		list.append(Encounters.Choice.new(NAME_VORONIN, "Say you move for Voronin"))
		list.append(Encounters.Choice.new(BACK_OFF, "Back away slowly"))
	return list


## Applies the answer. The roll decides a fight or an escape and must be in the range [0, 1).
static func resolve(run: RunState, encounter: Dictionary, choice: StringName, roll: float = 0.0) -> String:
	match choice:
		PAY:
			var paid := mini(int(encounter.toll), maxi(0, run.cash))
			run.cash -= paid
			Smuggling.record_toll(run, paid)
			return "You pay %s and they let the crate through." % Format.money(paid)
		FIGHT:
			if roll < fight_chance(run, encounter):
				StreetCred.add(run, StreetCred.FIGHT_WON)
				return "You fight them off. The crate is still yours."
			Smuggling.skim(run, float(encounter.get("skim", SKIM_USUAL)))
			return "They beat you down and pull a few packages out of the crate. The job will pay less."
		RUN:
			if roll < escape_chance(run):
				Heat.add(run, ESCAPED_HEAT)
				return "You lose them in the alleys with the crate under your arm."
			Smuggling.skim(run, float(encounter.get("skim", SKIM_USUAL)))
			return "They catch up and rip a few packages out of the crate before you shake them. The job will pay less."
		NAME_VORONIN:
			if roll < name_chance(run, encounter):
				return "They trade a look and step aside. Nobody wants trouble with Voronin."
			run.pending_encounter = _pressed(run, encounter)
			return "They laugh. Voronin's name buys nothing here."
		BACK_OFF:
			if roll < back_off_chance(encounter):
				StreetCred.add(run, StreetCred.BACKED_OFF)
				return "You back out of the street with your hands in plain sight. Nobody follows, but word gets around."
			Smuggling.skim(run, float(encounter.get("skim", SKIM_USUAL)))
			return "They close in before you reach the corner and pull a few packages out of the crate. The job will pay less."
	return ""


static func _talk_penalty(encounter: Dictionary) -> float:
	return float(THREAT_TALK_PENALTY.get(int(encounter.get("threat", Routes.Threat.QUIET)), 0.0))


static func _capped_toll(run: RunState, asked: int) -> int:
	return mini(maxi(MIN_TOLL, asked), Smuggling.toll_room(run.crate))


static func _pressed(run: RunState, encounter: Dictionary) -> Dictionary:
	var pressed := encounter.duplicate()
	pressed.toll = _capped_toll(run, roundi(int(encounter.toll) * PRESSED_TOLL_FACTOR))
	pressed.pressed = true
	pressed.body = "The price just went up. Pay, or we take it out of the crate."
	return pressed
