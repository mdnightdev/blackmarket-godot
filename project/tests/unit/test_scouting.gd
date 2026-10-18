extends GutTest

const STEPS: StringName = &"tran_steps"
const BAY: StringName = &"loading_bay"

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	_run.price_seed = 77
	_run.day = 10
	_run.cash = 50000
	Corners.take(_run, Corners.MAMA_LIN)
	Story.mark(_run, Armory.UNLOCK_FLAG)


func _open_act_two() -> void:
	Corners.take_all(_run, Corners.HOME)
	Story.mark(_run, War.VEX_FELL)


func test_only_corners_the_player_could_hit_can_be_scouted() -> void:
	assert_eq(Scouting.scout(_run, BAY, 0.9, 0.5), Scouting.Result.NOT_A_TARGET, "Act 1 is only about Old Market")
	assert_eq(Scouting.scout(_run, Corners.MAMA_LIN, 0.9, 0.5), Scouting.Result.NOT_A_TARGET, "already held")
	assert_eq(Scouting.scout(_run, STEPS, 0.9, 0.5), Scouting.Result.OK)
	_open_act_two()
	assert_eq(Scouting.scout(_run, &"steam_grate_alley", 0.9, 0.5), Scouting.Result.OK, "The Slums opens in Act 2")
	assert_eq(Scouting.scout(_run, BAY, 0.9, 0.5), Scouting.Result.NOT_A_TARGET, "Warehouse Row requires holding The Slums first")
	Corners.take_all(_run, &"slums")
	assert_eq(Scouting.scout(_run, BAY, 0.9, 0.5), Scouting.Result.OK)


func test_a_scout_costs_more_in_richer_districts() -> void:
	_open_act_two()
	Corners.take_all(_run, &"slums")
	var riverside := Corners.find(&"under_the_bridge")
	assert_eq(Scouting.cost(riverside), Scouting.COST_PER_TIER * 2)
	Scouting.scout(_run, BAY, 0.9, 0.5)
	assert_eq(_run.cash, 50000 - Scouting.COST_PER_TIER)
	_run.cash = 10
	assert_eq(Scouting.scout(_run, BAY, 0.9, 0.5), Scouting.Result.NOT_ENOUGH_CASH)


func test_the_true_count_is_always_inside_the_range() -> void:
	var steps := Corners.find(STEPS)
	for roll: float in [0.0, 0.3, 0.7, 0.999]:
		Scouting.scout(_run, STEPS, 0.9, roll)
		var report := Scouting.report(_run, steps)
		assert_lte(int(report.low), steps.defenders)
		assert_gte(int(report.high), steps.defenders)
		assert_false(report.seen)
	assert_eq(War.defenders(_run, steps), steps.defenders, "an unseen scout changes nothing")


func test_ramos_narrows_the_range() -> void:
	var steps := Corners.find(STEPS)
	Scouting.scout(_run, STEPS, 0.9, 0.5)
	var wide := Scouting.report(_run, steps)
	_run.shark_bought = true
	Scouting.scout(_run, STEPS, 0.9, 0.5)
	var narrow := Scouting.report(_run, steps)
	assert_lt(int(narrow.high) - int(narrow.low), int(wide.high) - int(wide.low))


func test_a_spotted_scout_brings_more_men() -> void:
	var steps := Corners.find(STEPS)
	Scouting.scout(_run, STEPS, 0.0, 0.5)
	assert_true(Scouting.report(_run, steps).seen)
	assert_eq(War.defenders(_run, steps), steps.defenders + ceili(steps.defenders * Scouting.NOTICED_REINFORCEMENT))


func test_reports_go_stale() -> void:
	var steps := Corners.find(STEPS)
	Scouting.scout(_run, STEPS, 0.9, 0.5)
	_run.day += Scouting.FRESH_DAYS
	assert_false(Scouting.report(_run, steps).is_empty())
	_run.day += 1
	assert_true(Scouting.report(_run, steps).is_empty())
	assert_eq(Scouting.reading(_run, steps, Army.deployment(_run)), Scouting.UNKNOWN)


func test_the_reading_weighs_the_force_against_the_report() -> void:
	var steps := Corners.find(STEPS)
	Scouting.scout(_run, STEPS, 0.9, 0.5)
	Army.add(_run, Army.Tier.LUNATICS, Army.State.ACTIVE, 10)
	assert_eq(Scouting.reading(_run, steps, Army.deployment(_run)), Scouting.SUICIDE)
	_run.army_level = 1
	Army.add(_run, Army.Tier.GUARDS, Army.State.ACTIVE, 2000)
	_run.armory = { Armory.Grade.RIFLE: 2000 }
	assert_eq(Scouting.reading(_run, steps, Army.deployment(_run)), "easy")


func test_reports_survive_a_save() -> void:
	Scouting.scout(_run, STEPS, 0.0, 0.5)
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(_run.to_dict())))
	assert_eq(Scouting.report(restored, Corners.find(STEPS)), Scouting.report(_run, Corners.find(STEPS)))


func test_sanitize_drops_unknown_corners() -> void:
	var clean := Scouting.sanitize({ "tran_steps": { "low": 50, "high": 10, "day": 3 }, "nowhere": { "low": 1 } })
	assert_eq(clean.keys(), ["tran_steps"])
	assert_eq(int(clean.tran_steps.high), 50, "the top of the range never sits below the bottom")
