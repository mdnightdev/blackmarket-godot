extends GutTest

const STEPS: StringName = &"tran_steps"
const LANTERN: StringName = &"lantern"

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	_run.price_seed = 2024
	_run.day = 12
	Corners.take(_run, Corners.MAMA_LIN)
	Story.mark(_run, Armory.UNLOCK_FLAG)


func _take_steps() -> void:
	Corners.take(_run, STEPS)
	_run.corner_defenders.erase(String(STEPS))


func _guards_with_rifles(amount: int) -> Dictionary:
	_run.army_level = 1
	Army.add(_run, Army.Tier.GUARDS, Army.State.ACTIVE, amount)
	_run.armory = { Armory.Grade.RIFLE: amount }
	return Army.deployment(_run)


func test_no_ambush_until_a_corner_is_taken_from_vex() -> void:
	assert_false(VexAmbush.is_due(_run, 0.0), "Mama Lin's corner was bought, not taken")
	_take_steps()
	assert_true(VexAmbush.is_due(_run, 0.0))
	assert_false(VexAmbush.is_due(_run, 0.99))


func test_never_two_close_together() -> void:
	_take_steps()
	_run.last_ambush_day = _run.day - 1
	assert_false(VexAmbush.is_due(_run, 0.0))
	_run.last_ambush_day = _run.day - VexAmbush.MIN_DAYS_BETWEEN
	assert_true(VexAmbush.is_due(_run, 0.0))


func test_the_raiders_come_from_her_biggest_corner() -> void:
	_take_steps()
	var encounter := VexAmbush.start(_run)
	assert_eq(StringName(encounter.corner), STEPS)
	assert_eq(StringName(encounter.source), LANTERN)
	assert_eq(int(encounter.raiders), roundi((1200 + 2000) * VexAmbush.RAIDING_SHARE))
	assert_eq(_run.last_ambush_day, _run.day)


func test_rabbit_holds_where_the_same_men_without_him_fall() -> void:
	_take_steps()
	var encounter := VexAmbush.start(_run)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(_run.to_dict()))
	var held := VexAmbush.defend(_run, encounter, _guards_with_rifles(250), true, 0.5, 0.5)
	assert_true(held.won)
	assert_true(Corners.holds(_run, STEPS))
	assert_eq(War.defenders(_run, Corners.find(LANTERN)), 2000 - roundi(960 * VexAmbush.RAIDERS_LOST_ON_WIN))

	_run = RunState.from_dict(saved)
	var lost := VexAmbush.defend(_run, encounter, _guards_with_rifles(250), false, 0.5, 0.5)
	assert_false(lost.won)
	assert_false(Corners.holds(_run, STEPS), "the corner goes back to Vex")
	assert_eq(War.defenders(_run, Corners.find(STEPS)), 960 - roundi(960 * War.DEFENDERS_BLED))
	assert_eq(War.defenders(_run, Corners.find(LANTERN)), 2000 - 960)
	assert_gt(int(lost.dead) + int(lost.wounded), 0)


func test_the_encounter_resolves_without_the_countdown_screen() -> void:
	_take_steps()
	_guards_with_rifles(400)
	_run.pending_encounter = VexAmbush.start(_run)
	var labels := Encounters.choices(_run, _run.pending_encounter).map(func(choice: Encounters.Choice) -> StringName: return choice.id)
	assert_eq(labels, [VexAmbush.DELEGATE, VexAmbush.MOBILISE])
	assert_string_contains(Encounters.resolve(_run, VexAmbush.DELEGATE, 0.5), "holds")
	assert_false(Encounters.has_pending(_run))


func test_the_ambush_day_survives_a_save() -> void:
	_run.last_ambush_day = 9
	assert_eq(RunState.from_dict(_run.to_dict()).last_ambush_day, 9)
