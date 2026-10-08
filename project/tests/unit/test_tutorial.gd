extends GutTest

var _run: RunState


func before_each() -> void:
	_run = RunState.new()


func test_a_new_run_shows_the_first_page() -> void:
	assert_true(Tutorial.should_show(_run))
	assert_eq(Tutorial.page(_run), Tutorial.pages()[0])


func test_next_walks_through_every_page_then_finishes() -> void:
	for index in Tutorial.pages().size():
		assert_true(Tutorial.should_show(_run))
		assert_eq(Tutorial.page(_run), Tutorial.pages()[index])
		Tutorial.advance(_run)
	assert_false(Tutorial.should_show(_run))
	assert_true(_run.tutorial_completed)


func test_skip_offered_until_the_last_page() -> void:
	assert_eq(_choice_ids(), [Tutorial.NEXT, Tutorial.SKIP])
	_run.tutorial_step = Tutorial.pages().size() - 1
	assert_eq(_choice_ids(), [Tutorial.NEXT])


func test_finish_ends_it_from_any_page() -> void:
	Tutorial.finish(_run)
	assert_false(Tutorial.should_show(_run))
	assert_true(_run.tutorial_completed)


func test_progress_survives_a_reload() -> void:
	Tutorial.advance(_run)
	var loaded := RunState.from_dict(_run.to_dict())
	assert_eq(loaded.tutorial_step, 1)
	Tutorial.finish(loaded)
	assert_false(Tutorial.should_show(RunState.from_dict(loaded.to_dict())))


func test_pages_quote_the_current_debt_rules() -> void:
	var first: String = Tutorial.pages()[0].line
	assert_string_contains(first, Format.money(RunState.STARTING_DEBT))
	assert_string_contains(first, Format.money(Loan.FIRST_PAYMENT))


func _choice_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for choice in Tutorial.choices(_run):
		ids.append(choice.id)
	return ids
