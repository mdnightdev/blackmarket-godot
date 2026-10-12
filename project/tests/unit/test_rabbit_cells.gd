extends GutTest

var _run: RunState


func before_each() -> void:
	_run = RunState.new()


func _stop_with_goods() -> void:
	Inventory.add_units(_run, &"burner_phones", 2)
	Encounters.police_stop(_run)
	_run.pending_encounter = {}


func _go_missing() -> void:
	_stop_with_goods()
	_run.day = RabbitCells.EARLIEST_DAY
	assert_true(RabbitCells.check(_run, true))


func _resolve(choice: StringName) -> String:
	return Encounters.resolve(_run, choice, 0.5)


func _read_release() -> void:
	for page in RabbitCells.RELEASE_LINES.size():
		assert_eq(str(_run.pending_encounter.type), RabbitCells.RELEASED)
		_resolve(Encounters.CONTINUE)
	assert_false(Encounters.has_pending(_run))


func test_a_stop_with_an_empty_bag_does_not_count() -> void:
	Encounters.police_stop(_run)
	assert_eq(_run.rabbit_cells, RabbitCells.Stage.NONE)


func test_a_stop_with_goods_sets_it_up() -> void:
	_stop_with_goods()
	assert_eq(_run.rabbit_cells, RabbitCells.Stage.DUE)


func test_he_goes_missing_on_a_morning_from_day_four() -> void:
	_stop_with_goods()
	_run.day = RabbitCells.EARLIEST_DAY - 1
	assert_false(RabbitCells.check(_run, true))
	_run.day = RabbitCells.EARLIEST_DAY
	assert_false(RabbitCells.check(_run, false), "only in the morning")
	assert_true(RabbitCells.check(_run, true))
	assert_eq(str(_run.pending_encounter.type), RabbitCells.MISSING)


func test_paying_ramos_gets_him_out_now() -> void:
	_go_missing()
	_run.cash = 1000
	_resolve(RabbitCells.GO_TO_RAMOS)
	assert_eq(_run.cash, 1000 - RabbitCells.RAMOS_FEE)
	assert_eq(_run.rabbit_cells, RabbitCells.Stage.FREE)
	assert_true(_run.rabbit_medal_held)
	_read_release()


func test_ramos_needs_the_fee_in_hand() -> void:
	_go_missing()
	_run.cash = RabbitCells.RAMOS_FEE - 1
	var ramos: Encounters.Choice = Encounters.choices(_run, _run.pending_encounter)[0]
	assert_eq(ramos.id, RabbitCells.GO_TO_RAMOS)
	assert_false(ramos.enabled)


func test_lexie_gets_him_out_in_half_a_day() -> void:
	_go_missing()
	var cash_before := _run.cash
	assert_false(_resolve(RabbitCells.ASK_LEXIE).is_empty())
	assert_eq(_run.cash, cash_before)
	assert_false(RabbitCells.check(_run, false))
	_run.phase = RabbitCells.LEXIE_PHASES as RunState.Phase
	assert_true(RabbitCells.check(_run, false))
	assert_eq(str(_run.pending_encounter.body), RabbitCells.RELEASE_LINES[0])
	_read_release()


func test_waiting_takes_a_day_and_he_comes_out_angry() -> void:
	_go_missing()
	_resolve(RabbitCells.WAIT)
	_run.phase = RunState.Phase.NIGHT
	assert_false(RabbitCells.check(_run, false))
	_run.day += 1
	_run.phase = RunState.Phase.MORNING
	assert_true(RabbitCells.check(_run, true))
	for page in RabbitCells.RELEASE_LINES.size() - 1:
		_resolve(Encounters.CONTINUE)
	assert_eq(str(_run.pending_encounter.body), RabbitCells.ANGRY_LAST_LINE)


func test_it_happens_once() -> void:
	_go_missing()
	_resolve(RabbitCells.GO_TO_RAMOS)
	_read_release()
	_stop_with_goods()
	_run.day += 1
	assert_false(RabbitCells.check(_run, true))


func test_not_in_the_career() -> void:
	_run.career = true
	_stop_with_goods()
	assert_eq(_run.rabbit_cells, RabbitCells.Stage.NONE)


func test_the_night_survives_a_save() -> void:
	_go_missing()
	_resolve(RabbitCells.ASK_LEXIE)
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(_run.to_dict())))
	assert_eq(restored.rabbit_cells, RabbitCells.Stage.WITH_LEXIE)
	assert_eq(restored.rabbit_release_stamp, _run.rabbit_release_stamp)
