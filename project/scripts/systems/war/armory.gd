class_name Armory

## Weapons the player keeps for a war, bought from Rook in any amount. run.armory maps a Grade to the number of men it
## arms. Rook opens up as the player spends with him: blades and handguns at the front, rifles in the back room, then
## military grade. He buys weapons back at half his price. Weapons go on sale once the player owns a corner.

enum Grade { NONE, BLADE, HANDGUN, RIFLE, MILITARY }
enum Room { FRONT, BACK, MILITARY }
enum Result { OK, LOCKED, INVALID, NOT_ENOUGH_CASH }

const GRADE_NAMES := {
	Grade.BLADE: "Blades",
	Grade.HANDGUN: "Handguns",
	Grade.RIFLE: "Rifles",
	Grade.MILITARY: "Military kits",
}
const GRADE_ITEMS := {
	Grade.BLADE: &"machete",
	Grade.HANDGUN: &"pistol_45",
	Grade.RIFLE: &"rifle_ar15",
	Grade.MILITARY: &"anti_materiel_rifle",
}
## What one weapon adds to the man carrying it, before his own skill.
const POWER := {
	Grade.BLADE: 1.0,
	Grade.HANDGUN: 1.6,
	Grade.RIFLE: 2.4,
	Grade.MILITARY: 3.2,
}
const UNARMED_POWER := 0.1
const BEST_FIRST: Array[Grade] = [Grade.MILITARY, Grade.RIFLE, Grade.HANDGUN, Grade.BLADE]
const UNIT_PRICES := {
	Grade.BLADE: 1,
	Grade.HANDGUN: 4,
	Grade.RIFLE: 7,
	Grade.MILITARY: 12,
}
## The room Rook keeps each grade in.
const ROOMS := {
	Grade.BLADE: Room.FRONT,
	Grade.HANDGUN: Room.FRONT,
	Grade.RIFLE: Room.BACK,
	Grade.MILITARY: Room.MILITARY,
}
## Cash spent with Rook before the room opens.
const ROOM_SPEND := {
	Room.FRONT: 0,
	Room.BACK: 2500,
	Room.MILITARY: 25000,
}
## Saves from before orders of any size opened the rooms after this many lots.
const LEGACY_ROOM_LOTS := {
	Room.BACK: 4,
	Room.MILITARY: 10,
}
## Share of Rook's price he pays to take a weapon back.
const SELL_BACK_SHARE := 0.5
const UNLOCK_FLAG := "first_corner"


static func unlocked(run: RunState) -> bool:
	return Story.has(run, UNLOCK_FLAG)


static func room(run: RunState) -> Room:
	if run.rook_spent >= int(ROOM_SPEND[Room.MILITARY]):
		return Room.MILITARY
	if run.rook_spent >= int(ROOM_SPEND[Room.BACK]):
		return Room.BACK
	return Room.FRONT


static func is_on_sale(run: RunState, grade: Grade) -> bool:
	return unlocked(run) and ROOMS.has(grade) and int(ROOMS[grade]) <= room(run)


## Grades Rook sells right now, cheapest first.
static func on_sale(run: RunState) -> Array[Grade]:
	var grades: Array[Grade] = []
	for grade: int in ROOMS:
		if is_on_sale(run, grade as Grade):
			grades.append(grade as Grade)
	return grades


static func item_id(grade: Grade) -> StringName:
	return GRADE_ITEMS.get(grade, &"machete")


static func price(grade: Grade, amount: int) -> int:
	return int(UNIT_PRICES[grade]) * amount


static func sell_price(grade: Grade, amount: int) -> int:
	return floori(price(grade, amount) * SELL_BACK_SHARE)


static func most_affordable(run: RunState, grade: Grade) -> int:
	return maxi(0, floori(float(run.cash) / int(UNIT_PRICES[grade])))


static func buy(run: RunState, grade: Grade, amount: int) -> Result:
	if not is_on_sale(run, grade):
		return Result.LOCKED
	if amount <= 0:
		return Result.INVALID
	var cost := price(grade, amount)
	if run.cash < cost:
		return Result.NOT_ENOUGH_CASH
	run.cash -= cost
	run.armory[grade] = count(run, grade) + amount
	run.rook_spent += cost
	run.rook_orders += 1
	return Result.OK


static func sell(run: RunState, grade: Grade, amount: int) -> Result:
	if not unlocked(run):
		return Result.LOCKED
	if amount <= 0 or amount > count(run, grade):
		return Result.INVALID
	run.cash += sell_price(grade, amount)
	lose(run, grade, amount)
	return Result.OK


static func power_of(grade: Grade) -> float:
	return float(POWER.get(grade, UNARMED_POWER))


static func count(run: RunState, grade: Grade) -> int:
	return int(run.armory.get(grade, 0))


static func total(run: RunState) -> int:
	var sum := 0
	for grade: int in run.armory:
		sum += int(run.armory[grade])
	return sum


## Weapons carried by men who fell are gone.
static func lose(run: RunState, grade: Grade, amount: int) -> void:
	run.armory[grade] = maxi(0, count(run, grade) - amount)


## What an old save had spent with Rook, judged by the lots it bought.
static func spend_from_lots(lots: int) -> int:
	if lots >= int(LEGACY_ROOM_LOTS[Room.MILITARY]):
		return int(ROOM_SPEND[Room.MILITARY])
	if lots >= int(LEGACY_ROOM_LOTS[Room.BACK]):
		return int(ROOM_SPEND[Room.BACK])
	return 0


static func sanitize(source: Variant) -> Dictionary:
	var clean := {}
	if source is Dictionary:
		for key: Variant in source:
			var grade := int(str(key))
			var amount := int(source[key])
			if grade > Grade.NONE and grade < Grade.size() and amount > 0:
				clean[grade] = amount
	return clean
