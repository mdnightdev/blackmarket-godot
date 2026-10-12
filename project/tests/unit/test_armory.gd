extends GutTest

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	_run.cash = 100000


func _index_of(grade: Armory.Grade, room: Armory.Room) -> int:
	for index in Armory.LOTS.size():
		if int(Armory.LOTS[index].grade) == grade and int(Armory.LOTS[index].room) == room:
			return index
	return -1


func test_locked_until_the_first_corner() -> void:
	assert_eq(Armory.buy(_run, 0), Armory.Result.LOCKED)
	Story.mark(_run, Armory.UNLOCK_FLAG)
	assert_eq(Armory.buy(_run, 0), Armory.Result.OK)


func test_a_lot_arms_its_size_and_costs_the_unit_price() -> void:
	Story.mark(_run, Armory.UNLOCK_FLAG)
	var index := _index_of(Armory.Grade.BLADE, Armory.Room.FRONT)
	var lot := Armory.LOTS[index]
	assert_eq(Armory.buy(_run, index), Armory.Result.OK)
	assert_eq(_run.cash, 100000 - int(Armory.UNIT_PRICES[Armory.Grade.BLADE]) * int(lot.size))
	assert_eq(Armory.count(_run, Armory.Grade.BLADE), int(lot.size))
	assert_eq(Armory.total(_run), int(lot.size))


func test_needs_the_cash() -> void:
	Story.mark(_run, Armory.UNLOCK_FLAG)
	_run.cash = 0
	assert_eq(Armory.buy(_run, 0), Armory.Result.NOT_ENOUGH_CASH)
	assert_eq(Armory.total(_run), 0)


func test_rooms_open_with_regular_buying() -> void:
	Story.mark(_run, Armory.UNLOCK_FLAG)
	var back := _index_of(Armory.Grade.RIFLE, Armory.Room.BACK)
	var military := _index_of(Armory.Grade.MILITARY, Armory.Room.MILITARY)
	assert_false(Armory.lots_on_sale(_run).has(back))
	assert_eq(Armory.buy(_run, back), Armory.Result.LOCKED)
	_run.rook_lots = Armory.BACK_ROOM_LOTS
	assert_eq(Armory.room(_run), Armory.Room.BACK)
	assert_true(Armory.lots_on_sale(_run).has(back))
	assert_false(Armory.lots_on_sale(_run).has(military))
	_run.rook_lots = Armory.MILITARY_LOTS
	assert_eq(Armory.buy(_run, military), Armory.Result.OK)


func test_survives_a_save() -> void:
	Story.mark(_run, Armory.UNLOCK_FLAG)
	Armory.buy(_run, 0)
	Armory.buy(_run, 1)
	var loaded := RunState.from_dict(JSON.parse_string(JSON.stringify(_run.to_dict())))
	assert_eq(loaded.armory, _run.armory)
	assert_eq(loaded.rook_lots, 2)
	assert_true(Armory.unlocked(loaded))


func test_sanitize_drops_bad_grades() -> void:
	var clean := Armory.sanitize({ "1": 5, "0": 3, "9": 2, "2": -1 })
	assert_eq(clean, { Armory.Grade.BLADE: 5 })


func test_losing_men_takes_their_weapons() -> void:
	_run.armory = { Armory.Grade.HANDGUN: 10 }
	Armory.lose(_run, Armory.Grade.HANDGUN, 4)
	assert_eq(Armory.count(_run, Armory.Grade.HANDGUN), 6)
	Armory.lose(_run, Armory.Grade.HANDGUN, 40)
	assert_eq(Armory.count(_run, Armory.Grade.HANDGUN), 0)
