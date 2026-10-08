extends GutTest

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	_run.price_seed = 1357
	_run.district_id = Smuggling.ORIGIN
	_run.cash = 10000


func _first_offer() -> Dictionary:
	return Smuggling.board(_run)[0]


func _target(offer: Dictionary) -> StringName:
	return StringName(str(offer.destination))


func test_roads_run_both_ways_and_reach_every_district() -> void:
	var districts := Content.districts()
	for district in districts:
		assert_false(district.roads.is_empty(), "%s has a road" % district.id)
		for next in district.roads:
			var other := Content.district(next)
			assert_not_null(other, "%s road to %s" % [district.id, next])
			assert_true(other.roads.has(district.id), "%s road back to %s" % [next, district.id])
	var reached: Array[StringName] = [districts[0].id]
	var index := 0
	while index < reached.size():
		for next in Content.district(reached[index]).roads:
			if not reached.has(next):
				reached.append(next)
		index += 1
	assert_eq(reached.size(), districts.size())


func test_the_last_crate_on_the_board_is_a_long_run() -> void:
	var origin := Content.district(Smuggling.ORIGIN)
	for day in range(1, 8):
		_run.day = day
		var offers := Smuggling.board(_run)
		var last: Dictionary = offers[Smuggling.POSTED_PER_DAY - 1]
		assert_false(origin.roads.has(_target(last)), "day %d goes to %s" % [day, last.destination])


func test_paths_follow_roads_and_end_at_the_destination() -> void:
	var found := Routes.paths(&"docks", &"north_port")
	assert_false(found.is_empty())
	for path in found:
		assert_eq(path[-1], &"north_port")
		assert_lte(path.size(), Routes.MAX_STOPS)
		var previous: StringName = &"docks"
		for stop: StringName in path:
			assert_true(Content.district(previous).roads.has(stop), "%s to %s" % [previous, stop])
			previous = stop


func test_options_put_the_shortest_route_first() -> void:
	var options := Routes.options(_run, &"docks", &"north_port")
	var shortest: Array = Routes.paths(&"docks", &"north_port").reduce(func(best: Array, path: Array) -> Array: return path if path.size() < best.size() else best)
	assert_eq(options[0].size(), shortest.size())
	if options.size() > 1:
		var stamp := Calendar.stamp(_run)
		assert_lt(Routes.route_risk(_run, options[1], stamp), Routes.route_risk(_run, options[0], stamp))


func test_recon_costs_cash_halves_the_risk_and_lasts_the_phase() -> void:
	var stamp := Calendar.stamp(_run)
	var before := Routes.stop_risk(_run, &"slums", stamp)
	assert_true(Routes.buy_recon(_run))
	assert_eq(_run.cash, 10000 - Routes.RECON_COST)
	assert_almost_eq(Routes.stop_risk(_run, &"slums", stamp), clampf(before * Routes.RECON_FACTOR, Routes.MIN_RISK, Routes.MAX_RISK), 0.0001)
	assert_false(Routes.buy_recon(_run), "already scouted this phase")
	Calendar.advance_phase(_run)
	assert_false(Routes.has_recon(_run))


func test_recon_needs_the_cash() -> void:
	_run.cash = Routes.RECON_COST - 1
	assert_false(Routes.buy_recon(_run))
	assert_eq(_run.cash, Routes.RECON_COST - 1)


func test_a_lookout_scouts_every_route_for_free() -> void:
	_run.crew.append({ "role": "lookout", "hired_day": 1, "unpaid_days": 0 })
	assert_true(Routes.has_recon(_run))
	assert_false(Routes.buy_recon(_run))
	assert_eq(_run.cash, 10000)


func test_accept_keeps_a_valid_route_and_rejects_a_broken_one() -> void:
	var offer := _first_offer()
	var target := _target(offer)
	var broken: Array[StringName] = [target, target]
	assert_eq(Smuggling.accept(_run, offer, broken), Smuggling.Result.NO_ROUTE)
	assert_false(Smuggling.is_carrying(_run))
	var route: Array[StringName] = []
	route.assign(Routes.paths(Smuggling.ORIGIN, target)[-1])
	assert_eq(Smuggling.accept(_run, offer, route), Smuggling.Result.OK)
	assert_eq(Smuggling.stops_left(_run.crate), route)


func test_accept_without_a_route_takes_the_shortest() -> void:
	var offer := _first_offer()
	Smuggling.accept(_run, offer)
	var options := Routes.options(_run, Smuggling.ORIGIN, _target(offer))
	assert_eq(Smuggling.stops_left(_run.crate), Array(options[0]))


func test_following_the_route_keeps_the_full_pay() -> void:
	var offer := _first_offer()
	Smuggling.accept(_run, offer)
	for stop in Smuggling.stops_left(_run.crate):
		_run.district_id = stop
		Smuggling.record_stop(_run)
	assert_false(bool(_run.crate.off_route))
	assert_true(Smuggling.stops_left(_run.crate).is_empty())
	assert_eq(Smuggling.deliver(_run), int(offer.pay))


