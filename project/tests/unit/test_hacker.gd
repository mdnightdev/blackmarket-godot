extends GutTest

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	_run.price_seed = 31337
	_run.district_id = &"downtown"
	_run.cash = 5000


func test_targets_are_other_districts_with_dealers() -> void:
	var stamp := Calendar.stamp(_run)
	var targets := Hacker.targets(_run)
	assert_false(targets.is_empty())
	for district in targets:
		assert_ne(district.id, _run.district_id)
		assert_false(Roster.dealers_at(_run, district.id, stamp).is_empty(), String(district.id))


func test_hack_records_every_dealer_in_the_district() -> void:
	var target := Hacker.targets(_run)[0]
	var dealers := Hacker.hack(_run, target.id)
	assert_eq(dealers, Roster.dealers_at(_run, target.id, Calendar.stamp(_run)))
	assert_eq(_run.cash, 5000 - Hacker.PRICE)
	assert_true(Hacker.hacked_this_phase(_run))
	for dealer in dealers:
		assert_true(_run.price_sightings.any(func(sighting: Dictionary) -> bool: return sighting.dealer == String(dealer.id)), String(dealer.id))


func test_one_hack_per_phase() -> void:
	var target := Hacker.targets(_run)[0]
	Hacker.hack(_run, target.id)
	assert_true(Hacker.hack(_run, target.id).is_empty())
	assert_eq(_run.cash, 5000 - Hacker.PRICE)
	Calendar.advance_phase(_run)
	assert_false(Hacker.hacked_this_phase(_run))


func test_hack_needs_cash_and_another_district() -> void:
	var target := Hacker.targets(_run)[0]
	_run.cash = Hacker.PRICE - 1
	assert_true(Hacker.hack(_run, target.id).is_empty())
	_run.cash = 5000
	assert_true(Hacker.hack(_run, _run.district_id).is_empty())
	assert_eq(_run.cash, 5000)


func test_hack_stamp_is_saved() -> void:
	_run.hack_stamp = 6
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(_run.to_dict())))
	assert_eq(restored.hack_stamp, 6)
