class_name Turf

## The turf war with Vex. Each contested district stores the player's share from 0 to 100; Vex holds the rest.

enum Holder { NOBODY, PLAYER, VEX }
enum LevelResult { OK, NOT_CONTESTED, NOT_HELD, MAX_LEVEL, RANK_TOO_LOW, NEEDS_TRUST, NOT_ENOUGH_CASH }

const CONTESTED: Array[StringName] = [&"old_market", &"slums", &"docks", &"north_port", &"downtown"]
const STARTING_SHARE := 50
const VEX_STRONGHOLDS := { &"slums": 25, &"north_port": 25 }
const HOLD_SHARE := 60
const VEX_HOLD_SHARE := 40

const HELD_SELL_FACTOR := 1.1
const VEX_SELL_FACTOR := 0.9
## Lookouts on the player's own corners keep the police away.
const HELD_STOP_FACTOR := 0.7
const STOP_FACTOR_PER_LEVEL := 0.05
const MIN_HELD_STOP_FACTOR := 0.5
## Paid every morning for each district the player holds, at turf level 1.
const DAILY_CUT := 150
const CUT_PER_LEVEL := 100

const MAX_LEVEL := 5
## Must equal CONTESTED.size() * MAX_LEVEL.
const MAX_POWER := 25
## Entry n is the upgrade to level n + 2.
const LEVEL_UPS: Array[Dictionary] = [
	{ "cost": 2000, "rank": 3 },
	{ "cost": 5000, "rank": 5 },
	{ "cost": 12000, "rank": 7 },
	{ "cost": 25000, "rank": 9 },
]
## From this level on, a family's home district also needs that family's trust.
const TRUSTED_LEVEL := 4

const SALE_VALUE_PER_POINT := 600
const MAX_SALE_GAIN := 4
const VEX_PUSH_PER_PHASE := 4

const MUSCLE_GAIN := 12
const MUSCLE_HEAT := 8
const MUSCLE_BASE_COST := 500
const MUSCLE_COST_PER_SHARE := 10

const VICTORY := "turf_won"
const FIGHT_BASE_CHANCE := 0.4
const FIGHT_CHANCE_PER_SHARE := 0.005
const MAX_FIGHT_CHANCE := 0.85
const VICTORY_REWARD := 5000

const RIVAL: StringName = &"rival"


static func is_contested(district_id: StringName) -> bool:
	return CONTESTED.has(district_id)


static func share(run: RunState, district_id: StringName) -> int:
	if not is_contested(district_id):
		return 0
	return int(run.turf.get(district_id, VEX_STRONGHOLDS.get(district_id, STARTING_SHARE)))


static func holder(run: RunState, district_id: StringName) -> Holder:
	if not is_contested(district_id):
		return Holder.NOBODY
	var player_share := share(run, district_id)
	if player_share >= HOLD_SHARE or run.vex_gone:
		return Holder.PLAYER
	if player_share <= VEX_HOLD_SHARE:
		return Holder.VEX
	return Holder.NOBODY


static func held_count(run: RunState) -> int:
	return CONTESTED.filter(func(district_id: StringName) -> bool: return holder(run, district_id) == Holder.PLAYER).size()


## The level paid for in a district. It is kept while the hold is lost.
static func bought_level(run: RunState, district_id: StringName) -> int:
	return clampi(int(run.turf_levels.get(district_id, 1)), 1, MAX_LEVEL)


## The level in effect, 0 while the player does not hold the district.
static func level(run: RunState, district_id: StringName) -> int:
	return bought_level(run, district_id) if holder(run, district_id) == Holder.PLAYER else 0


## Summed turf levels across the contested districts, from 0 to MAX_POWER.
static func power(run: RunState) -> int:
	var total := 0
	for district_id in CONTESTED:
		total += level(run, district_id)
	return total


static func business_slots(run: RunState, district_id: StringName) -> int:
	var current := level(run, district_id)
	if current < 2:
		return 0
	return 1 if current < TRUSTED_LEVEL else 2


## The family whose home turf this is, or null.
static func home_family(district_id: StringName) -> FamilyDef:
	for family in Content.families():
		if family.home_districts.has(district_id):
			return family
	return null


## Cash for the next level, -1 when the district cannot level further.
static func next_level_cost(run: RunState, district_id: StringName) -> int:
	var upgrade := _next_level_up(run, district_id)
	return int(upgrade.cost) if not upgrade.is_empty() else -1


## Street cred rank for the next level, -1 when the district cannot level further.
static func next_level_rank(run: RunState, district_id: StringName) -> int:
	var upgrade := _next_level_up(run, district_id)
	return int(upgrade.rank) if not upgrade.is_empty() else -1


