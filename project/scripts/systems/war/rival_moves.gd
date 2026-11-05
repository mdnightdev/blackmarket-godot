class_name RivalMoves

## Stochastic rival AI decision-making. Each active gang evaluates candidate moves using personality weights
## (anger, greed, cunning) and samples its play via Gaussian utility noise and Softmax exploration (see Odds).

enum Move {
	RECRUIT_AND_ARM,
	RETAKE_CORNER,
	HIT_DELIVERY,
	RAID_FRONT,
	BUY_COP,
	BAIT_TRAP,
	RAID_HQ,
}

const COP_BRIBE_COST := 25000
const COP_BRIBE_DAYS := 3
const COP_STOP_BONUS := 0.15

const PERSONALITIES := {
	&"vex": { "anger": 1.5, "greed": 1.0, "cunning": 0.6 },
	&"baby": { "anger": 1.4, "greed": 1.2, "cunning": 0.9 },
	&"jackal": { "anger": 1.0, "greed": 1.5, "cunning": 0.8 },
	&"celeste": { "anger": 0.7, "greed": 1.2, "cunning": 1.5 },
	&"lucyferek": { "anger": 1.2, "greed": 1.3, "cunning": 1.4 },
}
const DEFAULT_PERSONALITY := { "anger": 1.0, "greed": 1.0, "cunning": 1.0 }


static func personality(gang: GangDef) -> Dictionary:
	if gang == null:
		return DEFAULT_PERSONALITY
	return PERSONALITIES.get(gang.id, DEFAULT_PERSONALITY)


## Evaluates candidate moves for the gang and returns Array of { move, score, target }.
static func candidates(run: RunState, gang: GangDef) -> Array[Dictionary]:
	var list: Array[Dictionary] = [
		{ "move": Move.RECRUIT_AND_ARM, "score": 1.0, "target": &"" }
	]
	if gang == null or Gangs.is_gone(run, gang):
		return list
	var weights := personality(gang)
	var anger_weight := float(weights.anger)
	var greed_weight := float(weights.greed)
	var cunning_weight := float(weights.cunning)
	var gang_anger := Rivals.anger(run, gang)

	if RivalStrike.can_strike(run, gang):
		var best_corner: CornerDef = null
		var best_retake := 0.0
		for corner in RivalStrike.targets(run, gang):
			var from := RivalStrike.source(run, gang, corner)
			if from == null:
				continue
			var sent := RivalStrike.raiders(run, from)
			var raider_power := sent * Rivals.power_per_man(run, gang)
			var garrison_pow := Corners.garrison_power(run, corner)
			if garrison_pow <= 0.0 or raider_power >= garrison_pow * 1.25:
				var value_ratio := float(corner.daily_cut()) / maxf(garrison_pow, 100.0)
				var retake_score := clampf(value_ratio * (1.0 + gang_anger * 0.4) * anger_weight, 0.5, 4.0)
				if retake_score > best_retake:
					best_retake = retake_score
					best_corner = corner
		if best_corner != null:
			list.append({ "move": Move.RETAKE_CORNER, "score": best_retake, "target": best_corner.id })

	if is_hq_vulnerable(run):
		var hq_score := clampf((1.8 + gang_anger * 0.25) * (anger_weight + cunning_weight) * 0.5, 1.0, 4.5)
		list.append({ "move": Move.RAID_HQ, "score": hq_score, "target": Corners.HOME })

	if _has_delivery_in_turf(run, gang):
		var hit_score := 1.45 * greed_weight
		list.append({ "move": Move.HIT_DELIVERY, "score": hit_score, "target": &"" })

	var vulnerable_front := _front_in_turf(run, gang)
	if not vulnerable_front.is_empty():
		var raid_score := 1.35 * greed_weight
		list.append({ "move": Move.RAID_FRONT, "score": raid_score, "target": StringName(str(vulnerable_front.get("district", ""))) })

	if Rivals.chest(run, gang) >= COP_BRIBE_COST and Rivals.cop_bribe_until(run, gang) <= run.day:
		var chest_factor := clampf(float(Rivals.chest(run, gang)) / 150000.0, 0.2, 1.5)
		var cop_score := (0.9 + chest_factor * 0.5) * cunning_weight
		list.append({ "move": Move.BUY_COP, "score": cop_score, "target": &"" })

	var held_corners := Rivals.corners(run, gang)
	if held_corners.size() >= 2:
		var bait_target := held_corners[0]
		for c in held_corners:
			if War.defenders(run, c) < War.defenders(run, bait_target):
				bait_target = c
		var bait_score := (0.85 + gang_anger * 0.15) * cunning_weight
		list.append({ "move": Move.BAIT_TRAP, "score": bait_score, "target": bait_target.id })

	return list


