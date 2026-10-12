extends GutTest

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	_run.career = true
	Story.mark(_run, War.VEX_FELL)
	_run.cash = 50_000
	_run.stash_level = Safehouse.UPGRADES.size()
	_run.street_cred = StreetCred.MAX


func test_bag_grows_with_pack_mule_and_runner() -> void:
	var base := Inventory.capacity(_run)
	assert_eq(Skills.upgrade(_run, &"pack_mule"), Skills.Result.OK)
	assert_eq(Crew.hire(_run, &"runner"), Crew.Result.OK)
	assert_eq(Inventory.capacity(_run), base + Skills.capacity_bonus(_run) + Content.crew_role(&"runner").capacity_bonus)


func test_cool_head_cools_heat_faster() -> void:
	_run.heat = 50
	Heat.cool_down(_run, false)
	var plain := _run.heat
	_run.heat = 50
	Skills.upgrade(_run, &"cool_head")
	Heat.cool_down(_run, false)
	assert_eq(_run.heat, plain - Skills.extra_cooling(_run))


func test_driver_lowers_police_stops() -> void:
	Inventory.add_units(_run, &"street_meds", 15)
	var before := Police.stop_chance(_run)
	Crew.hire(_run, &"driver")
	assert_lt(Police.stop_chance(_run), before)


func test_lookout_lowers_police_stops() -> void:
	Inventory.add_units(_run, &"street_meds", 15)
	_run.heat = 0
	var plain := Police.stop_chance(_run)
	Crew.hire(_run, &"lookout")
	assert_almost_eq(Police.stop_chance(_run), plain * Crew.stop_factor(_run), 0.0001)


func test_haggler_lowers_buy_prices() -> void:
	var dealer := Content.dealer_in(&"old_market")
	var item := Content.item(&"street_meds")
	var plain := Market.buy_price(_run, dealer, item)
	Skills.upgrade(_run, &"haggler")
	Skills.upgrade(_run, &"haggler")
	Skills.upgrade(_run, &"haggler")
	assert_lt(Market.buy_price(_run, dealer, item), plain)


func test_smuggler_raises_crate_pay() -> void:
	var crate := { "pay": 1000 }
	assert_eq(Smuggling.payout(_run, crate), 1000)
	Skills.upgrade(_run, &"smuggler")
	assert_eq(Smuggling.payout(_run, crate), 1100)


func test_lookout_turns_a_raid_into_a_warning_once_a_day() -> void:
	Crew.hire(_run, &"lookout")
	_run.heat = Heat.MAX
	var warning := Encounters.raid_or_warning(_run)
	assert_eq(warning.type, Encounters.RAID_WARNING)
	assert_eq(_run.heat, Heat.MAX - Encounters.RAID_WARNING_COOLING)
	_run.heat = Heat.MAX
	_run.pending_encounter = {}
	assert_eq(Encounters.raid_or_warning(_run).type, Encounters.RAID)


func test_warning_needs_a_lookout() -> void:
	_run.heat = Heat.MAX
	assert_eq(Encounters.raid_or_warning(_run).type, Encounters.RAID)


func test_crew_fight_bonus_helps_against_muggers_and_vex() -> void:
	var street := StreetEvents.fight_chance(_run)
	var vex := Turf.fight_chance(_run, &"old_market")
	Crew.hire(_run, &"muscle")
	assert_gt(StreetEvents.fight_chance(_run), street)
	assert_gt(Turf.fight_chance(_run, &"old_market"), vex)


func test_shelved_goods_keep_their_cost_basis() -> void:
	_run.cost_basis[&"street_meds"] = 40
	_run.businesses.append({ "business": "corner_shop", "district": "old_market", "stock": { "street_meds": 5 }, "closed_until": 0 })
	Inventory.add_units(_run, &"street_meds", 2)
	Inventory.discard(_run, &"street_meds", 2)
	assert_eq(int(_run.cost_basis.get(&"street_meds", 0)), 40)
