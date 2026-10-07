class_name Turf

## The turf war with Vex. Each contested district stores the player's share from 0 to 100; Vex holds the rest.

enum Holder { NOBODY, PLAYER, VEX }

const CONTESTED: Array[StringName] = [&"old_market", &"slums", &"docks", &"north_port", &"downtown"]
const STARTING_SHARE := 50
const VEX_STRONGHOLDS := { &"slums": 25, &"north_port": 25 }
const HOLD_SHARE := 60
const VEX_HOLD_SHARE := 40

const HELD_SELL_FACTOR := 1.1
const VEX_SELL_FACTOR := 0.9
## Lookouts on the player's own corners keep the police away.
const HELD_STOP_FACTOR := 0.7
## Paid every morning for each district the player holds.
const DAILY_CUT := 150

const SALE_VALUE_PER_POINT := 600
const MAX_SALE_GAIN := 4
const VEX_PUSH_PER_PHASE := 4

const MUSCLE_GAIN := 12
const MUSCLE_HEAT := 8
const MUSCLE_BASE_COST := 500
const MUSCLE_COST_PER_SHARE := 10

const CLASH := "clash"
const VICTORY := "turf_won"
const CLASH_CHANCE := 0.25
## The player's crew defends held districts, so Vex starts trouble there less often.
const HELD_CLASH_FACTOR := 0.5
const TRIBUTE_BASE := 300
const TRIBUTE_PER_SHARE := 5
const FIGHT_BASE_CHANCE := 0.4
const FIGHT_CHANCE_PER_SHARE := 0.005
const MAX_FIGHT_CHANCE := 0.85
const FIGHT_GAIN := 10
const FIGHT_LOSS := 10
## Share of carried cash lost when Vex's crew wins the fight.
const BEATING_CASH_FRACTION := 0.1
const BACK_OFF_LOSS := 8
const VICTORY_REWARD := 5000

const TRIBUTE: StringName = &"tribute"
const FIGHT: StringName = &"fight"
const BACK_OFF: StringName = &"back_off"
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


static func sell_factor(run: RunState, district_id: StringName) -> float:
	match holder(run, district_id):
		Holder.PLAYER:
			return HELD_SELL_FACTOR
		Holder.VEX:
			return VEX_SELL_FACTOR
	return 1.0


static func stop_factor(run: RunState, district_id: StringName) -> float:
	return HELD_STOP_FACTOR if holder(run, district_id) == Holder.PLAYER else 1.0


static func daily_cut(run: RunState) -> int:
	return held_count(run) * DAILY_CUT


## Pays the morning cut from every held district and returns it.
static func collect_daily_cut(run: RunState) -> int:
	var cut := daily_cut(run)
	run.cash += cut
	return cut


## The more of the district the player runs, the more people stand with them in a fight.
static func fight_chance(run: RunState, district_id: StringName) -> float:
	return minf(FIGHT_BASE_CHANCE + share(run, district_id) * FIGHT_CHANCE_PER_SHARE, MAX_FIGHT_CHANCE)


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


static func clash_due(run: RunState, roll: float) -> bool:
	if run.vex_gone or not is_contested(run.district_id):
		return false
	if Roster.rival_location(run, Calendar.stamp(run)) != run.district_id:
		return false
	match holder(run, run.district_id):
		Holder.VEX:
			return false
		Holder.PLAYER:
			return roll < CLASH_CHANCE * HELD_CLASH_FACTOR
	return roll < CLASH_CHANCE


static func clash(run: RunState) -> Dictionary:
	var district := Content.district(run.district_id)
	return {
		"type": CLASH,
		"speaker": String(RIVAL),
		"title": "Turf clash",
		"body": "My crew says you have been selling on my corners in %s. Pay up, fight, or walk away." % (district.display_name if district != null else "town"),
		"district": String(run.district_id),
		"tribute": tribute_cost(run),
	}


static func tribute_cost(run: RunState) -> int:
	return TRIBUTE_BASE + share(run, run.district_id) * TRIBUTE_PER_SHARE


## Applies the answer to a clash. The roll decides the fight and must be in the range [0, 1).
static func resolve_clash(run: RunState, encounter: Dictionary, choice: StringName, roll: float) -> String:
	var district_id := StringName(str(encounter.get("district", run.district_id)))
	match choice:
		TRIBUTE:
			var paid := mini(int(encounter.tribute), maxi(0, run.cash))
			run.cash -= paid
			return "You hand Vex %s. Her crew leaves your corners alone, for now." % Format.money(paid)
		FIGHT:
			if roll < fight_chance(run, district_id):
				shift(run, district_id, FIGHT_GAIN)
				return "Your people hold the street. Vex's crew scatters."
			var lost := floori(maxi(0, run.cash) * BEATING_CASH_FRACTION)
			run.cash -= lost
			shift(run, district_id, -FIGHT_LOSS)
			return "They beat you down and take %s. Vex owns more of these corners now." % Format.money(lost)
		BACK_OFF:
			shift(run, district_id, -BACK_OFF_LOSS)
			return "You walk away. Vex's crew moves onto your corners."
	return ""


## Vex leaves once the player holds every contested district. Waits while another encounter is pending.
static func check_victory(run: RunState) -> void:
	if run.vex_gone or not run.pending_encounter.is_empty():
		return
	for district_id in CONTESTED:
		if share(run, district_id) < HOLD_SHARE:
			return
	run.vex_gone = true
	run.cash += VICTORY_REWARD
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
