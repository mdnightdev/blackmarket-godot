class_name Armory

## Weapons the player keeps for a war, bought from Rook in lots. run.armory maps a Grade to the number of men it arms.
## Rook opens up as the player keeps buying: small lots at the front, the back room, then military grade.
## Weapons go on sale once the player owns a corner.

enum Grade { NONE, BLADE, HANDGUN, RIFLE, MILITARY }
enum Room { FRONT, BACK, MILITARY }
enum Result { OK, LOCKED, NOT_ENOUGH_CASH }

const GRADE_NAMES := {
	Grade.BLADE: "Blades",
	Grade.HANDGUN: "Handguns",
	Grade.RIFLE: "Rifles",
	Grade.MILITARY: "Military kits",
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
	Grade.BLADE: 2,
	Grade.HANDGUN: 9,
	Grade.RIFLE: 15,
	Grade.MILITARY: 25,
}
const LOTS: Array[Dictionary] = [
	{ "grade": Grade.BLADE, "size": 200, "room": Room.FRONT },
	{ "grade": Grade.HANDGUN, "size": 100, "room": Room.FRONT },
	{ "grade": Grade.RIFLE, "size": 20, "room": Room.FRONT },
	{ "grade": Grade.HANDGUN, "size": 400, "room": Room.BACK },
	{ "grade": Grade.RIFLE, "size": 250, "room": Room.BACK },
	{ "grade": Grade.MILITARY, "size": 100, "room": Room.MILITARY },
	{ "grade": Grade.MILITARY, "size": 400, "room": Room.MILITARY },
]
const BACK_ROOM_LOTS := 4
const MILITARY_LOTS := 10
const UNLOCK_FLAG := "first_corner"


static func unlocked(run: RunState) -> bool:
	return Story.has(run, UNLOCK_FLAG)


static func room(run: RunState) -> Room:
	if run.rook_lots >= MILITARY_LOTS:
		return Room.MILITARY
	if run.rook_lots >= BACK_ROOM_LOTS:
		return Room.BACK
	return Room.FRONT


## Indexes into LOTS that Rook offers right now.
static func lots_on_sale(run: RunState) -> Array[int]:
	var on_sale: Array[int] = []
	for index in LOTS.size():
		if int(LOTS[index].room) <= room(run):
			on_sale.append(index)
	return on_sale


static func lot_price(lot: Dictionary) -> int:
	return int(UNIT_PRICES[int(lot.grade)]) * int(lot.size)


static func describe_lot(lot: Dictionary) -> String:
	return "%d %s, %s" % [int(lot.size), str(GRADE_NAMES[int(lot.grade)]).to_lower(), Format.money(lot_price(lot))]


static func buy(run: RunState, index: int) -> Result:
	if not unlocked(run) or index < 0 or index >= LOTS.size() or int(LOTS[index].room) > room(run):
		return Result.LOCKED
	var lot := LOTS[index]
	var price := lot_price(lot)
	if run.cash < price:
		return Result.NOT_ENOUGH_CASH
	run.cash -= price
	run.armory[int(lot.grade)] = count(run, int(lot.grade)) + int(lot.size)
	run.rook_lots += 1
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


static func sanitize(source: Variant) -> Dictionary:
	var clean := {}
	if source is Dictionary:
		for key: Variant in source:
			var grade := int(str(key))
			var amount := int(source[key])
			if grade > Grade.NONE and grade < Grade.size() and amount > 0:
				clean[grade] = amount
	return clean
