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

## BATTLE.md Section 2 & 3: War Event Windows & 5 Simultaneous March Lines.
const MAX_MARCH_LINES := 5
const DEFAULT_WAR_WINDOW_SECONDS := 600.0
const BASE_TRANSIT_SECONDS := 15.0
const REINFORCEMENT_RATE_PER_SECOND := 0.004

## BATTLE.md Section 5: Decision at the Gate.
enum GateDecision { COMMIT, PULL_BACK, STAGGER }
const PULL_BACK_CASH_PENALTY := 2500
const PULL_BACK_CRED_PENALTY := -5
const STAGGER_MIN_MORALE := 0.50

## BATTLE.md Section 7: Commander Canon & Command Clearances.
const COMMANDER_RABBIT: StringName = &"midnight_rabbit"
const COMMANDER_VEX: StringName = &"rival"
const COMMANDER_SHARK: StringName = &"shark"
const COMMANDER_GAO: StringName = &"old_gao"
const COMMANDER_VORONIN: StringName = &"voronin"
const RABBIT: StringName = COMMANDER_RABBIT
const VEX_COMMANDER: StringName = COMMANDER_VEX
const SHARK_COMMANDER: StringName = COMMANDER_SHARK
const OLD_GAO_COMMANDER: StringName = COMMANDER_GAO

const COMMANDER_CLEARANCES := {
	&"midnight_rabbit": [Army.Tier.LUNATICS, Army.Tier.GUARDS, Army.Tier.BLACK_HAND],
	&"rival": [Army.Tier.LUNATICS, Army.Tier.GUARDS],
	&"vex": [Army.Tier.LUNATICS, Army.Tier.GUARDS],
	&"shark": [Army.Tier.LUNATICS],
	&"old_gao": [Army.Tier.LUNATICS],
}

## BATTLE.md Section 11: Zeroing, Commander Capture, Ransom & Mercenary Bounty Jailbreaks.
const EXECUTION_CLOCK_SECONDS := 180.0
const EXECUTION_TIMER_SECONDS := EXECUTION_CLOCK_SECONDS
const RANSOM_DEMAND_CHANCE := 0.65
const BASE_RANSOM_COST := 50000
const RABBIT_RANSOM_COST := 150000
const RANSOM_HIKE_MULTIPLIER := 1.75
const CLINIC_REVIVAL_FEE := 100000
const MIN_JAILBREAK_BOUNTY := 35000


const INVASION_ORDER: Array[StringName] = [
	&"old_market",
	&"slums",
	&"warehouse_row",
	&"west_end",
	&"north_port",
	&"docks",
	&"riverside",
]

const INVASION_PREREQUISITES: Dictionary = {
	&"slums": &"old_market",
	&"warehouse_row": &"slums",
	&"west_end": &"warehouse_row",
	&"north_port": &"west_end",
	&"docks": &"north_port",
	&"riverside": &"north_port",
}


static func is_open(run: RunState) -> bool:
	return Corners.holds(run, Corners.MAMA_LIN) and not Story.has(run, VEX_FELL)


static func can_invade_district(run: RunState, district_id: StringName) -> bool:
	if district_id == Corners.HOME:
		return is_open(run)
	if not Campaign.is_act_two(run):
		return false
	if district_id == &"slums":
		return true
	var prereq: StringName = INVASION_PREREQUISITES.get(district_id, &"")
	if prereq.is_empty():
		return false
	return Turf.holds(run, prereq) or Corners.held_count(run, district_id) > 0


static func invasion_lock_reason(run: RunState, district_id: StringName) -> String:
	if district_id == Corners.HOME:
		if not Corners.holds(run, Corners.MAMA_LIN):
			return "Buy Mama Lin's corner first"
		return ""
	if not Campaign.is_act_two(run):
		return "Defeat Vex in Old Market first"
	var district := Content.district(district_id)
	if district != null and Travel.is_locked(run, district):
		return "Needs %s rank" % StreetCred.rank_name(district.min_rank)
	var prereq: StringName = INVASION_PREREQUISITES.get(district_id, &"")
	if not prereq.is_empty() and not Turf.holds(run, prereq) and Corners.held_count(run, district_id) <= 0:
		var prev_dist := Content.district(prereq)
		var prev_name := prev_dist.display_name if prev_dist != null else String(prereq)
		return "Hold %s first" % prev_name
	return ""


