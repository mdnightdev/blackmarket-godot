extends GutTest

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	_run.cash = 100000


func test_locked_until_the_first_corner() -> void:
	assert_eq(Armory.buy(_run, Armory.Grade.BLADE, 10), Armory.Result.LOCKED)
	Story.mark(_run, Armory.UNLOCK_FLAG)
	assert_eq(Armory.buy(_run, Armory.Grade.BLADE, 10), Armory.Result.OK)


func test_any_amount_costs_the_unit_price() -> void:
	Story.mark(_run, Armory.UNLOCK_FLAG)
	assert_eq(Armory.buy(_run, Armory.Grade.HANDGUN, 37), Armory.Result.OK)
	assert_eq(_run.cash, 100000 - 37 * int(Armory.UNIT_PRICES[Armory.Grade.HANDGUN]))
	assert_eq(Armory.count(_run, Armory.Grade.HANDGUN), 37)
	assert_eq(_run.rook_spent, 37 * int(Armory.UNIT_PRICES[Armory.Grade.HANDGUN]))
	assert_eq(_run.rook_orders, 1)


func test_needs_the_cash_and_a_real_amount() -> void:
	Story.mark(_run, Armory.UNLOCK_FLAG)
	assert_eq(Armory.buy(_run, Armory.Grade.BLADE, 0), Armory.Result.INVALID)
	_run.cash = 0
	assert_eq(Armory.buy(_run, Armory.Grade.BLADE, 1), Armory.Result.NOT_ENOUGH_CASH)
	assert_eq(Armory.most_affordable(_run, Armory.Grade.BLADE), 0)
	assert_eq(Armory.total(_run), 0)


func test_rooms_open_with_cash_spent() -> void:
	Story.mark(_run, Armory.UNLOCK_FLAG)
	var front := Armory.on_sale(_run)
	assert_eq(front.size(), 2)
	assert_true(front.has(Armory.Grade.BLADE) and front.has(Armory.Grade.HANDGUN))
	assert_eq(Armory.buy(_run, Armory.Grade.RIFLE, 1), Armory.Result.LOCKED)
	_run.rook_spent = int(Armory.ROOM_SPEND[Armory.Room.BACK])
	assert_eq(Armory.room(_run), Armory.Room.BACK)
	assert_true(Armory.on_sale(_run).has(Armory.Grade.RIFLE))
	assert_false(Armory.on_sale(_run).has(Armory.Grade.MILITARY))
	_run.rook_spent = int(Armory.ROOM_SPEND[Armory.Room.MILITARY])
	assert_eq(Armory.buy(_run, Armory.Grade.MILITARY, 400), Armory.Result.OK)


func test_rook_buys_back_at_half() -> void:
	Story.mark(_run, Armory.UNLOCK_FLAG)
	_run.armory = { Armory.Grade.HANDGUN: 540 }
	assert_eq(Armory.sell(_run, Armory.Grade.HANDGUN, 541), Armory.Result.INVALID)
	assert_eq(Armory.sell(_run, Armory.Grade.HANDGUN, 0), Armory.Result.INVALID)
	assert_eq(Armory.sell(_run, Armory.Grade.HANDGUN, 101), Armory.Result.OK)
	assert_eq(_run.cash, 100000 + floori(101 * int(Armory.UNIT_PRICES[Armory.Grade.HANDGUN]) * Armory.SELL_BACK_SHARE))
	assert_eq(Armory.count(_run, Armory.Grade.HANDGUN), 439)


func test_survives_a_save() -> void:
	Story.mark(_run, Armory.UNLOCK_FLAG)
	Armory.buy(_run, Armory.Grade.BLADE, 200)
	Armory.buy(_run, Armory.Grade.HANDGUN, 100)
	var loaded := RunState.from_dict(JSON.parse_string(JSON.stringify(_run.to_dict())))
	assert_eq(loaded.armory, _run.armory)
	assert_eq(loaded.rook_orders, 2)
	assert_eq(loaded.rook_spent, _run.rook_spent)
	assert_true(Armory.unlocked(loaded))


func test_old_saves_keep_the_rooms_their_lots_opened() -> void:
	var data := _run.to_dict()
	data.erase("rook_orders")
	data.erase("rook_spent")
	data["rook_lots"] = 12
	var loaded := RunState.from_dict(JSON.parse_string(JSON.stringify(data)))
	assert_eq(loaded.rook_orders, 12)
	assert_eq(Armory.room(loaded), Armory.Room.MILITARY)
	data["rook_lots"] = 5
	assert_eq(Armory.room(RunState.from_dict(JSON.parse_string(JSON.stringify(data)))), Armory.Room.BACK)


func test_sanitize_drops_bad_grades() -> void:
	var clean := Armory.sanitize({ "1": 5, "0": 3, "9": 2, "2": -1 })
	assert_eq(clean, { Armory.Grade.BLADE: 5 })


func test_losing_men_takes_their_weapons() -> void:
	_run.armory = { Armory.Grade.HANDGUN: 10 }
	Armory.lose(_run, Armory.Grade.HANDGUN, 4)
	assert_eq(Armory.count(_run, Armory.Grade.HANDGUN), 6)
	Armory.lose(_run, Armory.Grade.HANDGUN, 40)
	assert_eq(Armory.count(_run, Armory.Grade.HANDGUN), 0)
