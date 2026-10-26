class_name Heists

## Big one-off jobs for a career run. Each needs a crew and a district, then rests for a few days.
## run.heist_cooldowns maps a heist id to the first day it can be pulled again.

enum Result { OK, NOT_CAREER, RANK_TOO_LOW, MISSING_CREW, COOLDOWN, WRONG_DISTRICT }

const COOLDOWN_DAYS := 3
const FAILED_HEAT := 20
const CREW_LOSS_CHANCE := 0.3
## Added for every required role on the crew.
const ROLE_BONUS := 0.1
## Added when the family running the district treats the player as Family and is not the target.
const FAMILY_BONUS := 0.15
const MAX_CHANCE := 0.9


static func check(run: RunState, heist: HeistDef) -> Result:
	if not Campaign.is_act_two(run):
		return Result.NOT_CAREER
	if StreetCred.rank(run) < heist.min_rank:
		return Result.RANK_TOO_LOW
	if not missing_roles(run, heist).is_empty():
		return Result.MISSING_CREW
	if days_until_ready(run, heist) > 0:
		return Result.COOLDOWN
	if run.district_id != heist.district_id:
		return Result.WRONG_DISTRICT
	return Result.OK


static func missing_roles(run: RunState, heist: HeistDef) -> Array[StringName]:
	var missing: Array[StringName] = []
	for role_id in heist.required_roles:
		if not Crew.has(run, role_id):
			missing.append(role_id)
	return missing


static func days_until_ready(run: RunState, heist: HeistDef) -> int:
	return maxi(0, int(run.heist_cooldowns.get(heist.id, 0)) - run.day)


## The take grows with every rank above the one that opens the heist.
static func payout(run: RunState, heist: HeistDef) -> int:
	var ranks_above := maxi(0, StreetCred.rank(run) - heist.min_rank)
	return roundi(heist.payout * (1.0 + PayScale.RANK_GROWTH * ranks_above))


static func success_chance(run: RunState, heist: HeistDef) -> float:
	var hired_roles := heist.required_roles.size() - missing_roles(run, heist).size()
	var chance := heist.base_chance + ROLE_BONUS * hired_roles + Skills.fight_bonus(run)
	var home_family := _home_family(heist.district_id)
	if home_family != null and home_family.id != heist.target_family and Families.tier(run, home_family.id) == Families.Tier.FAMILY:
		chance += FAMILY_BONUS
	return clampf(chance, 0.0, MAX_CHANCE)


## Returns { success, payout, lost_role }. lost_role is the required role that was caught, empty when none.
## Both rolls must be in the range [0, 1). Nothing happens when check() does not pass.
static func attempt(run: RunState, heist: HeistDef, roll: float, crew_roll: float) -> Dictionary:
	var outcome := { "success": false, "payout": 0, "lost_role": "" }
	if check(run, heist) != Result.OK:
		return outcome
	var chance := success_chance(run, heist)
	run.heist_cooldowns[heist.id] = run.day + COOLDOWN_DAYS

	if roll < chance:
		var take := payout(run, heist)
		run.cash += take
		run.profit += take
		Heat.add(run, heist.heat)
		StreetCred.add(run, heist.cred)
		if not heist.target_family.is_empty():
			Families.shift(run, heist.target_family, -heist.standing_loss)
		outcome["success"] = true
		outcome["payout"] = take
		return outcome

	Heat.add(run, FAILED_HEAT)
	if not Encounters.has_pending(run):
		run.pending_encounter = Encounters.police_stop(run)
	if crew_roll < CREW_LOSS_CHANCE and not heist.required_roles.is_empty():
		var count := heist.required_roles.size()
		var index := clampi(floori(crew_roll / CREW_LOSS_CHANCE * count), 0, count - 1)
		var lost_role := heist.required_roles[index]
		Crew.fire(run, lost_role)
		outcome["lost_role"] = String(lost_role)
	return outcome


static func _home_family(district_id: StringName) -> FamilyDef:
	for family in Content.families():
		if family.home_districts.has(district_id):
			return family
	return null