## A rival corner the player could hit or scout: Old Market's during the war, any other in Act 2 once the district
## is open to the player and invasion progression order has reached it.
static func is_target(run: RunState, corner: CornerDef) -> bool:
	if Corners.holds(run, corner.id):
		return false
	var district_id := Corners.district_of(corner.id)
	if not Turf.is_contested(district_id):
		return false
	if district_id == Corners.HOME:
		return is_open(run)
	var district := Content.district(district_id)
	var gang := Corners.gang_of(corner.id)
	return Campaign.is_act_two(run) \
		and district != null \
		and not Gangs.is_gone(run, gang) \
		and not Travel.is_locked(run, district) \
		and can_invade_district(run, district_id)


static func can_attack(run: RunState, corner: CornerDef) -> bool:
	return run.war_window_open and is_target(run, corner) and Army.reserve(run) > 0 and can_dispatch_march(run)


## BATTLE.md Section 2: Timed War Event Windows.
static func open_war_window(run: RunState, duration: float = DEFAULT_WAR_WINDOW_SECONDS) -> void:
	run.war_window_open = true
	run.war_window_seconds = maxf(0.0, duration)


static func close_war_window(run: RunState) -> void:
	run.war_window_open = false
	run.war_window_seconds = 0.0


static func is_war_window_open(run: RunState) -> bool:
	return run.war_window_open


## BATTLE.md Section 3 & 4: March Lines (max 5 simultaneous dispatches) & Physical Troop Accounting.
static func active_march_count(run: RunState) -> int:
	return run.active_marches.size()


static func can_dispatch_march(run: RunState) -> bool:
	return run.active_marches.size() < MAX_MARCH_LINES


static func total_marching(run: RunState) -> int:
	var sum := 0
	for march: Dictionary in run.active_marches:
		var deploy: Variant = march.get("deployment", {})
		if deploy is Dictionary:
			sum += Army.deployed_count(deploy)
	return sum


## BATTLE.md Section 7: Commander Canon & Command Clearances.
static func is_commander_captured(run: RunState, commander_id: StringName) -> bool:
	if commander_id.is_empty():
		return false
	var entry: Dictionary = run.captured_commanders.get(String(commander_id), {})
	return not entry.is_empty() and str(entry.get("bounty_status", "none")) != "rescued"


static func is_commander_unavailable(run: RunState, commander_id: StringName) -> bool:
	if commander_id.is_empty():
		return false
	if is_commander_captured(run, commander_id):
		return true
	if commander_id == COMMANDER_RABBIT and run.rabbit_cells != RabbitCells.Stage.NONE:
		return true
	for march: Dictionary in run.active_marches:
		if StringName(str(march.get("commander", ""))) == commander_id:
			return true
	return false


static func is_commander_available(run: RunState, commander_id: StringName) -> bool:
	return not is_commander_unavailable(run, commander_id)


static func commander_allows_tier(commander_id: StringName, tier: Army.Tier) -> bool:
	var raw: Array = COMMANDER_CLEARANCES.get(commander_id, [Army.Tier.LUNATICS])
	return raw.has(tier)


## BATTLE.md Section 7A: If Rabbit is captured or hospitalized, syndicate loses clearance to deploy T3 Black Hand on offensive marches.
static func can_deploy_black_hand_offensively(run: RunState, commander_id: StringName = COMMANDER_RABBIT) -> bool:
	if is_commander_unavailable(run, COMMANDER_RABBIT):
		return false
	var allowed := commander_allowed_tiers(run, commander_id)
	return allowed.has(Army.Tier.BLACK_HAND)


