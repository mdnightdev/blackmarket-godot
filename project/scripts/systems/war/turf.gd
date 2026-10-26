class_name Turf

## The turf war with the gangs. Every district a gang fights over is split into corners, and the player's share of
## a district is the share of its corners they hold, from 0 to 100. Corners only change hands by force, see War and
## RivalStrike. See GangDef.

enum Holder { NOBODY, PLAYER, GANG }

## The share at which neither side runs the district.
const EVEN_SHARE := 50
const HOLD_SHARE := 60
const GANG_HOLD_SHARE := 40

const HELD_SELL_FACTOR := 1.1
const GANG_SELL_FACTOR := 0.9
## Lookouts on the player's own corners keep the police away.
const HELD_STOP_FACTOR := 0.7
## A held district has room for one business, and a second from this street cred rank.
const SECOND_BUSINESS_RANK := 6

const VICTORY := "turf_won"
## Strength lead against a gang's crew at an even split, and what each point of share adds to it.
const FIGHT_EDGE := 0.05
const FIGHT_EDGE_PER_SHARE := 0.008


## Every district some gang fights over, in catalog order.
static func contested() -> Array[StringName]:
	var districts: Array[StringName] = []
	for gang in Content.gangs():
		for district_id in gang.turf:
			if not districts.has(district_id):
				districts.append(district_id)
	return districts


static func is_contested(district_id: StringName) -> bool:
	return Gangs.owner(district_id) != null


static func share(run: RunState, district_id: StringName) -> int:
	return Corners.share(run, district_id) if is_contested(district_id) else 0


static func holder(run: RunState, district_id: StringName) -> Holder:
	var gangs := Gangs.owners(district_id)
	if gangs.is_empty():
		return Holder.NOBODY
	var all_gone := gangs.all(func(g: GangDef) -> bool: return Gangs.is_gone(run, g))
	var player_share := share(run, district_id)
	if player_share >= HOLD_SHARE or all_gone:
		return Holder.PLAYER
	if player_share <= GANG_HOLD_SHARE:
		return Holder.GANG
	return Holder.NOBODY


static func held_count(run: RunState) -> int:
	return contested().filter(func(district_id: StringName) -> bool: return holder(run, district_id) == Holder.PLAYER).size()


static func holds(run: RunState, district_id: StringName) -> bool:
	if is_contested(district_id):
		return holder(run, district_id) == Holder.PLAYER
	var family := home_family(district_id)
	if family != null and Families.tier(run, family.id) >= Families.Tier.TRUSTED:
		return true
	return Corners.share(run, district_id) >= HOLD_SHARE


static func business_slots(run: RunState, district_id: StringName) -> int:
	if not holds(run, district_id):
		return 0
	return 2 if StreetCred.rank(run) >= SECOND_BUSINESS_RANK else 1


## The family whose home turf this is, or null.
static func home_family(district_id: StringName) -> FamilyDef:
	for family in Content.families():
		if family.home_districts.has(district_id):
			return family
	return null


static func sell_factor(run: RunState, district_id: StringName) -> float:
	match holder(run, district_id):
		Holder.PLAYER:
			return HELD_SELL_FACTOR
		Holder.GANG:
			return GANG_SELL_FACTOR
	return 1.0


static func stop_factor(run: RunState, district_id: StringName) -> float:
	return HELD_STOP_FACTOR if holder(run, district_id) == Holder.PLAYER else 1.0


## Rent and protection from every corner the player holds.
static func daily_cut(run: RunState) -> int:
	return Corners.daily_cut(run)


## Pays the morning cut and returns it.
static func collect_daily_cut(run: RunState) -> int:
	var cut := daily_cut(run)
	run.cash += cut
	return cut


## The more of the district the player runs, the more people stand with them in a street fight against its gang.
## Holding most of a district makes losing rare, and fighting where the gang holds everything is a long shot.
static func fight_chance(run: RunState, district_id: StringName) -> float:
	var edge := FIGHT_EDGE + (share(run, district_id) - EVEN_SHARE) * FIGHT_EDGE_PER_SHARE
	return Odds.contest(edge + StreetEvents.fight_bonus(run))


## A gang leaves once the player holds every corner of its turf. Waits while another encounter is pending.
static func check_victory(run: RunState) -> void:
	if not run.pending_encounter.is_empty():
		return
	for gang in Gangs.active(run):
		if gang.id == War.VEX_GANG:
			continue
		if not Rivals.corners(run, gang).is_empty():
			continue
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
