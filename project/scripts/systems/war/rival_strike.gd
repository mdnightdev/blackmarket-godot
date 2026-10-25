class_name RivalStrike

## Rivals hit back. A gang that lost corners to the player sends part of a nearby crew to take one back, but only when
## it likes the odds against what the player could send. At most one strike comes per morning, and each gang waits a
## few days between strikes. The morning brings a warning and the player has a short countdown to answer.
## 午夜兔子 can take the defence, and a war veteran gets more out of the same men. Or the player mobilises the crew
## themselves and picks who goes. A lost defence hands the corner back with the raiders' survivors on it.

const TYPE := "rival_strike"
const DELEGATE: StringName = &"delegate"
const MOBILISE: StringName = &"mobilise"
const RABBIT: StringName = &"midnight_rabbit"
const COUNTDOWN_SECONDS := 15.0
const CHANCE := 0.35
## Days a gang waits after striking before it can strike again.
const MIN_DAYS_BETWEEN := 3
## Share of the gang's men in the district that it sends.
const RAIDING_SHARE := 0.3
## A gang strikes when its raiders are worth at least this share of the defence the player could put up.
const LIKES_ODDS_AT := 0.8
const RABBIT_EDGE := 1.25
## Defenders who know the ground fight a little better than the crew walking in.
const HOLDING_EDGE := 1.1
## Share of the raiders who fall when the defence holds.
const RAIDERS_LOST_ON_WIN := 0.6


## Corners the gang could hit: the ones the player took from it. Mama Lin's corner was bought, not taken, and Old
## Market stays the player's once Vex kneels.
static func targets(run: RunState, gang: GangDef) -> Array[CornerDef]:
	var list: Array[CornerDef] = []
	for district_id in gang.turf:
		if district_id == Corners.HOME and not War.is_open(run):
			continue
		for corner in Corners.of(district_id):
			if corner.id != Corners.MAMA_LIN and Corners.holds(run, corner.id) and Corners.gang_of(corner.id) == gang:
				list.append(corner)
	return list


## The corner the raiders leave from: the gang's corner with the most men in the target's district, or anywhere on
## its turf when it holds nothing there.
static func source(run: RunState, gang: GangDef, target: CornerDef) -> CornerDef:
	var nearby := Corners.of(Corners.district_of(target.id)).filter(
		func(corner: CornerDef) -> bool: return not Corners.holds(run, corner.id) and Corners.gang_of(corner.id) == gang)
	var pool: Array = nearby if not nearby.is_empty() else Rivals.corners(run, gang)
	var best: CornerDef = null
	for corner: CornerDef in pool:
		if best == null or War.defenders(run, corner) > War.defenders(run, best):
			best = corner
	return best if best != null and War.defenders(run, best) > 0 else null


## A third of the gang's men in the source's district, never more than the source holds.
static func raiders(run: RunState, from: CornerDef) -> int:
	var gang := Corners.gang_of(from.id)
	var standing := 0
	for corner in Corners.of(Corners.district_of(from.id)):
		if Corners.gang_of(corner.id) == gang:
			standing += War.defenders(run, corner)
	return clampi(roundi(standing * RAIDING_SHARE), 1, War.defenders(run, from))


## The gang weighs its raiders against the corner's posted garrison when fortified, or the reserve force.
static func likes_odds(run: RunState, gang: GangDef, sent: int, target: CornerDef = null) -> bool:
	if target != null and Corners.garrison(run, target.id) > 0:
		return sent * Rivals.power_per_man(run, gang) >= Corners.garrison_power(run, target) * 1.25
	return sent * Rivals.power_per_man(run, gang) >= Army.strength(run) * HOLDING_EDGE * LIKES_ODDS_AT


static func can_strike(run: RunState, gang: GangDef) -> bool:
	if Gangs.is_gone(run, gang) or targets(run, gang).is_empty():
		return false
	var last := Rivals.last_strike_day(run, gang)
	return last <= 0 or run.day - last >= MIN_DAYS_BETWEEN


## Queues one strike when a new day starts and some gang is ready and likes its odds.
static func check(run: RunState, new_day_started: bool, roll: float) -> bool:
	if not new_day_started or Encounters.has_pending(run) or roll >= CHANCE:
		return false
	var rng := Odds.rng_for(run, &"rival_strike")
	for gang in Gangs.active(run):
		if not can_strike(run, gang):
			continue
		var corners := targets(run, gang)
		var target := corners[rng.randi() % corners.size()]
		var from := source(run, gang, target)
		if from == null:
			continue
		var sent := raiders(run, from)
		if likes_odds(run, gang, sent, target):
			run.pending_encounter = start(run, gang, target, from, sent)
			return true
	return false


static func start(run: RunState, gang: GangDef, target: CornerDef, from: CornerDef, sent: int) -> Dictionary:
	Rivals.note_strike(run, gang, run.day)
	var carrying := str(Armory.GRADE_NAMES[Rivals.gear(run, gang)]).to_lower()
	return {
		"type": TYPE,
		"gang": String(gang.id),
		"speaker": String(RABBIT),
		"title": "Ambush",
		"body": "%s is moving on %s. About %d men with %s, out of %s. Say how we answer." % [gang.crew_name, target.display_name, sent, carrying, from.display_name],
		"corner": String(target.id),
		"source": String(from.id),
		"raiders": sent,
	}