static func commander_allowed_tiers(run: RunState, commander_id: StringName) -> Array[Army.Tier]:
	if commander_id.is_empty():
		var default_tiers: Array[Army.Tier] = [Army.Tier.LUNATICS, Army.Tier.GUARDS]
		if not is_commander_unavailable(run, COMMANDER_RABBIT):
			default_tiers.append(Army.Tier.BLACK_HAND)
		return default_tiers
	if is_commander_unavailable(run, commander_id):
		return []
	var raw: Array = COMMANDER_CLEARANCES.get(commander_id, [Army.Tier.LUNATICS])
	var tiers: Array[Army.Tier] = []
	for t: int in raw:
		if t == Army.Tier.BLACK_HAND and is_commander_unavailable(run, COMMANDER_RABBIT):
			continue
		tiers.append(t as Army.Tier)
	return tiers


static func filter_deployment_for_commander(run: RunState, deployment: Dictionary, commander_id: StringName) -> Dictionary:
	var allowed := commander_allowed_tiers(run, commander_id)
	var cap := Army.march_capacity(run, commander_id)
	var left := mini(cap, Army.reserve(run))
	var filtered := {}
	for tier in Army.DEPLOY_ORDER:
		if not allowed.has(tier):
			continue
		var wanted := int(deployment.get(tier, 0))
		var taken := mini(left, mini(wanted, Army.count(run, tier)))
		if taken > 0:
			filtered[tier] = taken
			left -= taken
	return filtered


## BATTLE.md Section 2 & 3: Physical transit time based on district distance, supporting staggered arrivals.
static func transit_time(run: RunState, origin_district: StringName, target_corner_id: StringName) -> float:
	var target_dist := Corners.district_of(target_corner_id)
	var from_id := origin_district if not origin_district.is_empty() else run.district_id
	if from_id == target_dist or target_dist.is_empty():
		return BASE_TRANSIT_SECONDS
	var from_def := Content.district(from_id)
	var to_def := Content.district(target_dist)
	if from_def == null or to_def == null:
		return BASE_TRANSIT_SECONDS * 2.0
	var dist_factor := from_def.map_position.distance_to(to_def.map_position)
	return snappedf(BASE_TRANSIT_SECONDS + dist_factor * 45.0, 0.5)


## Dispatches a march column on one of the 5 simultaneous dispatch lines (BATTLE.md Section 3).
static func dispatch_march(run: RunState, corner_id: StringName, deployment: Dictionary, commander_id: StringName = &"", origin_or_stagger: Variant = &"") -> Dictionary:
	var corner := Corners.find(corner_id)
	if corner == null or not can_attack(run, corner):
		return {}
	var valid_deploy := filter_deployment_for_commander(run, deployment, commander_id)
	if Army.deployed_count(valid_deploy) <= 0:
		return {}
	var from_dist: StringName = run.district_id
	var stagger_offset := 0.0
	if origin_or_stagger is float or origin_or_stagger is int:
		stagger_offset = maxf(0.0, float(origin_or_stagger))
	elif not str(origin_or_stagger).is_empty():
		from_dist = StringName(str(origin_or_stagger))
	var eta := transit_time(run, from_dist, corner_id) + stagger_offset
	# Stagger arrival if another march is already targeting the same corner
	for existing: Dictionary in run.active_marches:
		if StringName(str(existing.get("target_corner", ""))) == corner_id and str(existing.get("state", "")) == "marching":
			eta = maxf(eta, float(existing.get("eta_seconds", 0.0)) + 3.0)
	var march_index := run.active_marches.size() + 1
	var march := {
		"id": march_index,
		"origin": String(from_dist),
		"target_corner": String(corner_id),
		"deployment": valid_deploy,
		"commander": String(commander_id),
		"state": "marching",
		"status": "marching",
		"eta_seconds": eta,
		"total_transit_seconds": eta,
		"reinforcements_added": 0,
		"morale": 1.0,
	}
	run.active_marches.append(march)
	return march