## Samples one move using Softmax + Gaussian utility noise so rival behavior is strategic yet unpredictable.
static func pick_move(run: RunState, gang: GangDef, rng: RandomNumberGenerator) -> Dictionary:
	var options := candidates(run, gang)
	var scores: Array[float] = []
	for opt in options:
		scores.append(float(opt.score))
	var idx := Odds.softmax_pick(rng, scores, 0.55, 0.22)
	return options[clampi(idx, 0, options.size() - 1)]


## Executes the chosen move and returns a notice dictionary (empty when silent).
static func execute_move(run: RunState, gang: GangDef, picked: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var move_type := int(picked.get("move", Move.RECRUIT_AND_ARM)) as Move
	match move_type:
		Move.RETAKE_CORNER:
			var target := Corners.find(StringName(str(picked.get("target", ""))))
			if target != null and not Encounters.has_pending(run):
				var from := RivalStrike.source(run, gang, target)
				if from != null:
					var sent := RivalStrike.raiders(run, from)
					run.pending_encounter = RivalStrike.start(run, gang, target, from, sent)
			return {}
		Move.BUY_COP:
			var current_chest := Rivals.chest(run, gang)
			if current_chest >= COP_BRIBE_COST:
				var entry := Rivals.state(run, gang)
				entry["chest"] = current_chest - COP_BRIBE_COST
				entry["cop_bribe_until"] = run.day + COP_BRIBE_DAYS
				run.rivals[gang.id] = entry
				return {
					"line": "%s put the local beat on their payroll." % gang.crew_name,
					"hint": "Police stops are heavier on %s turf for %d days." % [gang.display_name, COP_BRIBE_DAYS],
				}
		Move.BAIT_TRAP:
			var corner := Corners.find(StringName(str(picked.get("target", ""))))
			if corner != null and not Corners.holds(run, corner.id):
				var boost := roundi(corner.defenders * Odds.bell(rng, 0.25, 0.45, 0.75))
				run.corner_defenders[String(corner.id)] = mini(Rivals.max_garrison(corner), War.defenders(run, corner) + boost)
				Rivals.set_bait_corner(run, gang, corner.id)
			return {}
		Move.RAID_FRONT:
			var front := _front_in_turf(run, gang)
			if not front.is_empty():
				front["closed_until"] = maxi(int(front.get("closed_until", 0)), run.day + 1)
				var def := Businesses.definition(front)
				var bname := def.display_name if def != null else "front"
				return {
					"line": "%s shook down your %s and forced the shutters down for today." % [gang.crew_name, bname.to_lower()],
					"hint": "Post stronger garrisons or drive %s out of the district." % gang.display_name,
				}
		Move.HIT_DELIVERY:
			if Smuggling.is_carrying(run):
				Heat.add(run, 6)
				return {
					"line": "%s spotters tipped the docks on your crate route." % gang.crew_name,
					"hint": "+6 heat while crossing %s turf." % gang.display_name,
				}
		Move.RECRUIT_AND_ARM:
			if int(run.rival_ransomware.get(gang.id, 0)) > run.day:
				return {
					"line": "%s recruit pool and communications remain locked by ransomware." % gang.crew_name,
					"hint": "No enemy reinforcements recruited today.",
				}
			var held := Rivals.corners(run, gang)
			if not held.is_empty():
				var pool := roundi((100.0 + 120.0 * held.size()) * Odds.bell(rng, 0.75, 1.0, 1.35))
				var per_corner := maxi(1, floori(float(pool) / held.size()))
				for c in held:
					run.corner_defenders[String(c.id)] = mini(Rivals.max_garrison(c), War.defenders(run, c) + per_corner)
		Move.RAID_HQ:
			if is_hq_vulnerable(run):
				return execute_hq_raid(run, gang)
	return {}


## True when the player's Headquarters / home reserve is left undefended while marching (BATTLE.md Section 4).
static func is_hq_vulnerable(run: RunState) -> bool:
	if run == null:
		return false
	if Army.reserve(run) > 0:
		return false
	var home_garrison := 0
	for c in Corners.of(Corners.HOME):
		if Corners.holds(run, c.id):
			home_garrison += Corners.garrison(run, c.id)
	return home_garrison <= 0 and (War.total_marching(run) > 0 or Corners.total_garrisoned(run) > 0)


## Counter-raids an undefended player HQ: burns front businesses, destroys armory weapons, and loots cash reserves.
static func execute_hq_raid(run: RunState, gang: GangDef) -> Dictionary:
	var looted_cash := roundi(run.cash * 0.20)
	run.cash = maxi(0, run.cash - looted_cash)
	var destroyed_weapons := 0
	for grade: int in [Armory.Grade.MILITARY, Armory.Grade.RIFLE, Armory.Grade.HANDGUN, Armory.Grade.BLADE]:
		var stock := Armory.count(run, grade as Armory.Grade)
		if stock > 0:
			var lost := maxi(1, roundi(stock * 0.25))
			Armory.lose(run, grade as Armory.Grade, lost)
			destroyed_weapons += lost
	var burned_fronts := 0
	for entry in run.businesses:
		if Businesses.is_open(run, entry):
			entry["closed_until"] = maxi(int(entry.get("closed_until", 0)), run.day + 2)
			burned_fronts += 1
			break
	var crew_label := gang.crew_name if gang != null else "Rival raiders"
	return {
		"line": "%s counter-raided your undefended HQ! Looted %s, smashed %d weapons, and torched %d front." % [
			crew_label, Format.money(looted_cash), destroyed_weapons, burned_fronts
		],
		"hint": "Keep troops in your Home Reserve or garrison your HQ before launching full-scale marches.",
		"looted_cash": looted_cash,
		"destroyed_weapons": destroyed_weapons,
		"burned_fronts": burned_fronts,
	}


## Runs one stochastic move per active gang in Act 2 and returns any morning notices.
static func morning(run: RunState, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var notices: Array[Dictionary] = []
	if not Campaign.is_act_two(run):
		return notices
	for gang in Gangs.confronting(run):
		var chosen := pick_move(run, gang, rng)
		var notice := execute_move(run, gang, chosen, rng)
		if not notice.is_empty():
			notices.append(notice)
	return notices


## True when the owning rival has set a hidden bait trap on this corner.
static func is_baited(run: RunState, corner_id: StringName) -> bool:
	var gang := Corners.gang_of(corner_id)
	if gang == null or Gangs.is_gone(run, gang) or Corners.holds(run, corner_id):
		return false
	return Rivals.bait_corner(run, gang) == corner_id


## Extra police stop chance in a district when an owning rival has bribed local cops.
static func cop_bribe_bonus(run: RunState, district_id: StringName) -> float:
	for gang in Gangs.owners(district_id):
		if not Gangs.is_gone(run, gang) and Rivals.cop_bribe_until(run, gang) > run.day:
			return COP_STOP_BONUS
	return 0.0


static func _has_delivery_in_turf(run: RunState, gang: GangDef) -> bool:
	if Smuggling.is_carrying(run):
		var dest := StringName(str(run.crate.get("destination", "")))
		if gang.turf.has(dest) or gang.turf.has(run.district_id):
			return true
	return false


static func _front_in_turf(run: RunState, gang: GangDef) -> Dictionary:
	for entry in run.businesses:
		var dist := Businesses.district_of(entry)
		if gang.turf.has(dist) and Businesses.is_open(run, entry):
			return entry
	return {}