static func check_level_up(run: RunState, district_id: StringName) -> LevelResult:
	if not is_contested(district_id):
		return LevelResult.NOT_CONTESTED
	if holder(run, district_id) != Holder.PLAYER:
		return LevelResult.NOT_HELD
	var next_level := bought_level(run, district_id) + 1
	if next_level > MAX_LEVEL:
		return LevelResult.MAX_LEVEL
	if StreetCred.rank(run) < next_level_rank(run, district_id):
		return LevelResult.RANK_TOO_LOW
	if next_level >= TRUSTED_LEVEL:
		var family := home_family(district_id)
		if family != null and Families.tier(run, family.id) < Families.Tier.TRUSTED:
			return LevelResult.NEEDS_TRUST
	if run.cash < next_level_cost(run, district_id):
		return LevelResult.NOT_ENOUGH_CASH
	return LevelResult.OK


static func level_up(run: RunState, district_id: StringName) -> LevelResult:
	var result := check_level_up(run, district_id)
	if result == LevelResult.OK:
		run.cash -= next_level_cost(run, district_id)
		run.turf_levels[district_id] = bought_level(run, district_id) + 1
	return result


static func _next_level_up(run: RunState, district_id: StringName) -> Dictionary:
	if not is_contested(district_id):
		return {}
	var index := bought_level(run, district_id) - 1
	return LEVEL_UPS[index] if index < LEVEL_UPS.size() else {}


static func sell_factor(run: RunState, district_id: StringName) -> float:
	match holder(run, district_id):
		Holder.PLAYER:
			return HELD_SELL_FACTOR
		Holder.VEX:
			return VEX_SELL_FACTOR
	return 1.0


static func stop_factor(run: RunState, district_id: StringName) -> float:
	var current := level(run, district_id)
	if current == 0:
		return 1.0
	return maxf(HELD_STOP_FACTOR - STOP_FACTOR_PER_LEVEL * (current - 1), MIN_HELD_STOP_FACTOR)


## The morning cut from one district, 0 while the player does not hold it.
static func district_cut(run: RunState, district_id: StringName) -> int:
	var current := level(run, district_id)
	if current == 0:
		return 0
	return DAILY_CUT + CUT_PER_LEVEL * (current - 1)


static func daily_cut(run: RunState) -> int:
	var total := 0
	for district_id in CONTESTED:
		total += district_cut(run, district_id)
	return total


## Pays the morning cut from every held district and returns it.
static func collect_daily_cut(run: RunState) -> int:
	var cut := daily_cut(run)
	run.cash += cut
	return cut


## The more of the district the player runs, the more people stand with them in a fight.
static func fight_chance(run: RunState, district_id: StringName) -> float:
	var bonus := Skills.fight_bonus(run) + Crew.fight_bonus(run)
	return minf(FIGHT_BASE_CHANCE + share(run, district_id) * FIGHT_CHANCE_PER_SHARE + bonus, MAX_FIGHT_CHANCE)


## Moves the player's share and returns the change actually applied.
static func shift(run: RunState, district_id: StringName, amount: int) -> int:
	if not is_contested(district_id) or run.vex_gone:
		return 0
	var before := share(run, district_id)
	var after := clampi(before + amount, 0, 100)
	run.turf[district_id] = after
	check_victory(run)
	return after - before


static func record_sale(run: RunState, sale_value: int) -> void:
	shift(run, run.district_id, mini(MAX_SALE_GAIN, ceili(float(sale_value) / SALE_VALUE_PER_POINT)))


static func muscle_cost(run: RunState) -> int:
	return MUSCLE_BASE_COST + share(run, run.district_id) * MUSCLE_COST_PER_SHARE


static func can_send_muscle(run: RunState) -> bool:
	return is_contested(run.district_id) \
		and not run.vex_gone \
		and share(run, run.district_id) < 100 \
		and run.muscle_stamp != Calendar.stamp(run) \
		and run.cash >= muscle_cost(run)


static func send_muscle(run: RunState) -> bool:
	if not can_send_muscle(run):
		return false
	run.cash -= muscle_cost(run)
	run.muscle_stamp = Calendar.stamp(run)
	Heat.add(run, MUSCLE_HEAT)
	shift(run, run.district_id, MUSCLE_GAIN)
	return true


## Vex gains ground wherever she spends the phase.
static func vex_pushes(run: RunState) -> void:
	var location := Roster.rival_location(run, Calendar.stamp(run))
	shift(run, location, -VEX_PUSH_PER_PHASE)


## Vex leaves once the player holds every contested district. Waits while another encounter is pending.
static func check_victory(run: RunState) -> void:
	if run.vex_gone or not run.pending_encounter.is_empty():
		return
	for district_id in CONTESTED:
		if share(run, district_id) < HOLD_SHARE:
			return
	run.vex_gone = true
	run.cash += VICTORY_REWARD
	StreetCred.add(run, StreetCred.VEX_BEATEN)
	run.pending_encounter = {
		"type": VICTORY,
		"speaker": String(RIVAL),
		"title": "Vex is out",
		"body": "Fine. The city is yours. I'm taking my crew somewhere the rent is cheaper. My stash house comes with the corners, %s inside." % Format.money(VICTORY_REWARD),
	}


static func sanitize(source: Variant) -> Dictionary:
	var result := {}
	if source is Dictionary:
		for key: Variant in source:
			var district_id := StringName(str(key))
			if is_contested(district_id):
				result[district_id] = clampi(int(source[key]), 0, 100)
	return result
