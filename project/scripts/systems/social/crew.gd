class_name Crew

## Hired help, opened up by a career run. run.crew holds { role, hired_day, unpaid_days, free },
## at most one entry per role. Wages are paid each morning and unpaid crew walk out.
## Free members, like the Shark after the buyout, draw no wage and take no crew slot.

enum Result { OK, NOT_CAREER, UNKNOWN, RANK_TOO_LOW, CREW_FULL, ALREADY_HIRED, NOT_ENOUGH_CASH, NOT_HIRED }

const BASE_CAP := 1
const UNPAID_DAYS_TO_WALK := 2
const MIN_STOP_FACTOR := 0.2

## Keys of run.crew_report, cleared by each morning report.
const DELIVERIES: StringName = &"deliveries"
const DELIVERY_PAY: StringName = &"delivery_pay"
const RAIDS_WARNED: StringName = &"raids_warned"
const COLLECTIONS: StringName = &"collections"
const COLLECTION_PAY: StringName = &"collection_pay"


## One crew slot, plus one for every safehouse upgrade.
static func cap(run: RunState) -> int:
	return BASE_CAP + run.stash_level


static func hired_count(run: RunState) -> int:
	return run.crew.filter(func(member: Dictionary) -> bool: return not is_free(member)).size()


static func is_free(member: Dictionary) -> bool:
	return bool(member.get("free", false))


static func is_free_role(run: RunState, role_id: StringName) -> bool:
	var index := _index_of(run, role_id)
	return index >= 0 and is_free(run.crew[index])


## Takes someone on for nothing. A paid member in the same role stops drawing a wage.
static func join_free(run: RunState, role_id: StringName) -> void:
	var index := _index_of(run, role_id)
	if index >= 0:
		run.crew[index]["free"] = true
		run.crew[index]["unpaid_days"] = 0
		return
	run.crew.append({ "role": String(role_id), "hired_day": run.day, "unpaid_days": 0, "free": true })


static func has(run: RunState, role_id: StringName) -> bool:
	return _index_of(run, role_id) >= 0


static func is_jailed(run: RunState, role_id: StringName) -> bool:
	var index := _index_of(run, role_id)
	return index >= 0 and bool(run.crew[index].get("jailed", false))


static func is_informant(run: RunState, role_id: StringName) -> bool:
	var index := _index_of(run, role_id)
	return index >= 0 and bool(run.crew[index].get("informant", false))


static func bail_cost(run: RunState, role_id: StringName) -> int:
	var index := _index_of(run, role_id)
	return maxi(0, int(run.crew[index].get("bail", 0))) if index >= 0 else 0


static func bail_member(run: RunState, role_id: StringName) -> bool:
	var index := _index_of(run, role_id)
	if index < 0 or not bool(run.crew[index].get("jailed", false)):
		return false
	var cost := bail_cost(run, role_id)
	if run.cash < cost:
		return false
	run.cash -= cost
	run.crew[index]["jailed"] = false
	run.crew[index]["bail"] = 0
	return true



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
	for member in run.crew:
		var role := Content.crew_role(StringName(str(member.get("role", ""))))
		if role != null and not is_free(member):
			total += role.daily_wage
	return total


static func check_hire(run: RunState, role_id: StringName) -> Result:
	if not Campaign.is_act_two(run):
		return Result.NOT_CAREER
	var role := Content.crew_role(role_id)
	if role == null:
		return Result.UNKNOWN
	if has(run, role_id):
		return Result.ALREADY_HIRED
	if StreetCred.rank(run) < role.min_rank:
		return Result.RANK_TOO_LOW
	if hired_count(run) >= cap(run):
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
		if is_free(member):
			staying.append(member)
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
		if not is_jailed(run, role.id):
			total += role.capacity_bonus
	return total


## Multiplier on the police stop chance.
static func stop_factor(run: RunState) -> float:
	var reduction := 0.0
	for role in roles(run):
		if not is_jailed(run, role.id):
			reduction += role.stop_reduction
	var factor := maxf(MIN_STOP_FACTOR, 1.0 - reduction)
	if run.crew.any(func(m: Dictionary) -> bool: return bool(m.get("informant", false))):
		factor = minf(2.0, factor * 1.8)
	return factor


static func escape_bonus(run: RunState) -> float:
	var total := 0.0
	for role in roles(run):
		if not is_jailed(run, role.id):
			total += role.escape_bonus
	return total


static func fight_bonus(run: RunState) -> float:
	var total := 0.0
	for role in roles(run):
		if not is_jailed(run, role.id):
			total += role.fight_bonus
	return total


