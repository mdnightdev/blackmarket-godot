extends GutTest

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	_run.opening_done = true


func test_nothing_plays_before_the_opening_is_over() -> void:
	_run.opening_done = false
	Tutorial.observe(_run)
	assert_eq(Tutorial.next_lesson(_run), "")


func test_meeting_lexie_comes_first_in_old_market() -> void:
	_run.district_id = Tutorial.MEETING_DISTRICT
	Tutorial.observe(_run)
	assert_eq(Tutorial.next_lesson(_run), Tutorial.MEETING)
	assert_eq(Tutorial.lines(Tutorial.MEETING).size(), 3)


func test_lessons_wait_until_lexie_is_met() -> void:
	_run.district_id = &"downtown"
	Tutorial.note(_run, Tutorial.FIRST_BUY)
	assert_eq(Tutorial.next_lesson(_run), "")
	_run.district_id = Tutorial.MEETING_DISTRICT
	Tutorial.observe(_run)
	Tutorial.note(_run, Tutorial.FIRST_BUY)
	assert_eq(_run.lessons_queued, [Tutorial.MEETING, Tutorial.FIRST_BUY] as Array[String])


func test_each_lesson_plays_once() -> void:
	_meet_lexie()
	Tutorial.note(_run, Tutorial.FIRST_SALE)
	Tutorial.finish_lesson(_run, Tutorial.FIRST_SALE)
	Tutorial.note(_run, Tutorial.FIRST_SALE)
	assert_false(_run.lessons_queued.has(Tutorial.FIRST_SALE))


func test_observe_reads_heat_police_and_jobs() -> void:
	_meet_lexie()
	_run.heat = Heat.NOTICED
	_run.pending_encounter = { "type": Encounters.POLICE }
	_run.customer_offers.append({ "id": "order" })
	_run.errand_offers.append({ "id": "errand", "sender": String(Errands.SENDER) })
	Tutorial.observe(_run)
	for lesson in [Tutorial.HOT, Tutorial.POLICE_STOP, Tutorial.CUSTOMER_ORDER, Tutorial.SHARK_ERRAND]:
		assert_true(_run.lessons_queued.has(lesson), lesson)


func test_payment_lesson_comes_while_paying_early_still_counts() -> void:
	_meet_lexie()
	_run.day = _run.next_due_day - 1 - Tutorial.PAYMENT_WARNING_DAYS - 1
	Tutorial.observe(_run)
	assert_false(_run.lessons_queued.has(Tutorial.PAYMENT_DUE))
	_run.day += 1
	Tutorial.observe(_run)
	assert_true(_run.lessons_queued.has(Tutorial.PAYMENT_DUE))


func test_covering_the_week_brings_the_last_lesson() -> void:
	_meet_lexie()
	_run.cash = 10000
	Loan.repay(_run, Loan.FIRST_PAYMENT)
	Tutorial.observe(_run)
	assert_true(_run.lessons_queued.has(Tutorial.PAYMENT_MADE))


func test_switching_off_clears_the_queue() -> void:
	_meet_lexie()
	Tutorial.note(_run, Tutorial.FIRST_BUY)
	Tutorial.switch_off(_run)
	assert_eq(Tutorial.next_lesson(_run), "")
	Tutorial.note(_run, Tutorial.FIRST_SALE)
	assert_eq(Tutorial.next_lesson(_run), "")


func test_no_lessons_in_the_career() -> void:
	_run.career = true
	Tutorial.observe(_run)
	assert_eq(Tutorial.next_lesson(_run), "")


func test_every_lesson_has_lines() -> void:
	for lesson: String in Tutorial.LINES:
		assert_false(Tutorial.lines(lesson).is_empty(), lesson)


func test_progress_survives_a_reload() -> void:
	_meet_lexie()
	Tutorial.finish_lesson(_run, Tutorial.MEETING)
	Tutorial.note(_run, Tutorial.FIRST_BUY)
	var data := _run.to_dict()
	data.lessons_queued.append("not_a_lesson")
	var loaded := RunState.from_dict(JSON.parse_string(JSON.stringify(data)))
	assert_true(loaded.opening_done)
	assert_eq(loaded.lessons_seen, [Tutorial.MEETING] as Array[String])
	assert_eq(loaded.lessons_queued, [Tutorial.FIRST_BUY] as Array[String])


func test_old_saves_skip_the_opening() -> void:
	var data := RunState.new().to_dict()
	data.erase("opening_done")
	assert_true(RunState.from_dict(data).opening_done)


func test_a_new_run_starts_with_the_opening() -> void:
	assert_true(OpeningTalk.should_play(RunState.new()))


func _meet_lexie() -> void:
	_run.district_id = Tutorial.MEETING_DISTRICT
	Tutorial.observe(_run)
