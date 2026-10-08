class_name Turf

## The turf war with the gangs. Each district of a gang's turf stores the player's share from 0 to 100, and the
## gang holds the rest. See GangDef.

enum Holder { NOBODY, PLAYER, GANG }
enum LevelResult { OK, NOT_CONTESTED, NOT_HELD, MAX_LEVEL, RANK_TOO_LOW, NEEDS_TRUST, NOT_ENOUGH_CASH }

const STARTING_SHARE := 50
const HOLD_SHARE := 60
const GANG_HOLD_SHARE := 40

const HELD_SELL_FACTOR := 1.1
const GANG_SELL_FACTOR := 0.9
## Lookouts on the player's own corners keep the police away.
const HELD_STOP_FACTOR := 0.7
const STOP_FACTOR_PER_LEVEL := 0.05
const MIN_HELD_STOP_FACTOR := 0.5
## Paid every morning for each district the player holds, at turf level 1.
const DAILY_CUT := 150
const CUT_PER_LEVEL := 100

const MAX_LEVEL := 5
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

const MUSCLE_GAIN := 12
const MUSCLE_HEAT := 8
const MUSCLE_BASE_COST := 500
const MUSCLE_COST_PER_SHARE := 10

const VICTORY := "turf_won"
## Strength lead against a gang's crew at an even split, and what each point of share adds to it.
const FIGHT_EDGE := 0.05
const FIGHT_EDGE_PER_SHARE := 0.008


## Every district some gang fights over, in catalog order.
static func contested() -> Array[StringName]:
	var districts: Array[StringName] = []
	for gang in Content.gangs():
		districts.append_array(gang.turf)
	return districts


static func is_contested(district_id: StringName) -> bool:
	return Gangs.owner(district_id) != null


static func share(run: RunState, district_id: StringName) -> int:
	var gang := Gangs.owner(district_id)
	if gang == null:
		return 0
	return int(run.turf.get(district_id, gang.strongholds.get(district_id, STARTING_SHARE)))


static func holder(run: RunState, district_id: StringName) -> Holder:
	var gang := Gangs.owner(district_id)
	if gang == null:
		return Holder.NOBODY
	var player_share := share(run, district_id)
	if player_share >= HOLD_SHARE or Gangs.is_gone(run, gang):
		return Holder.PLAYER
	if player_share <= GANG_HOLD_SHARE:
		return Holder.GANG
	return Holder.NOBODY


static func held_count(run: RunState) -> int:
	return contested().filter(func(district_id: StringName) -> bool: return holder(run, district_id) == Holder.PLAYER).size()


## The level paid for in a district. It is kept while the hold is lost.
static func bought_level(run: RunState, district_id: StringName) -> int:
	return clampi(int(run.turf_levels.get(district_id, 1)), 1, MAX_LEVEL)


## The level in effect, 0 while the player does not hold the district.
static func level(run: RunState, district_id: StringName) -> int:
	return bought_level(run, district_id) if holder(run, district_id) == Holder.PLAYER else 0


## Summed turf levels across the contested districts, from 0 to max_power.
static func power(run: RunState) -> int:
	var total := 0
	for district_id in contested():
		total += level(run, district_id)
	return total


static func max_power() -> int:
	return contested().size() * MAX_LEVEL


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
		Holder.GANG:
			return GANG_SELL_FACTOR
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
	for district_id in contested():
		total += district_cut(run, district_id)
	return total


## Pays the morning cut from every held district and returns it.
static func collect_daily_cut(run: RunState) -> int:
	var cut := daily_cut(run)
	run.cash += cut
	return cut


## The more of the district the player runs, the more people stand with them in a fight against its gang.
## Holding most of a district makes losing rare, and fighting in a gang stronghold is a long shot.
static func fight_chance(run: RunState, district_id: StringName) -> float:
	var edge := FIGHT_EDGE + (share(run, district_id) - STARTING_SHARE) * FIGHT_EDGE_PER_SHARE
	return Odds.contest(edge + StreetEvents.fight_bonus(run))


## Moves the player's share and returns the change actually applied.
static func shift(run: RunState, district_id: StringName, amount: int) -> int:
	if Gangs.is_gone(run, Gangs.owner(district_id)):
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
	return not Gangs.is_gone(run, Gangs.owner(run.district_id)) \
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


## Each gang gains ground wherever its boss spends the phase, hard where it is strong and barely where the player
## dominates.
static func gangs_push(run: RunState) -> void:
	var stamp := Calendar.stamp(run)
	for gang in Gangs.active(run):
		var location := Gangs.boss_location(run, gang, stamp)
		if Gangs.owner(location) == gang:
			shift(run, location, -gang_push(run, gang, location))


static func gang_push(run: RunState, gang: GangDef, district_id: StringName) -> int:
	return floori(gang.max_push * (100 - share(run, district_id)) / 100.0)


## A gang leaves once the player holds every district of its turf. Waits while another encounter is pending.
static func check_victory(run: RunState) -> void:
	if not run.pending_encounter.is_empty():
		return
	for gang in Gangs.active(run):
		if gang.turf.all(func(district_id: StringName) -> bool: return share(run, district_id) >= HOLD_SHARE):
			run.gangs_gone.append(gang.id)
			run.cash += gang.victory_reward
			StreetCred.add(run, StreetCred.GANG_BEATEN)
			run.pending_encounter = {
				"type": VICTORY,
				"gang": String(gang.id),
				"speaker": String(gang.boss),
				"title": gang.victory_title,
				"body": gang.victory_line % Format.money(gang.victory_reward),
			}
			return


static func victory_summary(gang: GangDef) -> String:
	return "Count it, %s in the stash. The whole street watched you push me out, that buys you %d cred. No more gates, no more hunts. My corners are yours." % [
		Format.money(gang.victory_reward), StreetCred.GANG_BEATEN,
	]


static func sanitize(source: Variant) -> Dictionary:
	var result := {}
	if source is Dictionary:
		for key: Variant in source:
			var district_id := StringName(str(key))
			if is_contested(district_id):
				result[district_id] = clampi(int(source[key]), 0, 100)
	return result
