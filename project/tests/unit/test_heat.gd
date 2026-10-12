extends GutTest

var _run: RunState
var _phones: ItemDef


func before_each() -> void:
	_run = RunState.new()
	Story.mark(_run, War.VEX_FELL)
	_phones = Content.item(&"burner_phones")


func test_heat_levels() -> void:
	assert_eq(Heat.level(_run), Heat.Level.CALM)
	_run.heat = Heat.NOTICED
	assert_eq(Heat.level(_run), Heat.Level.NOTICED)
	_run.heat = Heat.WATCHED
	assert_eq(Heat.level(_run), Heat.Level.WATCHED)
	_run.heat = Heat.MAX
	assert_eq(Heat.level_name(_run), "Wanted")


func test_brandt_follows_a_watched_player() -> void:
	var brandt := Content.character(Police.BRANDT)
	var visits := func() -> int:
		var count := 0
		for stamp in 200:
			if Roster.character_location(_run, brandt, stamp) == _run.district_id:
				count += 1
		return count
	_run.district_id = &"docks"
	var calm: int = visits.call()
	_run.heat = Heat.WATCHED
	assert_gt(visits.call(), calm * 2)


func test_trips_with_goods_add_no_heat() -> void:
	Inventory.add_units(_run, _phones.id, 10)
	assert_eq(Heat.carried_risk(_run), 150)
	Encounters.after_arrival(_run, RandomNumberGenerator.new())
	assert_eq(_run.heat, 0)


func test_heat_cools_faster_overnight() -> void:
	_run.heat = 20
	Heat.cool_down(_run, false)
	assert_eq(_run.heat, 20 - Heat.DECAY_PER_PHASE)
	Heat.cool_down(_run, true)
	assert_eq(_run.heat, 20 - Heat.DECAY_PER_PHASE * 2 - Heat.OVERNIGHT_DECAY)


func test_heat_stays_between_zero_and_max() -> void:
	Heat.add(_run, -50)
	assert_eq(_run.heat, 0)
	Heat.add(_run, 500)
	assert_eq(_run.heat, Heat.MAX)
	assert_true(Heat.is_maxed(_run))
