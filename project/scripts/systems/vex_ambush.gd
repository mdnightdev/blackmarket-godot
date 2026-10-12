class_name VexAmbush

## Once the player has taken a corner from Vex, her crew strikes back. At most once every few days a morning brings
## a warning: part of her crew is moving on one of the corners she lost. The player has a short countdown to answer.
## 午夜兔子 can take the defence, and a war veteran gets more out of the same men. Or the player mobilises the crew
## themselves and picks who goes. A lost defence hands the corner back to Vex with her survivors on it.

const TYPE := "vex_ambush"
const DELEGATE: StringName = &"delegate"
const MOBILISE: StringName = &"mobilise"
const RABBIT: StringName = &"midnight_rabbit"
const COUNTDOWN_SECONDS := 15.0
const CHANCE := 0.35
## Days from one ambush before the next can come, so there are never two in a row.
const MIN_DAYS_BETWEEN := 3
## Share of the crew still standing at Vex's corners that she sends.
const RAIDING_SHARE := 0.3
const RABBIT_EDGE := 1.25
## Defenders who know the ground fight a little better than the crew walking in.
const HOLDING_EDGE := 1.1
## Share of the raiders who fall when the defence holds.
const RAIDERS_LOST_ON_WIN := 0.6


## Corners Vex could hit: the ones the player took from her. Mama Lin's corner was bought, not taken.
static func targets(run: RunState) -> Array[CornerDef]:
	var list: Array[CornerDef] = []
	for corner in Corners.of(Corners.HOME):
		if corner.id != Corners.MAMA_LIN and Corners.holds(run, corner.id):
			list.append(corner)
	return list


## The corner Vex sends the raiders from: wherever she still has the most men.
static func source(run: RunState) -> CornerDef:
	var best: CornerDef = null
	for corner in Corners.of(Corners.HOME):
		if not Corners.holds(run, corner.id) and (best == null or War.defenders(run, corner) > War.defenders(run, best)):
			best = corner
	return best if best != null and War.defenders(run, best) > 0 else null


static func is_due(run: RunState, roll: float) -> bool:
	if not War.is_open(run) or targets(run).is_empty() or source(run) == null:
		return false
	if run.last_ambush_day > 0 and run.day - run.last_ambush_day < MIN_DAYS_BETWEEN:
		return false
	return roll < CHANCE


static func check(run: RunState, new_day_started: bool, roll: float) -> bool:
	if not new_day_started or Encounters.has_pending(run) or not is_due(run, roll):
		return false
	run.pending_encounter = start(run)
	return true


static func start(run: RunState) -> Dictionary:
	var corners := targets(run)
	var target := corners[Odds.rng_for(run, &"vex_ambush").randi() % corners.size()]
	var from := source(run)
	var standing := 0
	for corner in Corners.of(Corners.HOME):
		standing += War.defenders(run, corner)
	var raiders := clampi(roundi(standing * RAIDING_SHARE), 1, War.defenders(run, from))
	run.last_ambush_day = run.day
	return {
		"type": TYPE,
		"speaker": String(RABBIT),
		"title": "Ambush",
		"body": "Vex's crew is moving on %s. About %d blades out of %s. Say how we answer." % [target.display_name, raiders, from.display_name],
		"corner": String(target.id),
		"source": String(from.id),
		"raiders": raiders,
	}


## Settles the ambush without the countdown screen. Returns what happened in one line.
static func resolve(run: RunState, encounter: Dictionary, choice: StringName, roll: float) -> String:
	var delegated := choice == DELEGATE
	var deployment := rabbit_deployment(run) if delegated else Army.deployment(run)
	return summary(defend(run, encounter, deployment, delegated, roll, 0.5))


static func summary(result: Dictionary) -> String:
	if result.is_empty():
		return ""
	var corner := Corners.find(StringName(str(result.corner)))
	var place := corner.display_name if corner != null else "the corner"
	if bool(result.won):
		return "%s holds. %d of Vex's crew stay down. You lost %d dead, %d wounded." % [place, int(result.defenders_lost), int(result.dead), int(result.wounded)]
	return "%s falls back to Vex. You lost %d dead, %d wounded." % [place, int(result.dead), int(result.wounded)]


## What Rabbit sends: everyone the expansion allows, the Black Hand included.
static func rabbit_deployment(run: RunState) -> Dictionary:
	return Army.deployment(run)


static func choices(run: RunState) -> Array[Encounters.Choice]:
	var rabbit := Content.speaker(RABBIT)
	return [
		Encounters.Choice.new(DELEGATE, "Leave it to %s" % (rabbit.display_name if rabbit != null else "Rabbit")),
		Encounters.Choice.new(MOBILISE, "Mobilise the crew yourself", Army.active(run) > 0),
	]


## Fights the ambush with the men sent. roll and fate are in [0, 1) as in War.attack. Returns { corner, won,
## delegated, deployed, losses, dead, wounded, defenders, defenders_lost }, where defenders are Vex's raiders, so
## the result reads like a War.attack result.
static func defend(run: RunState, encounter: Dictionary, deployment: Dictionary, delegated: bool, roll: float, fate: float) -> Dictionary:
	var corner := Corners.find(StringName(str(encounter.get("corner", ""))))
	var from := Corners.find(StringName(str(encounter.get("source", ""))))
	if corner == null or from == null:
		return {}
	var raiders := int(encounter.get("raiders", 0))
	var sent := Army.deployed_count(deployment)
	var edge := HOLDING_EDGE * (RABBIT_EDGE if delegated else 1.0)
	var mine := Army.power(run, deployment) * edge * lerpf(1.0 - War.LUCK, 1.0 + War.LUCK, roll)
	var theirs := raiders * War.BLADE_SKILL
	var won := sent > 0 and mine >= theirs
	var hit_share := War.WIN_HIT_SHARE * minf(1.0, theirs / maxf(mine, 1.0)) if won else War.LOSS_HIT_SHARE
	var death_share := (War.WIN_DEATH_SHARE if won else War.LOSS_DEATH_SHARE) + (fate - 0.5) * War.FATE_SWING
	var losses := Army.casualties(deployment, hit_share, death_share)
	var raiders_lost := roundi(raiders * (RAIDERS_LOST_ON_WIN if won else War.DEFENDERS_BLED))
	var left_at_source := War.defenders(run, from) - (raiders_lost if won else raiders)
	run.corner_defenders[String(from.id)] = maxi(0, left_at_source)
	if not won:
		Corners.lose(run, corner.id)
		run.corner_defenders[String(corner.id)] = mini(corner.defenders, raiders - raiders_lost)
	Army.take_losses(run, deployment, losses)
	return {
		"corner": String(corner.id),
		"won": won,
		"delegated": delegated,
		"deployed": deployment,
		"losses": losses,
		"dead": Army.sum_losses(losses, "dead"),
		"wounded": Army.sum_losses(losses, "wounded"),
		"defenders": raiders,
		"defenders_lost": raiders_lost,
	}
