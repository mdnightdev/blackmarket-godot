extends GutTest

const STAMPS_CHECKED := 160

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	_run.price_seed = 4242


func test_residents_never_leave_home() -> void:
	for dealer in _residents():
		for stamp in STAMPS_CHECKED:
			assert_eq(Roster.dealer_location(_run, dealer, stamp), dealer.district_id)


func test_every_market_has_a_dealer_in_every_phase() -> void:
	for district in Content.districts():
		if not district.venues.has(&"market"):
			continue
		for stamp in STAMPS_CHECKED:
			assert_false(Roster.dealers_at(_run, district.id, stamp).is_empty(), "%s at %d" % [district.id, stamp])


func test_travellers_follow_their_route_and_hours() -> void:
	for dealer in _travellers():
		for stamp in STAMPS_CHECKED:
			var location := Roster.dealer_location(_run, dealer, stamp)
			if dealer.works_in(stamp % RunState.Phase.size()):
				assert_true(dealer.route.has(location), "%s at %d" % [dealer.id, stamp])
			else:
				assert_eq(location, &"", "%s off duty at %d" % [dealer.id, stamp])


func test_travellers_stay_put_for_the_day_and_move_between_days() -> void:
	for dealer in _travellers():
		var visited := {}
		for day_index in STAMPS_CHECKED / RunState.Phase.size():
			var today: Array[StringName] = []
			for phase: int in dealer.working_phases:
				today.append(Roster.dealer_location(_run, dealer, day_index * RunState.Phase.size() + phase))
			assert_eq(today.count(today[0]), today.size(), "%s on day %d" % [dealer.id, day_index])
			visited[today[0]] = true
		assert_gt(visited.size(), 1, String(dealer.id))


func test_travellers_only_visit_market_districts() -> void:
	for dealer in _travellers():
		assert_not_null(Content.district(dealer.district_id), String(dealer.id))
		for district_id in dealer.route:
			var district := Content.district(district_id)
			assert_not_null(district, "%s route %s" % [dealer.id, district_id])
			assert_true(district.venues.has(&"market"), "%s route %s" % [dealer.id, district_id])


func test_schedule_survives_a_save() -> void:
	var restored := RunState.from_dict(_run.to_dict())
	for stamp in 40:
		for dealer in _travellers():
			assert_eq(Roster.dealer_location(restored, dealer, stamp), Roster.dealer_location(_run, dealer, stamp))
		for character in Content.characters():
			assert_eq(Roster.character_location(restored, character, stamp), Roster.character_location(_run, character, stamp))


func test_fixed_characters() -> void:
	for stamp in STAMPS_CHECKED:
		assert_eq(Roster.character_location(_run, _character(&"shark"), stamp), &"downtown")
		assert_eq(Roster.character_location(_run, _character(&"enforcer"), stamp), &"")


func test_police_patrol_hot_districts_more_often() -> void:
	var officer := _character(&"officer")
	var visits := {}
	for stamp in 2000:
		var location := Roster.character_location(_run, officer, stamp)
		assert_true(officer.route.has(location))
		visits[location] = int(visits.get(location, 0)) + 1
	assert_gt(int(visits.get(&"north_port", 0)), int(visits.get(&"slums", 0)))


func test_patrol_multiplier_uses_the_strongest_officer_present() -> void:
	var detective := _character(&"detective")
	var stamp := _find_stamp(func(at: int) -> bool:
		return Roster.character_location(_run, detective, at) == &"docks")
	assert_eq(Roster.patrol_multiplier(_run, &"docks", stamp), detective.stop_multiplier)

	var quiet := _find_stamp(func(at: int) -> bool:
		return Roster.characters_at(_run, &"slums", at).all(
				func(character: CharacterDef) -> bool: return character.role != CharacterDef.Role.POLICE))
	assert_eq(Roster.patrol_multiplier(_run, &"slums", quiet), 1.0)


func test_patrols_raise_stop_odds() -> void:
	Inventory.add_units(_run, &"burner_phones", 4)
	_run.district_id = &"old_market"
	var patrolled := _find_stamp(func(at: int) -> bool: return Roster.patrol_multiplier(_run, &"old_market", at) > 1.0)
	var quiet := _find_stamp(func(at: int) -> bool: return Roster.patrol_multiplier(_run, &"old_market", at) == 1.0)
	_set_stamp(quiet)
	var calm_chance := Police.stop_chance(_run)
	_set_stamp(patrolled)
	var multiplier := Roster.patrol_multiplier(_run, &"old_market", patrolled)
	assert_almost_eq(Police.stop_chance(_run), minf(calm_chance * multiplier, Police.MAX_STOP_CHANCE), 0.0001)


func test_rival_lowers_what_dealers_pay() -> void:
	var dealer := Content.dealer_in(&"old_market")
	var phones := Content.item(&"burner_phones")
	var with_rival := _find_stamp(func(at: int) -> bool: return Roster.rival_in(_run, &"old_market", at))
	_set_stamp(with_rival)
	var expected := floori(Market.buy_price(_run, dealer, phones) * Market.SELL_SPREAD * Market.RIVAL_SELL_FACTOR)
	assert_eq(Market.sell_price(_run, dealer, phones), maxi(1, expected))

	var without_rival := _find_stamp(func(at: int) -> bool: return not Roster.rival_in(_run, &"old_market", at))
	_set_stamp(without_rival)
	assert_eq(Market.sell_price(_run, dealer, phones), maxi(1, floori(Market.buy_price(_run, dealer, phones) * Market.SELL_SPREAD)))


func _residents() -> Array[DealerDef]:
	var list: Array[DealerDef] = []
	list.assign(Content.dealers().filter(func(dealer: DealerDef) -> bool: return dealer.is_resident()))
	return list


func _travellers() -> Array[DealerDef]:
	var list: Array[DealerDef] = []
	list.assign(Content.dealers().filter(func(dealer: DealerDef) -> bool: return not dealer.is_resident()))
	assert_false(list.is_empty(), "catalog has travelling dealers")
	return list


func _character(id: StringName) -> CharacterDef:
	for character in Content.characters():
		if character.id == id:
			return character
	fail_test("missing character %s" % id)
	return null


func _find_stamp(matches: Callable) -> int:
	for stamp in 400:
		if matches.call(stamp):
			return stamp
	fail_test("no phase stamp matched")
	return 0


func _set_stamp(stamp: int) -> void:
	_run.day = floori(float(stamp) / RunState.Phase.size()) + 1
	_run.phase = (stamp % RunState.Phase.size()) as RunState.Phase
