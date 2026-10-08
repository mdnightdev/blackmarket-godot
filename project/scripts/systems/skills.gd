class_name Skills

## Perks bought with skill points. One point is earned per street cred rank above the first.
## Each effect list holds the value for skill ranks 1 to MAX_RANK in order.

enum Result { OK, UNKNOWN, NO_POINTS, MAX_RANK, RANK_TOO_LOW, NOT_ENOUGH_CASH, NOTHING_TO_RESET }

const MAX_RANK := 3
## Street cred rank needed to buy each skill rank, indexed by skill rank minus one.
const CRED_GATES: Array[int] = [1, 4, 7]
const RESPEC_COST_PER_CRED_RANK := 5000
const STRENGTH_WORDS: Array[String] = ["a little", "a lot", "far"]

const SKILLS := {
	&"haggler": {
		"name": "Haggler",
		"buy_discount": [0.03, 0.06, 0.10],
	},
	&"pack_mule": {
		"name": "Pack Mule",
		"capacity": [10, 20, 35],
	},
	&"cool_head": {
		"name": "Cool Head",
		"cooling": [1, 2, 3],
	},
	&"wheelman": {
		"name": "Wheelman",
		"escape": [0.05, 0.10, 0.15],
		"travel_heat": [1, 2, 3],
	},
	&"muscle": {
		"name": "Muscle",
		"fight": [0.05, 0.10, 0.15],
	},
	&"smuggler": {
		"name": "Smuggler",
		"crate_pay": [0.10, 0.20, 0.30],
		"crate_risk": [0.85, 0.70, 0.55],
	},
}


static func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in SKILLS:
		result.append(id)
	return result


static func is_known(id: StringName) -> bool:
	return SKILLS.has(id)


static func display_name(id: StringName) -> String:
	return str(SKILLS[id].name) if is_known(id) else ""


## Effect text for a skill rank, empty for unknown skills or ranks below 1. Ranks above MAX_RANK read as MAX_RANK.
static func describe(id: StringName, rank: int) -> String:
	if not is_known(id) or rank < 1:
		return ""
	match id:
		&"haggler":
			return "Buy prices -%d%%" % _percent(_value_at(id, "buy_discount", rank))
		&"pack_mule":
			return "Bag +%d slots" % int(_value_at(id, "capacity", rank))
		&"cool_head":
			return "Heat cools %d more per phase" % int(_value_at(id, "cooling", rank))
		&"wheelman":
			return "Escapes %s easier, travel heat -%d" % [_strength(rank), int(_value_at(id, "travel_heat", rank))]
		&"muscle":
			return "Fights %s easier" % _strength(rank)
		&"smuggler":
			return "Crate pay +%d%%, crates draw %s less police attention" % [
				_percent(_value_at(id, "crate_pay", rank)),
				_strength(rank),
			]
	return ""


## Unknown skills read as 0. Stored ranks are clamped to 0..MAX_RANK.
static func rank_of(run: RunState, id: StringName) -> int:
	if not is_known(id):
		return 0
	return clampi(int(run.skills.get(id, 0)), 0, MAX_RANK)


static func max_rank() -> int:
	return MAX_RANK


static func points_earned(run: RunState) -> int:
	return StreetCred.rank(run) - 1


static func points_spent(run: RunState) -> int:
	var spent := 0
	for id: StringName in SKILLS:
		spent += rank_of(run, id)
	return spent


static func points_free(run: RunState) -> int:
	return maxi(0, points_earned(run) - points_spent(run))


static func required_cred_rank(skill_rank: int) -> int:
	return CRED_GATES[clampi(skill_rank, 1, MAX_RANK) - 1]


static func check_upgrade(run: RunState, id: StringName) -> Result:
	if not is_known(id):
		return Result.UNKNOWN
	var next_rank := rank_of(run, id) + 1
	if next_rank > MAX_RANK:
		return Result.MAX_RANK
	if StreetCred.rank(run) < required_cred_rank(next_rank):
		return Result.RANK_TOO_LOW
	if points_free(run) <= 0:
		return Result.NO_POINTS
	return Result.OK


static func upgrade(run: RunState, id: StringName) -> Result:
	var result := check_upgrade(run, id)
	if result == Result.OK:
		run.skills[id] = rank_of(run, id) + 1
	return result


static func respec_cost(run: RunState) -> int:
	return RESPEC_COST_PER_CRED_RANK * StreetCred.rank(run)


static func check_respec(run: RunState) -> Result:
	if points_spent(run) == 0:
		return Result.NOTHING_TO_RESET
	if run.cash < respec_cost(run):
		return Result.NOT_ENOUGH_CASH
	return Result.OK


## Pays the cost and refunds every point.
static func respec(run: RunState) -> Result:
	var result := check_respec(run)
	if result == Result.OK:
		run.cash -= respec_cost(run)
		run.skills.clear()
	return result


static func buy_discount(run: RunState) -> float:
	return _effect(run, &"haggler", "buy_discount", 0.0)


static func capacity_bonus(run: RunState) -> int:
	return int(_effect(run, &"pack_mule", "capacity", 0.0))


static func extra_cooling(run: RunState) -> int:
	return int(_effect(run, &"cool_head", "cooling", 0.0))


static func escape_bonus(run: RunState) -> float:
	return _effect(run, &"wheelman", "escape", 0.0)


static func travel_heat_reduction(run: RunState) -> int:
	return int(_effect(run, &"wheelman", "travel_heat", 0.0))


## Added to the win chance of muggings, Vex fights and heists.
static func fight_bonus(run: RunState) -> float:
	return _effect(run, &"muscle", "fight", 0.0)


static func crate_pay_bonus(run: RunState) -> float:
	return _effect(run, &"smuggler", "crate_pay", 0.0)


## Multiplies the chance of losing crate cargo. 1.0 when the skill is not learned.
static func crate_risk_factor(run: RunState) -> float:
	return _effect(run, &"smuggler", "crate_risk", 1.0)


static func _effect(run: RunState, id: StringName, key: String, neutral: float) -> float:
	var rank := rank_of(run, id)
	return neutral if rank == 0 else _value_at(id, key, rank)


static func _value_at(id: StringName, key: String, rank: int) -> float:
	return float(SKILLS[id][key][clampi(rank, 1, MAX_RANK) - 1])


static func _percent(fraction: float) -> int:
	return roundi(fraction * 100.0)


## Odds-based perks grow by rank in words, since the odds themselves stay hidden.
static func _strength(rank: int) -> String:
	return STRENGTH_WORDS[clampi(rank, 1, MAX_RANK) - 1]