func test_leaving_the_route_cuts_the_pay() -> void:
	var offer := _first_offer()
	var target := _target(offer)
	var route: Array[StringName] = []
	route.assign(Routes.paths(Smuggling.ORIGIN, target)[0])
	Smuggling.accept(_run, offer, route)
	var detour: StringName = &""
	for district in Content.districts():
		if district.id != route[0] and district.id != Smuggling.ORIGIN:
			detour = district.id
			break
	_run.district_id = detour
	Smuggling.record_stop(_run)
	assert_true(bool(_run.crate.off_route))
	_run.district_id = target
	assert_eq(Smuggling.deliver(_run), roundi(int(offer.pay) * Smuggling.OFF_ROUTE_PAY))


func test_route_progress_and_recon_survive_a_save() -> void:
	Smuggling.accept(_run, _first_offer())
	var first: StringName = Smuggling.stops_left(_run.crate)[0]
	_run.district_id = first
	Smuggling.record_stop(_run)
	Routes.buy_recon(_run)
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(_run.to_dict())))
	assert_eq(restored.crate.route, _run.crate.route)
	assert_eq(int(restored.crate.stop), int(_run.crate.stop))
	assert_eq(bool(restored.crate.off_route), false)
	assert_eq(restored.recon_stamp, _run.recon_stamp)


func test_a_bad_saved_route_falls_back_to_the_destination() -> void:
	Smuggling.accept(_run, _first_offer())
	var data := _run.to_dict()
	data.crate.route = ["nowhere"]
	data.crate.stop = 9
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(data)))
	assert_eq(restored.crate.route, [str(restored.crate.destination)])
	assert_eq(int(restored.crate.stop), 1)


func test_no_ambush_without_a_crate() -> void:
	assert_false(Routes.ambush_due(_run, 0.0))
	Smuggling.accept(_run, _first_offer())
	assert_true(Routes.ambush_due(_run, 0.0))
	assert_false(Routes.ambush_due(_run, 0.999))


func _crew_ambush() -> Dictionary:
	return { "type": Ambush.TYPE, "threat": Routes.Threat.QUIET, "toll": 300, "skim": 0.2 }


func test_ambush_toll_costs_cash_and_keeps_the_crate() -> void:
	Smuggling.accept(_run, _first_offer())
	Ambush.resolve(_run, _crew_ambush(), Ambush.PAY, 0.0)
	assert_eq(_run.cash, 10000 - 300)
	assert_true(Smuggling.is_carrying(_run))


func test_toll_and_skim_stay_inside_their_limits() -> void:
	var offer := _first_offer()
	Smuggling.accept(_run, offer)
	for stamp in 30:
		Calendar.advance_phase(_run)
		var encounter := Ambush.start(_run)
		if encounter.type != Ambush.TYPE:
			continue
		assert_between(int(encounter.toll), maxi(Ambush.MIN_TOLL, floori(int(offer.pay) * Ambush.TOLL_LOW)), maxi(Ambush.MIN_TOLL, ceili(int(offer.pay) * Ambush.TOLL_HIGH)))
		assert_between(float(encounter.skim), Ambush.SKIM_LOW, Ambush.SKIM_HIGH)


func test_losing_an_ambush_fight_skims_the_cargo_but_keeps_the_crate() -> void:
	var offer := _first_offer()
	Smuggling.accept(_run, offer)
	Ambush.resolve(_run, _crew_ambush(), Ambush.FIGHT, 0.999)
	assert_true(Smuggling.is_carrying(_run))
	assert_false(Smuggling.is_banned(_run))
	_run.district_id = _target(offer)
	assert_eq(Smuggling.deliver(_run), roundi(int(offer.pay) * 0.8))


func test_skims_never_take_more_than_the_cap() -> void:
	var offer := _first_offer()
	Smuggling.accept(_run, offer)
	for attempt in 4:
		Ambush.resolve(_run, _crew_ambush(), Ambush.RUN, 0.999)
	assert_almost_eq(float(_run.crate.skimmed), Smuggling.MAX_SKIM, 0.0001)
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(_run.to_dict())))
	assert_almost_eq(float(restored.crate.skimmed), Smuggling.MAX_SKIM, 0.0001)


func test_escaping_an_ambush_keeps_the_crate_but_adds_heat() -> void:
	Smuggling.accept(_run, _first_offer())
	var heat_before := _run.heat
	Ambush.resolve(_run, _crew_ambush(), Ambush.RUN, 0.0)
	assert_true(Smuggling.is_carrying(_run))
	assert_eq(_run.heat, heat_before + Ambush.ESCAPED_HEAT)


func test_ambush_is_a_police_stop_or_a_crew_after_the_crate() -> void:
	Smuggling.accept(_run, _first_offer())
	var encounter := Ambush.start(_run)
	if Routes.threat(_run, _run.district_id, Calendar.stamp(_run)) == Routes.Threat.POLICE:
		assert_eq(encounter.type, Encounters.POLICE)
	else:
		assert_eq(encounter.type, Ambush.TYPE)
		assert_gte(int(encounter.toll), Ambush.MIN_TOLL)
		assert_not_null(Content.speaker(StringName(str(encounter.speaker))))
		assert_eq(Encounters.choices(_run, encounter).size(), 3)
