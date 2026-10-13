extends GutTest

const BAY: StringName = &"loading_bay"

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	_run.price_seed = 515
	Corners.take_all(_run, Corners.HOME)


func _open_act_two() -> void:
	Story.mark(_run, War.VEX_FELL)


func _jackal() -> GangDef:
	return Content.gang(&"jackal")


func test_each_rival_starts_with_its_own_weapons() -> void:
	assert_eq(Rivals.gear(_run, Content.gang(&"vex")), Armory.Grade.BLADE)
	assert_eq(Rivals.gear(_run, _jackal()), Armory.Grade.HANDGUN)
	assert_eq(Rivals.gear(_run, Content.gang(&"celeste")), Armory.Grade.RIFLE)
	assert_almost_eq(Rivals.power_per_man(_run, _jackal()), Armory.power_of(Armory.Grade.HANDGUN) * Rivals.SKILL, 0.001)


func test_rivals_wait_for_act_two() -> void:
	assert_true(Rivals.morning(_run).is_empty())
	assert_eq(Rivals.chest(_run, _jackal()), 0)
	assert_eq(War.defenders(_run, Corners.find(BAY)), Corners.find(BAY).defenders)


func test_each_morning_a_rival_banks_and_reinforces() -> void:
	_open_act_two()
	Corners.take(_run, &"scrap_yard")
	Rivals.morning(_run)
	var expected := 0
	for corner in Rivals.corners(_run, _jackal()):
		expected += roundi(corner.daily_cut() * Rivals.SAVINGS_SHARE)
	assert_eq(Rivals.chest(_run, _jackal()), expected, "only the corners it still holds pay it")
	var bay := Corners.find(BAY)
	assert_eq(War.defenders(_run, bay), bay.defenders + ceili(bay.defenders * Rivals.DAILY_GROWTH))
	assert_eq(War.defenders(_run, Corners.find(&"scrap_yard")), 0)


func test_garrisons_stop_growing_at_the_cap() -> void:
	_open_act_two()
	var bay := Corners.find(BAY)
	for morning in 200:
		Rivals.grow(_run, _jackal())
	assert_eq(War.defenders(_run, bay), Rivals.max_garrison(bay))


func test_a_full_war_chest_buys_better_weapons() -> void:
	_open_act_two()
	_run.rivals[&"jackal"] = { "chest": int(Rivals.GEAR_PRICES[Armory.Grade.RIFLE]) }
	var notices := Rivals.morning(_run)
	assert_eq(Rivals.gear(_run, _jackal()), Armory.Grade.RIFLE)
	assert_lt(Rivals.chest(_run, _jackal()), int(Rivals.GEAR_PRICES[Armory.Grade.RIFLE]))
	assert_eq(notices.size(), 1)
	assert_string_contains(str(notices[0].line), "rifles")


func test_the_best_armed_rival_stops_saving_for_weapons() -> void:
	_run.rivals[&"celeste"] = { "gear": Armory.Grade.MILITARY }
	assert_eq(Rivals.next_gear(_run, Content.gang(&"celeste")), Armory.Grade.NONE)


func test_rivals_survive_a_save() -> void:
	_run.rivals[&"jackal"] = { "chest": 4200, "gear": Armory.Grade.RIFLE, "last_strike_day": 6 }
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(_run.to_dict())))
	assert_eq(Rivals.chest(restored, _jackal()), 4200)
	assert_eq(Rivals.gear(restored, _jackal()), Armory.Grade.RIFLE)
	assert_eq(Rivals.last_strike_day(restored, _jackal()), 6)


func test_sanitize_drops_unknown_gangs_and_clamps() -> void:
	var clean := Rivals.sanitize({ "jackal": { "chest": -5, "gear": 99 }, "nobody": { "chest": 1 } })
	assert_eq(clean.size(), 1)
	assert_true(clean.has(&"jackal"))
	assert_eq(int(clean[&"jackal"].chest), 0)
	assert_eq(int(clean[&"jackal"].gear), Armory.Grade.MILITARY)