## Multiplier on the chance of being mugged.
static func mugging_factor(run: RunState) -> float:
	var factor := 1.0
	for role in roles(run):
		if not is_jailed(run, role.id):
			factor *= role.mugging_factor
	return factor


static func scouts_routes(run: RunState) -> bool:
	return roles(run).any(func(role: CrewRoleDef) -> bool: return not is_jailed(run, role.id) and role.scouts_routes)


static func can_warn_of_raid(run: RunState) -> bool:
	if run.raid_warning_day == run.day:
		return false
	return roles(run).any(func(role: CrewRoleDef) -> bool: return not is_jailed(run, role.id) and role.warns_of_raids)


static func use_raid_warning(run: RunState) -> void:
	run.raid_warning_day = run.day
	note(run, RAIDS_WARNED)


## The hired role that runs deliveries, null when there is none or when jailed.
static func runner(run: RunState) -> CrewRoleDef:
	for role in roles(run):
		if not is_jailed(run, role.id) and role.delivers_jobs:
			return role
	return null


static func runner_ready(run: RunState) -> bool:
	return runner(run) != null and run.runner_stamp != Calendar.stamp(run)


## The hired role that handles collections, null when there is none or when jailed.
static func muscle(run: RunState) -> CrewRoleDef:
	for role in roles(run):
		if not is_jailed(run, role.id) and role.id == &"muscle":
			return role
	return null


static func muscle_ready(run: RunState) -> bool:
	return muscle(run) != null and run.muscle_stamp != Calendar.stamp(run)


## Hands over a bar order, favour, customer order, or delivery errand without travel.
## Returns the pay, 0 when it could not be done.
static func send_runner(run: RunState, job: Dictionary) -> int:
	if not runner_ready(run):
		return 0
	var pay := 0
	if run.orders.has(job):
		pay = Orders.total(job)
		if not Orders.deliver(run, job):
			return 0
	elif run.favours.has(job):
		pay = Favours.total(job)
		if not Favours.deliver(run, job):
			return 0
	elif run.customer_orders.has(job):
		pay = Customers.deliver_by_runner(run, job)
		if pay <= 0:
			return 0
	elif run.errands.has(job) and str(job.get("kind", "")) == Errands.DELIVERY and bool(job.get("picked_up", false)):
		pay = int(job.get("pay", 0))
		Errands.complete(run, job)
	else:
		return 0
	use_runner(run, pay)
	return pay


static func use_runner(run: RunState, pay: int) -> void:
	run.runner_stamp = Calendar.stamp(run)
	note(run, DELIVERIES)
	note(run, DELIVERY_PAY, pay)


## Dispatches muscle to collect dues from a debtor without player travel.
## Returns the pay, 0 when it could not be done.
static func send_muscle(run: RunState, errand: Dictionary) -> int:
	if not muscle_ready(run):
		return 0
	if not run.errands.has(errand) or str(errand.get("kind", "")) != Errands.COLLECTION:
		return 0
	var paid := Errands.complete(run, errand, 1.0)
	var pay := int(paid.get("cash", 0)) + int(paid.get("debt", 0))
	use_muscle(run, int(errand.get("owed", pay)))
	return pay


static func use_muscle(run: RunState, amount: int) -> void:
	run.muscle_stamp = Calendar.stamp(run)
	note(run, COLLECTIONS)
	note(run, COLLECTION_PAY, amount)


static func note(run: RunState, key: StringName, amount := 1) -> void:
	if amount > 0:
		run.crew_report[key] = int(run.crew_report.get(key, 0)) + amount


## What the crew did since the last report, empty when there is nothing to tell.
static func report_line(run: RunState) -> String:
	var parts: PackedStringArray = []
	var deliveries := int(run.crew_report.get(DELIVERIES, 0))
	if deliveries > 0:
		parts.append("your runner made %d %s worth %s" % [deliveries, "delivery" if deliveries == 1 else "deliveries", Format.money(int(run.crew_report.get(DELIVERY_PAY, 0)))])
	var collections := int(run.crew_report.get(COLLECTIONS, 0))
	if collections > 0:
		parts.append("your muscle made %d %s collecting %s" % [collections, "collection" if collections == 1 else "collections", Format.money(int(run.crew_report.get(COLLECTION_PAY, 0)))])
	var warned := int(run.crew_report.get(RAIDS_WARNED, 0))
	if warned > 0:
		parts.append("your lookout warned you of %d %s" % [warned, "raid" if warned == 1 else "raids"])
	if parts.is_empty():
		return ""
	return "Yesterday %s." % ", ".join(parts)


