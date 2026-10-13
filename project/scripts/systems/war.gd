class_name War

## Corners change hands by force. Act 1 ends in a war for Old Market: once the player holds Mama Lin's corner,
## 午夜兔子 trains their men (see Gym), Rook arms them and the player chooses which of Vex's corners to hit. Rabbit's
## old unit, the first of the Black Hand, is offered after the first loss. When the last corner falls, Vex kneels and
## Act 2 opens, and every rival corner in a district the player can reach is fair game. Every fight is decided by
## numbers the player never sees: who goes in, what each side carries and luck. Scouting gives a rough read first,
## see Scouting. Each side counts its own dead and wounded.

const STRONGHOLD_FACTOR := 1.5
## The result swings by up to this share either way.
const LUCK := 0.2
## Share of the force hit in a won fight, scaled by how close it was, and in a lost one.
const WIN_HIT_SHARE := 0.3
const LOSS_HIT_SHARE := 0.4
## Share of the hit who die, before each tier's lethality. Fate moves it by up to half the swing either way.
const WIN_DEATH_SHARE := 0.35
const LOSS_DEATH_SHARE := 0.5
const FATE_SWING := 0.2
## A failed attack still thins the corner out.
const DEFENDERS_BLED := 0.2
## A street fight is loud, win or lose.
const ATTACK_HEAT := 10
const RABBIT_UNIT_PRICE := 25000
const RABBIT_UNIT_SIZE := 50

const LOST_ONCE := "war_lost_once"
const UNIT_HIRED := "rabbit_unit_hired"
const VEX_FELL := "vex_fell"
const BOOK_BURNED := "shark_book_burned"
const VEX_GANG: StringName = &"vex"


static func is_open(run: RunState) -> bool:
	return Corners.holds(run, Corners.MAMA_LIN) and not Story.has(run, VEX_FELL)


## A rival corner the player could hit or scout: Old Market's during the war, any other in Act 2 once the district
## is open to the player.
static func is_target(run: RunState, corner: CornerDef) -> bool:
	if Corners.holds(run, corner.id):
		return false
	var district_id := Corners.district_of(corner.id)
	if district_id == Corners.HOME:
		return is_open(run)
	var district := Content.district(district_id)
	return Campaign.is_act_two(run) \
		and district != null \
		and not Gangs.is_gone(run, Gangs.owner(district_id)) \
		and not Travel.is_locked(run, district)


static func can_attack(run: RunState, corner: CornerDef) -> bool:
	return is_target(run, corner) and Army.active(run) > 0


static func unit_on_offer(run: RunState) -> bool:
	return is_open(run) and Story.has(run, LOST_ONCE) and not Story.has(run, UNIT_HIRED)


## Rabbit's old unit joins as the Black Hand and stays after the war.
static func hire_unit(run: RunState) -> bool:
	if not unit_on_offer(run) or run.cash < RABBIT_UNIT_PRICE:
		return false
	run.cash -= RABBIT_UNIT_PRICE
	Army.add(run, Army.Tier.BLACK_HAND, Army.State.ACTIVE, RABBIT_UNIT_SIZE)
	Story.mark(run, UNIT_HIRED)
	return true


static func defenders(run: RunState, corner: CornerDef) -> int:
	if Corners.holds(run, corner.id):
		return 0
	return int(run.corner_defenders.get(String(corner.id), corner.defenders))


static func enemy_power(run: RunState, corner: CornerDef) -> float:
	var gang := Corners.gang_of(corner.id)
	var per_man := Rivals.power_per_man(run, gang) if gang != null else Rivals.SKILL
	return defenders(run, corner) * per_man * (STRONGHOLD_FACTOR if corner.stronghold else 1.0)


## Fights for a corner with the deployment from Army.deployment. roll and fate are in [0, 1): roll is the luck of the
## day, fate how deadly the hits turn out. Returns { corner, won, ended, deployed, losses, dead, wounded, defenders,
## defenders_lost }, empty when the attack cannot happen. losses maps a tier to its { dead, wounded }.
static func attack(run: RunState, corner_id: StringName, deployment: Dictionary, roll: float, fate: float) -> Dictionary:
	var corner := Corners.find(corner_id)
	if corner == null or not can_attack(run, corner) or Army.deployed_count(deployment) <= 0:
		return {}
	var mine := Army.power(run, deployment) * lerpf(1.0 - LUCK, 1.0 + LUCK, roll)
	var theirs := enemy_power(run, corner)
	var won := mine >= theirs
	var hit_share := WIN_HIT_SHARE * minf(1.0, theirs / maxf(mine, 1.0)) if won else LOSS_HIT_SHARE
	var death_share := (WIN_DEATH_SHARE if won else LOSS_DEATH_SHARE) + (fate - 0.5) * FATE_SWING
	var losses := Army.casualties(deployment, hit_share, death_share)
	Hospital.admit(run, losses)
	var result := {
		"corner": String(corner_id),
		"won": won,
		"ended": false,
		"deployed": deployment,
		"losses": losses,
		"dead": Army.sum_losses(losses, "dead"),
		"wounded": Army.sum_losses(losses, "wounded"),
		"defenders": defenders(run, corner),
	}
	var defenders_lost: int
	if won:
		defenders_lost = int(result.defenders)
		Corners.take(run, corner_id)
		run.corner_defenders.erase(String(corner_id))
		run.scouted.erase(String(corner_id))
	else:
		defenders_lost = roundi(int(result.defenders) * DEFENDERS_BLED)
		run.corner_defenders[String(corner_id)] = int(result.defenders) - defenders_lost
		Story.mark(run, LOST_ONCE)
	Army.take_losses(run, deployment, losses)
	Heat.add(run, ATTACK_HEAT)
	result.defenders_lost = defenders_lost
	if won and is_open(run) and Corners.held_count(run, Corners.HOME) == Corners.of(Corners.HOME).size():
		end_war(run)
		result.ended = true
	elif won:
		Turf.check_victory(run)
	return result


## Vex kneels. Old Market is the player's for good, Moreau starts her file, and Act 2 opens. Vex keeps her other
## districts. On the failure branch the Shark's book burns with her, so the doubled debt is gone.
static func end_war(run: RunState) -> void:
	Story.mark(run, VEX_FELL)
	Story.mark(run, Moreau.WATCHLIST)
	if Loan.is_with_vex(run):
		Story.mark(run, BOOK_BURNED)
		run.debt = 0
		run.career = true


static func sanitize_defenders(source: Variant) -> Dictionary:
	var clean := {}
	if source is Dictionary:
		for key: Variant in source:
			var corner := Corners.find(StringName(str(key)))
			if corner != null:
				clean[str(key)] = clampi(int(source[key]), 0, Rivals.max_garrison(corner))
	return clean