## Ticks active marches, reinforcement clocks, and war window timers (BATTLE.md Section 2 & 5).
static func tick_marches(run: RunState, delta: float) -> Array[Dictionary]:
	var arrived: Array[Dictionary] = []
	if run.war_window_seconds > 0.0:
		run.war_window_seconds = maxf(0.0, run.war_window_seconds - delta)
		if run.war_window_seconds <= 0.0:
			run.war_window_open = false
	var remaining: Array[Dictionary] = []
	for march: Dictionary in run.active_marches:
		var state := str(march.get("state", march.get("status", "marching")))
		if state == "marching":
			march["eta_seconds"] = maxf(0.0, float(march.get("eta_seconds", 0.0)) - delta)
			var corner := Corners.find(StringName(str(march.get("target_corner", ""))))
			if corner != null and not Corners.holds(run, corner.id):
				var added := maxi(1, roundi(corner.defenders * REINFORCEMENT_RATE_PER_SECOND * delta))
				var current_def := defenders(run, corner)
				var next_def := mini(Rivals.max_garrison(corner), current_def + added)
				march["reinforcements_added"] = int(march.get("reinforcements_added", 0)) + (next_def - current_def)
				run.corner_defenders[String(corner.id)] = next_def
			if float(march["eta_seconds"]) <= 0.0:
				march["state"] = "at_gate"
				march["status"] = "at_gate"
				arrived.append(march)
			remaining.append(march)
		elif state == "returning":
			march["eta_seconds"] = maxf(0.0, float(march.get("eta_seconds", 0.0)) - delta)
			if float(march["eta_seconds"]) > 0.0:
				remaining.append(march)
		else:
			remaining.append(march)
	run.active_marches = remaining
	return arrived


## BATTLE.md Section 5: Decision at the Gate (Commit, Pull Back, or Stagger Second Wave).
static func resolve_gate_decision(run: RunState, march_id: Variant, decision: GateDecision, roll: float = 0.5, fate: float = 0.5) -> Dictionary:
	var idx := -1
	var id_str := str(march_id)
	for i in run.active_marches.size():
		if str(run.active_marches[i].get("id", "")) == id_str:
			idx = i
			break
	if idx < 0:
		return {}
	var march: Dictionary = run.active_marches[idx]
	var corner_id := StringName(str(march.get("target_corner", "")))
	var commander_id := StringName(str(march.get("commander", "")))
	match decision:
		GateDecision.PULL_BACK:
			var penalty := mini(run.cash, PULL_BACK_CASH_PENALTY)
			run.cash -= penalty
			StreetCred.add(run, PULL_BACK_CRED_PENALTY)
			run.active_marches.remove_at(idx)
			return {
				"decision": "pull_back",
				"aborted": true,
				"corner": String(corner_id),
				"cash_penalty": penalty,
				"cred_penalty": PULL_BACK_CRED_PENALTY,
				"morale": maxf(0.0, float(march.get("morale", 1.0)) - 0.25),
			}
		GateDecision.STAGGER:
			var has_second_wave := false
			for other: Dictionary in run.active_marches:
				if str(other.get("id", "")) != id_str and StringName(str(other.get("target_corner", ""))) == corner_id:
					has_second_wave = true
					break
			if not has_second_wave or float(march.get("morale", 1.0)) < STAGGER_MIN_MORALE:
				return { "decision": "stagger_failed", "staggered": false, "reason": "Requires an en-route second wave and sufficient squad morale." }
			march["state"] = "holding"
			march["status"] = "holding"
			march["morale"] = maxf(0.0, float(march.get("morale", 1.0)) - 0.10)
			return {
				"decision": "staggered",
				"staggered": true,
				"corner": String(corner_id),
				"morale": march["morale"],
			}
		GateDecision.COMMIT:
			# Combine any staggered waves waiting at the same corner gate
			var combined_deploy: Dictionary = (march.get("deployment", {}) as Dictionary).duplicate()
			var remaining_marches: Array[Dictionary] = []
			for m: Dictionary in run.active_marches:
				var m_id := str(m.get("id", ""))
				var m_corner := StringName(str(m.get("target_corner", "")))
				var m_state := str(m.get("state", m.get("status", "")))
				if m_id == id_str or (m_corner == corner_id and m_state in ["staggered", "holding", "at_gate"]):
					if m_id != id_str:
						var extra: Dictionary = m.get("deployment", {})
						for tier: int in extra:
							combined_deploy[tier] = int(combined_deploy.get(tier, 0)) + int(extra[tier])
				else:
					remaining_marches.append(m)
			run.active_marches = remaining_marches
			var res := attack(run, corner_id, combined_deploy, roll, fate, commander_id)
			res["decision"] = "commit"
			return res
	return {}