## Settles the strike without the countdown screen. Returns what happened in one line.
static func resolve(run: RunState, encounter: Dictionary, choice: StringName, roll: float = 0.0) -> String:
	var delegated := choice == DELEGATE
	var deployment := rabbit_deployment(run) if delegated else Army.deployment(run)
	return summary(defend(run, encounter, deployment, delegated, roll, 0.5))


static func summary(result: Dictionary) -> String:
	if result.is_empty():
		return ""
	var corner := Corners.find(StringName(str(result.corner)))
	var place := corner.display_name if corner != null else "the corner"
	var gang := Content.gang(StringName(str(result.get("gang", Gangs.LEGACY_GANG))))
	var crew := gang.crew_name if gang != null else "the crew"
	if bool(result.won):
		return "%s holds. %d of %s stay down. You lost %d dead, %d wounded." % [place, int(result.defenders_lost), crew, int(result.dead), int(result.wounded)]
	return "%s falls back to %s. You lost %d dead, %d wounded." % [place, crew, int(result.dead), int(result.wounded)]


## What Rabbit sends: everyone the expansion allows, the Black Hand included.
static func rabbit_deployment(run: RunState) -> Dictionary:
	return Army.deployment(run)


static func choices(run: RunState, _encounter: Dictionary = {}) -> Array[Encounters.Choice]:
	var rabbit := Content.speaker(RABBIT)
	return [
		Encounters.Choice.new(DELEGATE, "Leave it to %s" % (rabbit.display_name if rabbit != null else "Rabbit")),
		Encounters.Choice.new(MOBILISE, "Mobilise the crew yourself", Army.reserve(run) > 0),
	]


## Fights the strike with the men sent. roll and fate are in [0, 1) as in War.attack. Returns { gang, corner, won,
## delegated, deployed, losses, dead, wounded, defenders, defenders_lost }, where defenders are the raiders, so the
## result reads like a War.attack result.
static func defend(run: RunState, encounter: Dictionary, deployment: Dictionary, delegated: bool, roll: float, fate: float) -> Dictionary:
	var corner := Corners.find(StringName(str(encounter.get("corner", ""))))
	var from := Corners.find(StringName(str(encounter.get("source", ""))))
	var gang := Gangs.of_encounter(encounter)
	if corner == null or from == null or gang == null:
		return {}
	var sent_against := int(encounter.get("raiders", 0))
	var sent := Army.deployed_count(deployment)
	var posted := Corners.garrison(run, corner.id)
	var edge := HOLDING_EDGE * (RABBIT_EDGE if delegated else 1.0)
	var luck_mult := Odds.bell_from_roll(roll, 1.0 - War.LUCK, 1.0, 1.0 + War.LUCK)
	var posted_bonus := Corners.garrison_power(run, corner) if posted > 0 else 0.0
	var mine := (Army.power(run, deployment) * edge + posted_bonus) * luck_mult
	var theirs := sent_against * Rivals.power_per_man(run, gang)
	var won := (sent > 0 or posted > 0) and mine >= theirs
	var hit_share := War.WIN_HIT_SHARE * minf(1.0, theirs / maxf(mine, 1.0)) if won else War.LOSS_HIT_SHARE
	var fate_offset := Odds.bell_from_roll(fate, -0.5 * War.FATE_SWING, 0.0, 0.5 * War.FATE_SWING)
	var death_share := (War.WIN_DEATH_SHARE if won else War.LOSS_DEATH_SHARE) + fate_offset
	var losses := Army.casualties(deployment, hit_share, death_share)
	Hospital.admit(run, losses)
	var raiders_lost := roundi(sent_against * (RAIDERS_LOST_ON_WIN if won else War.DEFENDERS_BLED))
	var left_at_source := War.defenders(run, from) - (raiders_lost if won else sent_against)
	run.corner_defenders[String(from.id)] = maxi(0, left_at_source)
	if not won:
		Corners.lose(run, corner.id)
		run.corner_defenders[String(corner.id)] = mini(Rivals.max_garrison(corner), sent_against - raiders_lost)
	Army.take_losses(run, deployment, losses)
	return {
		"gang": String(gang.id),
		"corner": String(corner.id),
		"won": won,
		"delegated": delegated,
		"deployed": deployment,
		"losses": losses,
		"dead": Army.sum_losses(losses, "dead"),
		"wounded": Army.sum_losses(losses, "wounded"),
		"defenders": sent_against,
		"defenders_lost": raiders_lost,
	}


static func reconcile_live_battle(run: RunState, result: Dictionary, player_side: BattleSide, enemy_side: BattleSide) -> void:
	if result.is_empty():
		return
	var corner_id := StringName(str(result.get("corner", "")))
	var corner := Corners.find(corner_id)
	if corner == null:
		return
	var player_share := float(player_side.survivors) / maxi(1, player_side.head_count)
	var enemy_share := float(enemy_side.survivors) / maxi(1, enemy_side.head_count)
	var live_won := enemy_share < player_share
	if live_won and not bool(result.won):
		result.won = true
		Corners.take(run, corner_id)
		run.corner_defenders.erase(String(corner_id))
