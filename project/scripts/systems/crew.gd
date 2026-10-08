class_name Crew

## Hired help, opened up by a career run. run.crew holds { role, hired_day, unpaid_days },
## at most one entry per role. Wages are paid each morning and unpaid crew walk out.

enum Result { OK, NOT_CAREER, UNKNOWN, RANK_TOO_LOW, CREW_FULL, ALREADY_HIRED, NOT_ENOUGH_CASH, NOT_HIRED }

const BASE_CAP := 1
const UNPAID_DAYS_TO_WALK := 2
const MIN_STOP_FACTOR := 0.2


## One crew slot, plus one for every safehouse upgrade.
static func cap(run: RunState) -> int:
	return BASE_CAP + run.stash_level


static func has(run: RunState, role_id: StringName) -> bool:
	return _index_of(run, role_id) >= 0


## Hired roles in the order they were taken on.
static func roles(run: RunState) -> Array[CrewRoleDef]:
	var list: Array[CrewRoleDef] = []
	for member in run.crew:
		var role := Content.crew_role(StringName(str(member.get("role", ""))))
		if role != null:
			list.append(role)
	return list


static func daily_wages(run: RunState) -> int:
	var total := 0
	for role in roles(run):
		total += role.daily_wage
	return total


static func check_hire(run: RunState, role_id: StringName) -> Result:
	if not run.career:
		return Result.NOT_CAREER
	var role := Content.crew_role(role_id)
	if role == null:
		return Result.UNKNOWN
	if has(run, role_id):
		return Result.ALREADY_HIRED
	if StreetCred.rank(run) < role.min_rank:
		return Result.RANK_TOO_LOW
	if run.crew.size() >= cap(run):
		return Result.CREW_FULL
	if run.cash < role.hire_cost:
		return Result.NOT_ENOUGH_CASH
	return Result.OK


static func hire(run: RunState, role_id: StringName) -> Result:
	var result := check_hire(run, role_id)
	if result != Result.OK:
		return result
	run.cash -= Content.crew_role(role_id).hire_cost
	run.crew.append({ "role": String(role_id), "hired_day": run.day, "unpaid_days": 0 })
	return Result.OK


static func fire(run: RunState, role_id: StringName) -> Result:
	var index := _index_of(run, role_id)
	if index < 0:
		return Result.NOT_HIRED
	run.crew.remove_at(index)
	return Result.OK


## Pays each member in hiring order while the cash lasts. Returns the roles that walked out.
static func pay_wages(run: RunState) -> Array[CrewRoleDef]:
	var walked: Array[CrewRoleDef] = []
	var staying: Array[Dictionary] = []
	for member in run.crew:
		var role := Content.crew_role(StringName(str(member.get("role", ""))))
		if role == null:
			continue
		if run.cash >= role.daily_wage:
			run.cash -= role.daily_wage
			member["unpaid_days"] = 0
		else:
			member["unpaid_days"] = int(member.get("unpaid_days", 0)) + 1
		if int(member["unpaid_days"]) >= UNPAID_DAYS_TO_WALK:
			walked.append(role)
			StreetCred.add(run, StreetCred.CREW_WALKED)
		else:
			staying.append(member)
	run.crew = staying
	return walked


static func capacity_bonus(run: RunState) -> int:
	var total := 0
	for role in roles(run):
		total += role.capacity_bonus
	return total


## Multiplier on the police stop chance.
static func stop_factor(run: RunState) -> float:
	var reduction := 0.0
	for role in roles(run):
		reduction += role.stop_reduction
	return maxf(MIN_STOP_FACTOR, 1.0 - reduction)


static func escape_bonus(run: RunState) -> float:
	var total := 0.0
	for role in roles(run):
		total += role.escape_bonus
	return total


static func fight_bonus(run: RunState) -> float:
	var total := 0.0
	for role in roles(run):
		total += role.fight_bonus
	return total


## Multiplier on the chance of being mugged.
static func mugging_factor(run: RunState) -> float:
	var factor := 1.0
	for role in roles(run):
		factor *= role.mugging_factor
	return factor


static func removes_travel_heat(run: RunState) -> bool:
	return roles(run).any(func(role: CrewRoleDef) -> bool: return role.removes_travel_heat)


static func can_warn_of_raid(run: RunState) -> bool:
	if run.raid_warning_day == run.day:
		return false
	return roles(run).any(func(role: CrewRoleDef) -> bool: return role.warns_of_raids)


static func use_raid_warning(run: RunState) -> void:
	run.raid_warning_day = run.day


## Empty when the role no longer exists.
static func sanitize(entry: Dictionary) -> Dictionary:
	var role_id := StringName(str(entry.get("role", "")))
	if Content.crew_role(role_id) == null:
		return {}
	return {
		"role": String(role_id),
		"hired_day": maxi(1, int(entry.get("hired_day", 1))),
		"unpaid_days": clampi(int(entry.get("unpaid_days", 0)), 0, UNPAID_DAYS_TO_WALK - 1),
	}


static func _index_of(run: RunState, role_id: StringName) -> int:
	for index in run.crew.size():
		if str(run.crew[index].get("role", "")) == String(role_id):
			return index
	return -1
