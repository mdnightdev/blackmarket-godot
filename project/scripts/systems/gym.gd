class_name Gym

## 午夜兔子's gym, open once he has joined the player. Four mornings a week he holds a training session: the hospital
## heals who it can, and every tier is filled back up to its slots, Black Hand first, with Lunatics from Auntie Tran.
## Men over a tier's slots are let go. The session is the only time the outfit costs money.

## Days of the week, counted from 0, with a session in the morning.
const SESSION_DAYS: Array[int] = [0, 2, 4, 6]


static func is_open(run: RunState) -> bool:
	return Story.has(run, Corners.RABBIT_JOINED)


static func is_session_day(day: int) -> bool:
	return SESSION_DAYS.has(posmod(day - 1, 7))


static func next_session_day(run: RunState) -> int:
	var day := run.day + 1
	while not is_session_day(day):
		day += 1
	return day


## Returns { healed, replaced, released, paid, vacancies }. replaced maps a tier to the men it gained.
static func session(run: RunState) -> Dictionary:
	var care := Hospital.heal(run)
	var paid := int(care.paid)
	var replaced := {}
	var released := 0
	for tier in Army.DEPLOY_ORDER:
		var extra := Army.total(run, tier) - Army.slots(run, tier)
		if extra > 0:
			var leaving := mini(extra, Army.count(run, tier))
			Army.add(run, tier, Army.State.ACTIVE, -leaving)
			released += leaving
			continue
		var price := int(Army.REPLACE_PRICES[tier])
		var filled := mini(Army.vacancies(run, tier), Army.men_for(price, run.cash))
		if filled > 0:
			var cost := Army.price_of(price, filled)
			Army.add(run, tier, Army.State.ACTIVE, filled)
			run.cash -= cost
			paid += cost
			replaced[tier] = filled
	var still_empty := 0
	for tier in Army.Tier.values():
		still_empty += Army.vacancies(run, tier)
	return { "healed": int(care.healed), "replaced": replaced, "released": released, "paid": paid, "vacancies": still_empty }


## What the next session would cost with today's wounded and empty slots.
static func estimate(run: RunState) -> int:
	var sum := Hospital.estimate(run)
	for tier in Army.Tier.values():
		sum += Army.price_of(int(Army.REPLACE_PRICES[tier]), Army.vacancies(run, tier))
	return sum


## The morning's session, when it is one. Returns notices for the morning.
static func morning(run: RunState) -> Array[Dictionary]:
	var notices: Array[Dictionary] = []
	if not is_open(run) or not is_session_day(run.day):
		return notices
	var result := session(run)
	var replaced := 0
	for tier: int in result.replaced:
		replaced += int(result.replaced[tier])
	if replaced == 0 and int(result.healed) == 0 and int(result.released) == 0:
		return notices
	var line := "Training day. %d new men, %d healed." % [replaced, int(result.healed)]
	if int(result.released) > 0:
		line += " %d let go." % int(result.released)
	var hint := "Paid %s." % Format.money(int(result.paid))
	if int(result.vacancies) > 0:
		hint += " %d slots still empty. Keep cash for the next session." % int(result.vacancies)
	notices.append({ "line": line, "hint": hint })
	return notices