## BATTLE.md Section 10: Decisive Combat Resolution (No Ties).
## A +-1 tie-breaker resolves dead heats on the spot; defenders hold ground on dead heats.
static func resolve_decisive_clash(attacker_power: float, defender_power: float) -> Dictionary:
	var diff := attacker_power - defender_power
	var tie_broken := false
	if is_zero_approx(diff):
		diff = -1.0
		tie_broken = true
	var attacker_won := diff > 0.0
	return {
		"won": attacker_won,
		"attacker_won": attacker_won,
		"defender_held": not attacker_won,
		"margin": diff,
		"tie_broken": tie_broken,
	}


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
	var factor := STRONGHOLD_FACTOR if corner.stronghold else 1.0
	if corner.stronghold and run.sniper_active:
		factor = 1.0
	return defenders(run, corner) * per_man * factor


## Fights for a corner with the deployment from Army.deployment. roll and fate are in [0, 1): roll is the luck of the
## day, fate how deadly the hits turn out. Returns { corner, won, ended, deployed, losses, dead, wounded, defenders,
## defenders_lost }, empty when the attack cannot happen. losses maps a tier to its { dead, wounded }.
static func attack(run: RunState, corner_id: StringName, deployment: Dictionary, roll: float, fate: float, commander_id: StringName = &"") -> Dictionary:
	var corner := Corners.find(corner_id)
	if corner == null or not can_attack(run, corner) or Army.deployed_count(deployment) <= 0:
		return {}
	var luck_mult := Odds.bell_from_roll(roll, 1.0 - LUCK, 1.0, 1.0 + LUCK)
	var mine := Army.power(run, deployment) * luck_mult
	var theirs := enemy_power(run, corner)
	run.sniper_active = false
	var clash := resolve_decisive_clash(mine, theirs)
	var won := bool(clash.attacker_won)
	var overwhelmed := not won and not commander_id.is_empty() and theirs >= maxf(mine, 1.0) * 8.0
	var losses: Dictionary
	if overwhelmed:
		losses = Army.split_casualties_by_role(deployment, Army.deployed_count(deployment), false)
	else:
		var hit_share := WIN_HIT_SHARE * minf(1.0, theirs / maxf(mine, 1.0)) if won else LOSS_HIT_SHARE
		var fate_offset := Odds.bell_from_roll(fate, -0.5 * FATE_SWING, 0.0, 0.5 * FATE_SWING)
		var death_share := (WIN_DEATH_SHARE if won else LOSS_DEATH_SHARE) + fate_offset
		losses = Army.casualties(deployment, hit_share, death_share)
	Hospital.admit(run, losses)
	var dead_total := Army.sum_losses(losses, "dead")
	var wounded_total := Army.sum_losses(losses, "wounded")
	var zeroed := is_squad_zeroed(deployment, losses)
	var gang := Corners.gang_of(corner_id)
	var captured := false
	if zeroed and not commander_id.is_empty():
		var gang_id := gang.id if gang != null else VEX_GANG
		capture_commander(run, commander_id, gang_id, fate)
		captured = true
	var result := {
		"corner": String(corner_id),
		"won": won,
		"ended": false,
		"deployed": deployment,
		"losses": losses,
		"dead": dead_total,
		"wounded": wounded_total,
		"defenders": defenders(run, corner),
		"zeroed": zeroed,
		"commander": String(commander_id),
		"commander_captured": captured,
	}
	var defenders_lost: int
	if won:
		defenders_lost = int(result.defenders)
		_fallback_survivors(run, corner, int(result.defenders))
		Corners.take(run, corner_id)
		run.corner_defenders.erase(String(corner_id))
		run.scouted.erase(String(corner_id))
		if gang != null:
			Rivals.add_anger(run, gang, 2.0 if corner.stronghold else 1.0)
	else:
		defenders_lost = roundi(int(result.defenders) * DEFENDERS_BLED)
		run.corner_defenders[String(corner_id)] = int(result.defenders) - defenders_lost
		Story.mark(run, LOST_ONCE)
	Army.take_losses(run, deployment, losses)
	Heat.add(run, ATTACK_HEAT)
	Heat.activate_frenzy(run, 300.0)
	result.defenders_lost = defenders_lost
	if won and is_open(run) and Corners.held_count(run, Corners.HOME) == Corners.of(Corners.HOME).size():
		end_war(run)
		result.ended = true
	elif won:
		Turf.check_victory(run)
	return result


