extends GutTest

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	_run.price_seed = 1357
	_run.district_id = Smuggling.ORIGIN
	_run.cash = 10000


func _first_offer() -> Dictionary:
	return Smuggling.board(_run)[0]


## Finds a run seed where the district has a roadblock at the current phase.
func _block(district_id: StringName) -> void:
	for seed in 5000:
		_run.price_seed = seed
		if Roadblocks.blocks(_run, district_id):
			return
	fail_test("no roadblock found for %s" % district_id)


func test_roadblocks_follow_the_seed_and_stay_up_until_their_last_phase() -> void:
	_block(&"slums")
	var stamp := Calendar.stamp(_run)
	var last := Roadblocks.last_blocked_stamp(_run, &"slums", stamp)
	assert_gte(last, stamp)
	assert_eq(Roadblocks.last_blocked_stamp(_run, &"slums", stamp), last)
	for blocked_stamp in range(stamp, last + 1):
		assert_eq(Roadblocks.last_blocked_stamp(_run, &"slums", blocked_stamp), last)
	var phases := RunState.Phase.size()
	assert_lt(last, (floori(float(stamp) / phases) + 1) * phases, "a roadblock ends with the day")


func test_roadblocks_are_rare() -> void:
	var blocked := 0
	var samples := 0
	for seed in 400:
		_run.price_seed = seed
		for district in Content.districts():
			samples += 1
			if Roadblocks.blocks(_run, district.id):
				blocked += 1
	assert_lt(float(blocked) / samples, Roadblocks.DAILY_CHANCE)


func test_only_a_crate_is_stopped() -> void:
	var offer := _first_offer()
	var target := Content.district(StringName(str(offer.destination)))
	_block(target.id)
	assert_false(Roadblocks.stops_crate(_run, target))
	_run.crate = Smuggling.sanitize(offer)
	assert_true(Roadblocks.stops_crate(_run, target))


func test_neighbours_hear_about_roadblocks_and_recon_sees_them_all() -> void:
	var here := Content.district(_run.district_id)
	assert_true(Roadblocks.is_known(_run, here.roads[0]))
	var far := Content.districts().filter(func(d: DistrictDef) -> bool:
		return d.id != here.id and not here.roads.has(d.id))
	assert_false(far.is_empty())
	assert_false(Roadblocks.is_known(_run, far[0].id))
	_run.recon_stamp = Calendar.stamp(_run)
	assert_true(Roadblocks.is_known(_run, far[0].id))


func test_detour_avoids_the_roadblock_and_is_not_off_route() -> void:
	_run.district_id = &"docks"
	_run.crate = { "id": "crate:0:9", "destination": "north_port", "slots": 4, "pay": 2000, "lead": 4, "due": 8 }
	var blocked: DistrictDef = null
	for path in Routes.paths(&"docks", &"north_port"):
		if path.size() > 1:
			blocked = Content.district(path[0])
			break
	assert_not_null(blocked)
	_run.crate = Smuggling.sanitize(_run.crate)
	var detour := Roadblocks.detour(_run, blocked)
	if detour.is_empty():
		pass_test("every other path is blocked today")
		return
	assert_false(detour.has(blocked.id))
	assert_true(Smuggling.reroute(_run, detour))
	_run.district_id = detour[0]
	Smuggling.record_stop(_run)
	assert_false(bool(_run.crate.off_route))


func test_no_detour_around_a_roadblock_at_the_destination() -> void:
	var offer := _first_offer()
	Smuggling.accept(_run, offer)
	assert_true(Roadblocks.detour(_run, Smuggling.destination(_run.crate)).is_empty())


func test_reroute_rejects_a_path_that_does_not_reach_the_drop() -> void:
	Smuggling.accept(_run, _first_offer())
	var wrong: Array[StringName] = [Content.district(_run.district_id).roads[0]]
	if wrong[0] == StringName(str(_run.crate.destination)):
		wrong = [&"nowhere"]
	assert_false(Smuggling.reroute(_run, wrong))


func test_recon_tells_when_the_roadblock_lifts() -> void:
	var here := Content.district(_run.district_id)
	var next: StringName = here.roads[0]
	_block(next)
	assert_string_contains(Routes.describe_stop(_run, next), "roadblock")
	assert_false(Routes.describe_stop(_run, next).contains("until"))
	_run.recon_stamp = Calendar.stamp(_run)
	assert_string_contains(Routes.describe_stop(_run, next), "until %s" % Roadblocks.clears_at(_run, next))


func test_road_danger_shifts_between_phases_within_the_limits() -> void:
	var seen := {}
	for stamp in 12:
		var risk := Routes.stop_risk(_run, &"slums", stamp)
		assert_between(risk, Routes.MIN_RISK, Routes.MAX_RISK)
		seen[snappedf(risk, 0.0001)] = true
	assert_gt(seen.size(), 1)