## Morning operational street risks: runner arrests, mugging ambushes, and police informants.
static func morning(run: RunState, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var notices: Array[Dictionary] = []
	if not Campaign.is_act_two(run):
		return notices

	# 1. Runner arrest risk if runner is active and not already jailed
	if has(run, &"runner") and not is_jailed(run, &"runner"):
		var arrest_risk := 0.05 + (float(run.heat) / 250.0)
		if rng.randf() < arrest_risk:
			var idx := _index_of(run, &"runner")
			if idx >= 0:
				var bail := maxi(500, 250 * StreetCred.rank(run))
				run.crew[idx]["jailed"] = true
				run.crew[idx]["bail"] = bail
				notices.append({
					"line": "Your runner was caught in a street sweep overnight and booked.",
					"hint": "Bail is %s. Post bail in your Crew roster to release them." % Format.money(bail),
				})

	# 2. Mugging ambush if rival gangs are active and deliveries/collections happened
	if not Gangs.confronting(run).is_empty():
		var total_jobs := int(run.crew_report.get(DELIVERIES, 0)) + int(run.crew_report.get(COLLECTIONS, 0))
		if total_jobs > 0 and rng.randf() < 0.15:
			if has(run, &"muscle") and not is_jailed(run, &"muscle"):
				notices.append({
					"line": "Rival gang raiders attempted to ambush your crew routes overnight.",
					"hint": "Your muscle held the line and drove them back with no losses.",
				})
			else:
				var stolen := mini(run.cash, 250 + 75 * StreetCred.rank(run))
				if stolen > 0:
					run.cash -= stolen
					notices.append({
						"line": "Rival thugs jumped your runner in an alley and took %s." % Format.money(stolen),
						"hint": "Hire muscle to protect your runners from street ambushes.",
					})

	# 3. Informant flip if heat >= 50
	if run.heat >= 50 and rng.randf() < 0.12:
		var candidates: Array[Dictionary] = []
		for member in run.crew:
			if not is_free(member) and not bool(member.get("informant", false)):
				candidates.append(member)
		if not candidates.is_empty():
			var flipped: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
			flipped["informant"] = true
			var role := Content.crew_role(StringName(str(flipped.get("role", ""))))
			var name := role.display_name.to_lower() if role != null else "crew member"
			notices.append({
				"line": "Street rumor: Detective Ramos was seen leaning hard on your %s." % name,
				"hint": "Suspected informant. They are leaking route intel. Fire them from Crew to stop the leak.",
			})

	return notices


## The role's effects, for example "+15 bag slots, delivers 1 job a phase". Odds are described, never quoted.
static func effects(role: CrewRoleDef) -> String:
	var parts: PackedStringArray = []
	if role.capacity_bonus > 0:
		parts.append("+%d bag slots" % role.capacity_bonus)
	if role.delivers_jobs:
		parts.append("delivers 1 job a phase")
	if role.stop_reduction > 0.0:
		parts.append("fewer police stops")
	if role.warns_of_raids:
		parts.append("warns of 1 raid a day")
	if role.scouts_routes:
		parts.append("free route recon")
	if role.escape_bonus > 0.0:
		parts.append("better escapes")
	if role.fight_bonus > 0.0:
		parts.append("wins more fights")
	if role.mugging_factor < 1.0:
		parts.append("fewer muggings")
	var text := ", ".join(parts)
	return text.left(1).to_upper() + text.substr(1)


## Empty when the role no longer exists.
static func sanitize(entry: Dictionary) -> Dictionary:
	var role_id := StringName(str(entry.get("role", "")))
	if Content.crew_role(role_id) == null:
		return {}
	var clean := {
		"role": String(role_id),
		"hired_day": maxi(1, int(entry.get("hired_day", 1))),
		"unpaid_days": clampi(int(entry.get("unpaid_days", 0)), 0, UNPAID_DAYS_TO_WALK - 1),
	}
	if is_free(entry):
		clean["free"] = true
	if bool(entry.get("jailed", false)):
		clean["jailed"] = true
		clean["bail"] = maxi(0, int(entry.get("bail", 0)))
	if bool(entry.get("informant", false)):
		clean["informant"] = true
	return clean


static func _index_of(run: RunState, role_id: StringName) -> int:
	for index in run.crew.size():
		if str(run.crew[index].get("role", "")) == String(role_id):
			return index
	return -1