## Escaping defenders from a lost corner fall back to another corner the gang still holds in that district.
static func _fallback_survivors(run: RunState, lost_corner: CornerDef, original_defenders: int) -> void:
	if not Campaign.is_act_two(run) or original_defenders <= 0:
		return
	var gang := Corners.gang_of(lost_corner.id)
	var district_id := Corners.district_of(lost_corner.id)
	var retreat_targets: Array[CornerDef] = []
	for other in Corners.of(district_id):
		if other.id != lost_corner.id and not Corners.holds(run, other.id) and Corners.gang_of(other.id) == gang:
			retreat_targets.append(other)
	if retreat_targets.is_empty():
		return
	var target := retreat_targets[0]
	var retreated := maxi(1, roundi(original_defenders * 0.2))
	run.corner_defenders[String(target.id)] = mini(Rivals.max_garrison(target), defenders(run, target) + retreated)


## Reconciles the live tactical battle outcome (from SUPPRESS, RALLY, BLITZ, or morale routs) back into run state.
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
		result.defenders_lost = int(result.defenders)
		_fallback_survivors(run, corner, int(result.defenders))
		Corners.take(run, corner_id)
		run.corner_defenders.erase(String(corner_id))
		run.scouted.erase(String(corner_id))
		var gang := Corners.gang_of(corner_id)
		if gang != null:
			Rivals.add_anger(run, gang, 2.0 if corner.stronghold else 1.0)
		if is_open(run) and Corners.held_count(run, Corners.HOME) == Corners.of(Corners.HOME).size():
			end_war(run)
			result.ended = true
		else:
			Turf.check_victory(run)


## Vex kneels. Old Market is the player's for good, Moreau starts her file, and Act 2 opens. Vex keeps her other
## districts. On the failure branch the Shark's book burns with her, so the doubled debt is gone.
static func end_war(run: RunState) -> void:
	Story.mark(run, VEX_FELL)
	Story.mark(run, Moreau.WATCHLIST)
	if Loan.is_with_vex(run):
		Story.mark(run, BOOK_BURNED)
		run.debt = 0
		run.career = true


## BATTLE.md Section 11A: If an attacking squad takes 100% casualties, the march is Zeroed.
static func is_squad_zeroed(deployment: Dictionary, losses: Dictionary) -> bool:
	var sent := Army.deployed_count(deployment)
	if sent <= 0:
		return false
	var total_losses := Army.sum_losses(losses, "dead") + Army.sum_losses(losses, "wounded")
	return total_losses >= sent


