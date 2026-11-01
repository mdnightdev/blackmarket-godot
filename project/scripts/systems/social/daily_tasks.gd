class_name DailyTasks

## Ten goals dealt each morning, each paying cash and street cred once.
## A task is stored as { id, kind, target, district, progress, done }. district is empty for kinds that do not name one.
##
## Call order for a day: deal() once the new day has started, the record_* hooks as things happen, and
## close_day() while run.day is still the finished day, which means before Calendar.advance_phase
## (or Travel.travel) moves the run out of the night phase.

const COUNT := 10
const COOL_HEAT := 30
const REWARD_PER_DAY := 150
const MIN_REWARD := 150
const SELL_BASE := 1500
const SELL_PER_DAY := 150
const SELL_ROUNDING := 100
const MAX_DELIVERIES := 2
const MARKET_VENUE: StringName = &"market"

const SELL_VALUE: StringName = &"sell_value"
const DELIVER_JOB: StringName = &"deliver_job"
const END_DAY_COOL: StringName = &"end_day_cool"
const CASINO_WIN: StringName = &"casino_win"
const VISIT: StringName = &"visit"
const TAKE_CORNER: StringName = &"take_corner"
const SCOUT_CORNER: StringName = &"scout_corner"
const POST_GARRISON: StringName = &"post_garrison"
const PAY_LOAN: StringName = &"pay_loan"
const USE_CONSUMABLE: StringName = &"use_consumable"

const KINDS: Array[StringName] = [
	SELL_VALUE,
	DELIVER_JOB,
	END_DAY_COOL,
	CASINO_WIN,
	VISIT,
	TAKE_CORNER,
	SCOUT_CORNER,
	POST_GARRISON,
	PAY_LOAN,
	USE_CONSUMABLE,
]


## Deals today's tasks unless they are already out. Seeded by the run, so a reload cannot reroll them.
static func deal(run: RunState) -> bool:
	if run.tasks_day == run.day:
		return false
	var day_index := run.day - 1
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run.price_seed, &"task", day_index])
	var kinds: Array[StringName] = []
	kinds.assign(KINDS)
	_shuffle(kinds, rng)
	var tasks: Array[Dictionary] = []
	for kind in kinds:
		if tasks.size() >= COUNT:
			break
		var task := _make(run, kind, rng)
		if not task.is_empty():
			task.id = "%s:%d" % [kind, day_index]
			tasks.append(task)
	run.daily_tasks = tasks
	run.tasks_day = run.day
	return true


static func reward(run: RunState) -> int:
	return maxi(MIN_REWARD, roundi(REWARD_PER_DAY * run.day / 5.0))


static func sell_target(day: int) -> int:
	return roundi((SELL_BASE + SELL_PER_DAY * day) / float(SELL_ROUNDING)) * SELL_ROUNDING


## Each hook returns the tasks it completed, with their rewards already paid.
static func record_sale(run: RunState, district_id: StringName, value: int) -> Array[Dictionary]:
	return _advance(run, SELL_VALUE, value, district_id)


## Counts a finished bar order, favour delivery or smuggling crate.
static func record_delivery(run: RunState) -> Array[Dictionary]:
	return _advance(run, DELIVER_JOB, 1)


static func record_casino_win(run: RunState) -> Array[Dictionary]:
	return _advance(run, CASINO_WIN, 1)


static func record_arrival(run: RunState, district_id: StringName) -> Array[Dictionary]:
	return _advance(run, VISIT, 1, district_id)


static func record_corner_taken(run: RunState) -> Array[Dictionary]:
	return _advance(run, TAKE_CORNER, 1)


static func record_scout(run: RunState) -> Array[Dictionary]:
	return _advance(run, SCOUT_CORNER, 1)


static func record_garrison(run: RunState) -> Array[Dictionary]:
	return _advance(run, POST_GARRISON, 1)


static func record_loan_payment(run: RunState) -> Array[Dictionary]:
	return _advance(run, PAY_LOAN, 1)


static func record_use_consumable(run: RunState) -> Array[Dictionary]:
	return _advance(run, USE_CONSUMABLE, 1)


## Must run while run.day and run.heat still belong to the finished day.
static func close_day(run: RunState) -> Array[Dictionary]:
	var completed: Array[Dictionary] = []
	if run.heat >= COOL_HEAT:
		return completed
	return _advance(run, END_DAY_COOL, 1)


