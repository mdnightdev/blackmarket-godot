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


func _start_on_steps() -> Dictionary:
	var target := Corners.find(STEPS)
	var from := RivalStrike.source(_run, _vex(), target)
	return RivalStrike.start(_run, _vex(), target, from, RivalStrike.raiders(_run, from))


func test_no_strike_until_a_corner_is_taken() -> void:
	assert_false(RivalStrike.can_strike(_run, _vex()), "Mama Lin's corner was bought, not taken")
	_take_steps()
	assert_true(RivalStrike.can_strike(_run, _vex()))
	assert_false(RivalStrike.check(_run, true, 0.99))
	assert_false(RivalStrike.check(_run, false, 0.0), "only when a day starts")
	assert_true(RivalStrike.check(_run, true, 0.0))
	assert_eq(_run.pending_encounter.type, RivalStrike.TYPE)
	assert_eq(Gangs.of_encounter(_run.pending_encounter), _vex())


func test_each_gang_waits_between_strikes() -> void:
	_take_steps()
	Rivals.note_strike(_run, _vex(), _run.day - 1)
	assert_false(RivalStrike.can_strike(_run, _vex()))
	Rivals.note_strike(_run, _vex(), _run.day - RivalStrike.MIN_DAYS_BETWEEN)
	assert_true(RivalStrike.can_strike(_run, _vex()))


func test_a_gang_only_strikes_when_it_likes_the_odds() -> void:
	_take_steps()
	_guards_with_rifles(1000)
	assert_false(RivalStrike.check(_run, true, 0.0), "the player's force is too strong to hit")
	assert_true(_run.pending_encounter.is_empty())


func test_the_raiders_come_from_the_biggest_corner_nearby() -> void:
	_take_steps()
	var encounter := _start_on_steps()
	assert_eq(StringName(encounter.corner), STEPS)
	assert_eq(StringName(encounter.source), LANTERN)
	assert_eq(int(encounter.raiders), roundi((1200 + 2000) * RivalStrike.RAIDING_SHARE))
	assert_string_contains(str(encounter.body), "Vex's crew")
	assert_eq(Rivals.last_strike_day(_run, _vex()), _run.day)


func test_rabbit_holds_where_the_same_men_without_him_fall() -> void:
	_take_steps()
	var encounter := _start_on_steps()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(_run.to_dict()))
	var held := RivalStrike.defend(_run, encounter, _guards_with_rifles(250), true, 0.5, 0.5)
	assert_true(held.won)
	assert_true(Corners.holds(_run, STEPS))
	assert_eq(War.defenders(_run, Corners.find(LANTERN)), 2000 - roundi(960 * RivalStrike.RAIDERS_LOST_ON_WIN))

	_run = RunState.from_dict(saved)
	var lost := RivalStrike.defend(_run, encounter, _guards_with_rifles(250), false, 0.5, 0.5)
	assert_false(lost.won)
	assert_false(Corners.holds(_run, STEPS), "the corner goes back to Vex")
	assert_eq(War.defenders(_run, Corners.find(STEPS)), 960 - roundi(960 * War.DEFENDERS_BLED))
	assert_eq(War.defenders(_run, Corners.find(LANTERN)), 2000 - 960)
	assert_gt(int(lost.dead) + int(lost.wounded), 0)


func test_the_encounter_resolves_without_the_countdown_screen() -> void:
	_take_steps()
	_guards_with_rifles(400)
	_run.pending_encounter = _start_on_steps()
	var labels := Encounters.choices(_run, _run.pending_encounter).map(func(choice: Encounters.Choice) -> StringName: return choice.id)
	assert_eq(labels, [RivalStrike.DELEGATE, RivalStrike.MOBILISE])
	assert_string_contains(Encounters.resolve(_run, RivalStrike.DELEGATE, 0.5), "holds")
	assert_false(Encounters.has_pending(_run))


func test_old_market_is_safe_once_vex_kneels() -> void:
	Corners.take_all(_run, Corners.HOME)
	Story.mark(_run, War.VEX_FELL)
	assert_true(RivalStrike.targets(_run, _vex()).is_empty())


func test_any_rival_strikes_back_in_act_two() -> void:
	Corners.take_all(_run, Corners.HOME)
	Story.mark(_run, War.VEX_FELL)
	var jackal := Content.gang(&"jackal")
	Corners.take(_run, &"loading_bay")
	var targets := RivalStrike.targets(_run, jackal)
	assert_eq(targets.size(), 1)
	assert_eq(targets[0].id, &"loading_bay")
	assert_true(RivalStrike.check(_run, true, 0.0))
	var encounter := _run.pending_encounter
	assert_eq(Gangs.of_encounter(encounter), jackal)
	assert_eq(StringName(encounter.source), &"jackal_lockup")
	assert_eq(int(encounter.raiders), roundi((2500 + 3000 + 5000) * RivalStrike.RAIDING_SHARE))
	assert_string_contains(str(encounter.body), "Jackal's crew")
	assert_string_contains(str(encounter.body), "handguns")
	var result := RivalStrike.defend(_run, encounter, {}, false, 0.5, 0.5)
	assert_false(result.won, "nobody went")
	assert_false(Corners.holds(_run, &"loading_bay"))
	assert_string_contains(RivalStrike.summary(result), "Jackal's crew")


func test_old_saves_keep_the_ambush_day_and_a_pending_ambush() -> void:
	_take_steps()
	var data := _run.to_dict()
	data.erase("rivals")
	data["last_ambush_day"] = 9
	data["pending_encounter"] = { "type": "vex_ambush", "corner": "tran_steps", "source": "lantern", "raiders": 300 }
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(data)))
	assert_eq(Rivals.last_strike_day(restored, _vex()), 9)
	assert_eq(restored.pending_encounter.type, RivalStrike.TYPE)
	assert_eq(Gangs.of_encounter(restored.pending_encounter), _vex())


func test_the_strike_day_survives_a_save() -> void:
	Rivals.note_strike(_run, _vex(), 9)
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(_run.to_dict())))
	assert_eq(Rivals.last_strike_day(restored, _vex()), 9)


func _vex() -> GangDef:
	return Content.gang(&"vex")