## BATTLE.md Section 11B: Captor probability check (Demand Ransom vs Refuse Negotiations) and execution countdown clock.
static func capture_commander(run: RunState, commander_id: StringName, gang_id: StringName, roll: float = 0.5) -> Dictionary:
	if commander_id.is_empty():
		return {}
	var demands_ransom := roll < RANSOM_DEMAND_CHANCE
	var base_ransom := RABBIT_RANSOM_COST if commander_id == COMMANDER_RABBIT else BASE_RANSOM_COST
	var ransom_val := base_ransom if demands_ransom else 0
	var entry := {
		"commander": String(commander_id),
		"gang": String(gang_id),
		"stance": "ransom" if demands_ransom else "refused",
		"ransom": ransom_val,
		"ransom_demanded": demands_ransom,
		"ransom_amount": ransom_val,
		"escalated": false,
		"seconds_left": EXECUTION_CLOCK_SECONDS,
		"bounty_posted": 0,
		"bounty_status": "none",
	}
	run.captured_commanders[String(commander_id)] = entry
	return entry


## BATTLE.md Section 11B: Captors holding high-value commanders (especially Rabbit) may hike the ransom mid-clock.
static func escalate_ransom(run: RunState, commander_id: StringName) -> int:
	var key := String(commander_id)
	if not run.captured_commanders.has(key):
		return 0
	var entry: Dictionary = run.captured_commanders[key]
	if not bool(entry.get("ransom_demanded", false)) or bool(entry.get("escalated", false)):
		return int(entry.get("ransom_amount", 0))
	var mult := 2.0 if commander_id == COMMANDER_RABBIT else RANSOM_HIKE_MULTIPLIER
	var hiked := roundi(float(entry.get("ransom_amount", BASE_RANSOM_COST)) * mult)
	entry["ransom"] = hiked
	entry["ransom_amount"] = hiked
	entry["escalated"] = true
	run.captured_commanders[key] = entry
	return hiked


static func pay_commander_ransom(run: RunState, commander_id: StringName) -> bool:
	var key := String(commander_id)
	if not run.captured_commanders.has(key):
		return false
	var entry: Dictionary = run.captured_commanders[key]
	if not bool(entry.get("ransom_demanded", false)) or str(entry.get("bounty_status", "none")) == "executed":
		return false
	var amount := int(entry.get("ransom_amount", 0))
	if amount <= 0 or run.cash < amount:
		return false
	run.cash -= amount
	run.captured_commanders.erase(key)
	return true


## BATTLE.md Section 11C: Underworld Bounty Jailbreaks (Mercenaries may extract, ignore if heavily defended, or demand a hike).
static func post_jailbreak_bounty(run: RunState, commander_id: StringName, bounty: int, roll: float = 0.5) -> Dictionary:
	var key := String(commander_id)
	if not run.captured_commanders.has(key) or bounty < MIN_JAILBREAK_BOUNTY or run.cash < bounty:
		return { "ok": false, "outcome": "invalid" }
	var entry: Dictionary = run.captured_commanders[key]
	if str(entry.get("bounty_status", "none")) == "executed":
		return { "ok": false, "outcome": "already_executed" }
	run.cash -= bounty
	entry["bounty_posted"] = int(entry.get("bounty_posted", 0)) + bounty
	var total_bounty := int(entry["bounty_posted"])
	if roll < 0.45 and total_bounty >= MIN_JAILBREAK_BOUNTY:
		run.captured_commanders.erase(key)
		return { "ok": true, "outcome": "rescued", "commander": key }
	elif roll < 0.75:
		var hike_needed := roundi(float(total_bounty) * 0.5)
		entry["bounty_status"] = "demanded_hike"
		entry["bounty_hike_needed"] = hike_needed
		run.captured_commanders[key] = entry
		return { "ok": true, "outcome": "demanded_hike", "hike_needed": hike_needed }
	else:
		entry["bounty_status"] = "ignored"
		run.captured_commanders[key] = entry
		return { "ok": true, "outcome": "ignored" }


