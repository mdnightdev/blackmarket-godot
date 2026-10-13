class_name Gym

## 午夜兔子's gym, open once he has joined the player. Men are paid for and join the outfit on the spot.

enum Course { LUNATICS, GUARDS, PROMOTION, BLACK_HAND }
enum Result { OK, CLOSED, LOCKED, INVALID, NOT_ENOUGH_MEN, NOT_ENOUGH_CASH }

## tier is who the men become and price is per thousand men.
const COURSES := {
	Course.LUNATICS: { "name": "Lunatics", "tier": Army.Tier.LUNATICS, "price": 1000 },
	Course.GUARDS: { "name": "Guards", "tier": Army.Tier.GUARDS, "price": 6000 },
	Course.PROMOTION: { "name": "Promote Lunatics", "tier": Army.Tier.GUARDS, "price": 5000 },
	Course.BLACK_HAND: { "name": "Black Hand", "tier": Army.Tier.BLACK_HAND, "price": 60000 },
}


static func is_open(run: RunState) -> bool:
	return Story.has(run, Corners.RABBIT_JOINED)


## Per thousand men.
static func price_per_thousand(course: Course) -> int:
	return int(COURSES[course].price)


static func price(course: Course, men: int) -> int:
	return Army.price_of(price_per_thousand(course), men)


## The most men the course can take right now: cash and, for a promotion, fit Lunatics.
static func most(run: RunState, course: Course) -> int:
	var men := Army.men_for(price_per_thousand(course), run.cash)
	if course == Course.PROMOTION:
		men = mini(men, Army.count(run, Army.Tier.LUNATICS))
	return maxi(0, men)


static func check(run: RunState, course: Course, men: int) -> Result:
	if not is_open(run):
		return Result.CLOSED
	if course == Course.BLACK_HAND and not Army.black_hand_open(run):
		return Result.LOCKED
	if men <= 0:
		return Result.INVALID
	if course == Course.PROMOTION and men > Army.count(run, Army.Tier.LUNATICS):
		return Result.NOT_ENOUGH_MEN
	if run.cash < price(course, men):
		return Result.NOT_ENOUGH_CASH
	return Result.OK


## Pays for the course and adds the men to the outfit. Promoted Lunatics become Guards.
static func enroll(run: RunState, course: Course, men: int) -> Result:
	var result := check(run, course, men)
	if result != Result.OK:
		return result
	run.cash -= price(course, men)
	if course == Course.PROMOTION:
		Army.add(run, Army.Tier.LUNATICS, Army.State.ACTIVE, -men)
	Army.add(run, int(COURSES[course].tier) as Army.Tier, Army.State.ACTIVE, men)
	return Result.OK


## Saves from when training took sessions may still hold men in training. They join the outfit on load.
static func deliver_legacy_training(run: RunState, source: Variant) -> void:
	if not source is Array:
		return
	for entry: Variant in source:
		if not entry is Dictionary:
			continue
		var tier := int(entry.get("tier", -1))
		var men := int(entry.get("men", 0))
		if tier >= 0 and tier < Army.Tier.size() and men > 0:
			Army.add(run, tier as Army.Tier, Army.State.ACTIVE, men)