static func describe(task: Dictionary) -> String:
	var target := int(task.target)
	match StringName(task.kind):
		SELL_VALUE:
			return "Sell %s in %s" % [Format.money(target), _district_name(task)]
		DELIVER_JOB:
			return "Complete a delivery" if target == 1 else "Complete %d deliveries" % target
		END_DAY_COOL:
			return "End the day under %d heat" % COOL_HEAT
		CASINO_WIN:
			return "Win a casino game" if target == 1 else "Win %d casino games" % target
		VISIT:
			return "Travel to %s" % _district_name(task)
		TAKE_CORNER:
			return "Capture a rival corner"
		SCOUT_CORNER:
			return "Scout a rival corner"
		POST_GARRISON:
			return "Station a garrison at a corner"
		PAY_LOAN:
			return "Make a loan payment"
		USE_CONSUMABLE:
			return "Use an operational consumable"
	return ""


static func progress_text(task: Dictionary) -> String:
	if StringName(task.kind) == SELL_VALUE:
		return "%s / %s" % [Format.money(int(task.progress)), Format.money(int(task.target))]
	return "%d / %d" % [int(task.progress), int(task.target)]


## Returns an empty dictionary when the kind is unknown or its district no longer exists.
static func sanitize(source: Dictionary) -> Dictionary:
	var kind := StringName(str(source.get("kind", "")))
	if not KINDS.has(kind):
		return {}
	var district_id := ""
	if _names_district(kind):
		district_id = str(source.get("district", ""))
		if Content.district(StringName(district_id)) == null:
			return {}
	var target := maxi(1, int(source.get("target", 1)))
	return {
		"id": str(source.get("id", "")),
		"kind": String(kind),
		"target": target,
		"district": district_id,
		"progress": clampi(int(source.get("progress", 0)), 0, target),
		"done": bool(source.get("done", false)),
	}


static func _advance(run: RunState, kind: StringName, amount: int, district_id: StringName = &"") -> Array[Dictionary]:
	var completed: Array[Dictionary] = []
	if run.tasks_day != run.day or amount <= 0:
		return completed
	for task in run.daily_tasks:
		if bool(task.done) or StringName(task.kind) != kind:
			continue
		if _names_district(kind) and StringName(task.district) != district_id:
			continue
		task.progress = mini(int(task.target), int(task.progress) + amount)
		if int(task.progress) >= int(task.target):
			task.done = true
			var pack := StreetCred.add(run, StreetCred.TASK_DONE)
			run.cash += reward(run)
			if not pack.is_empty():
				task["rank_pack"] = pack
			completed.append(task)
	return completed


## Returns an empty dictionary when no district suits the kind today.
static func _make(run: RunState, kind: StringName, rng: RandomNumberGenerator) -> Dictionary:
	var target := 1
	var district_id := ""
	match kind:
		SELL_VALUE:
			var markets := _reachable_districts(run).filter(func(district: DistrictDef) -> bool: return district.venues.has(MARKET_VENUE))
			if markets.is_empty():
				return {}
			var market: DistrictDef = markets[rng.randi_range(0, markets.size() - 1)]
			district_id = String(market.id)
			target = sell_target(run.day)
		DELIVER_JOB:
			target = rng.randi_range(1, MAX_DELIVERIES)
		VISIT:
			var destinations := _reachable_districts(run).filter(func(district: DistrictDef) -> bool: return district.id != run.district_id)
			if destinations.is_empty():
				return {}
			var destination: DistrictDef = destinations[rng.randi_range(0, destinations.size() - 1)]
			district_id = String(destination.id)
		TAKE_CORNER, SCOUT_CORNER, POST_GARRISON, PAY_LOAN, USE_CONSUMABLE:
			target = 1
	return {
		"id": "",
		"kind": String(kind),
		"target": target,
		"district": district_id,
		"progress": 0,
		"done": false,
	}


static func _reachable_districts(run: RunState) -> Array[DistrictDef]:
	var list: Array[DistrictDef] = []
	for district in Content.districts():
		if not Travel.is_locked(run, district):
			list.append(district)
	list.sort_custom(func(a: DistrictDef, b: DistrictDef) -> bool: return String(a.id) < String(b.id))
	return list


static func _shuffle(kinds: Array[StringName], rng: RandomNumberGenerator) -> void:
	for index in range(kinds.size() - 1, 0, -1):
		var swap := rng.randi_range(0, index)
		var held := kinds[index]
		kinds[index] = kinds[swap]
		kinds[swap] = held


static func _names_district(kind: StringName) -> bool:
	return kind == SELL_VALUE or kind == VISIT


static func _district_name(task: Dictionary) -> String:
	var district := Content.district(StringName(task.district))
	return district.display_name if district != null else str(task.district)