## Ticks execution countdown clocks for captured commanders; executes if clock hits zero (BATTLE.md Section 11C).
static func tick_captured_commanders(run: RunState, delta: float) -> Array[String]:
	var executed: Array[String] = []
	for key: String in run.captured_commanders.keys():
		var entry: Dictionary = run.captured_commanders[key]
		if str(entry.get("bounty_status", "none")) == "executed":
			continue
		var before := float(entry.get("seconds_left", EXECUTION_CLOCK_SECONDS))
		var after := maxf(0.0, before - delta)
		entry["seconds_left"] = after
		# Mid-clock ransom escalation for high-value commanders (especially Rabbit)
		if bool(entry.get("ransom_demanded", false)) and not bool(entry.get("escalated", false)) and after <= EXECUTION_CLOCK_SECONDS * 0.5 and after > 0.0:
			escalate_ransom(run, StringName(key))
		if after <= 0.0:
			entry["bounty_status"] = "executed"
			entry["ransom_demanded"] = false
			run.captured_commanders[key] = entry
			executed.append(key)
		else:
			run.captured_commanders[key] = entry
	return executed


## Revives an executed commander via dark-market clinic fees (BATTLE.md Section 11C).
static func revive_executed_commander(run: RunState, commander_id: StringName) -> bool:
	var key := String(commander_id)
	if not run.captured_commanders.has(key):
		return false
	var entry: Dictionary = run.captured_commanders[key]
	if str(entry.get("bounty_status", "")) != "executed" or run.cash < CLINIC_REVIVAL_FEE:
		return false
	run.cash -= CLINIC_REVIVAL_FEE
	run.captured_commanders.erase(key)
	return true


static func sanitize_defenders(source: Variant) -> Dictionary:
	var clean := {}
	if source is Dictionary:
		for key: Variant in source:
			var corner := Corners.find(StringName(str(key)))
			if corner != null:
				clean[str(key)] = clampi(int(source[key]), 0, Rivals.max_garrison(corner))
	return clean


static func sanitize_marches(source: Variant) -> Array[Dictionary]:
	var clean: Array[Dictionary] = []
	if not source is Array:
		return clean
	for item: Variant in source:
		if not item is Dictionary or clean.size() >= MAX_MARCH_LINES:
			continue
		var corner_id := StringName(str(item.get("target_corner", "")))
		if Corners.find(corner_id) == null:
			continue
		var deploy_raw: Variant = item.get("deployment", {})
		var deploy_clean := {}
		if deploy_raw is Dictionary:
			for k: Variant in deploy_raw:
				var tier := int(str(k))
				var amt := int(deploy_raw[k])
				if tier >= 0 and tier < Army.Tier.size() and amt > 0:
					deploy_clean[tier] = amt
		if deploy_clean.is_empty():
			continue
		clean.append({
			"id": str(item.get("id", "march_%s" % String(corner_id))),
			"origin": str(item.get("origin", String(Corners.HOME))),
			"target_corner": String(corner_id),
			"deployment": deploy_clean,
			"commander": str(item.get("commander", "")),
			"state": str(item.get("state", "marching")),
			"eta_seconds": maxf(0.0, float(item.get("eta_seconds", 0.0))),
			"total_transit_seconds": maxf(1.0, float(item.get("total_transit_seconds", BASE_TRANSIT_SECONDS))),
			"reinforcements_added": maxi(0, int(item.get("reinforcements_added", 0))),
			"morale": clampf(float(item.get("morale", 1.0)), 0.0, 1.0),
		})
	return clean


static func sanitize_captured(source: Variant) -> Dictionary:
	var clean := {}
	if not source is Dictionary:
		return clean
	for k: Variant in source:
		var entry: Variant = source[k]
		if not entry is Dictionary:
			continue
		var cmd := str(k)
		clean[cmd] = {
			"commander": cmd,
			"gang": str(entry.get("gang", String(VEX_GANG))),
			"ransom_demanded": bool(entry.get("ransom_demanded", false)),
			"ransom_amount": maxi(0, int(entry.get("ransom_amount", 0))),
			"escalated": bool(entry.get("escalated", false)),
			"seconds_left": maxf(0.0, float(entry.get("seconds_left", 0.0))),
			"bounty_posted": maxi(0, int(entry.get("bounty_posted", 0))),
			"bounty_status": str(entry.get("bounty_status", "none")),
		}
	return clean
