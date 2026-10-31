extends GutTest

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	_run.price_seed = 42
	Story.mark(_run, War.VEX_FELL)


func test_consumables_count_and_burn_from_bag_and_stash() -> void:
	assert_eq(Consumables.count(_run, Consumables.AMMO_9MM), 0)
	assert_false(Consumables.has(_run, Consumables.AMMO_9MM))
	assert_false(Consumables.burn(_run, Consumables.AMMO_9MM))

	Inventory.add_units(_run, Consumables.AMMO_9MM, 2)
	assert_eq(Consumables.count(_run, Consumables.AMMO_9MM), 2)
	assert_true(Consumables.has(_run, Consumables.AMMO_9MM))

	assert_true(Consumables.burn(_run, Consumables.AMMO_9MM))
	assert_eq(Consumables.count(_run, Consumables.AMMO_9MM), 1)

	_run.stash[Consumables.AMMO_9MM] = 3
	assert_eq(Consumables.count(_run, Consumables.AMMO_9MM), 4)

	assert_true(Consumables.burn(_run, Consumables.AMMO_9MM), "burns carried first")
	assert_eq(Inventory.count(_run, Consumables.AMMO_9MM), 0)
	assert_eq(int(_run.stash[Consumables.AMMO_9MM]), 3)

	assert_true(Consumables.burn(_run, Consumables.AMMO_9MM), "burns from stash when bag empty")
	assert_eq(int(_run.stash[Consumables.AMMO_9MM]), 2)


func test_street_meds_heals_wounded_and_rejects_empty_clinic() -> void:
	Inventory.add_units(_run, Consumables.STREET_MEDS, 2)
	assert_false(Consumables.can_use(_run, Consumables.STREET_MEDS), "no wounded troops")

	var res_empty := Consumables.use(_run, Consumables.STREET_MEDS)
	assert_false(res_empty.ok)
	assert_eq(Inventory.count(_run, Consumables.STREET_MEDS), 2)

	Army.add(_run, Army.Tier.LUNATICS, Army.State.WOUNDED, 600)
	assert_eq(Army.wounded(_run), 600)
	assert_true(Consumables.can_use(_run, Consumables.STREET_MEDS))

	var res_heal := Consumables.use(_run, Consumables.STREET_MEDS)
	assert_true(res_heal.ok)
	assert_eq(Inventory.count(_run, Consumables.STREET_MEDS), 1)
	assert_eq(Army.count(_run, Army.Tier.LUNATICS, Army.State.ACTIVE), 500)
	assert_eq(Army.wounded(_run), 100)


func test_fake_ids_activates_guaranteed_pass_and_resets() -> void:
	Inventory.add_units(_run, Consumables.FAKE_IDS, 1)
	assert_false(_run.fake_id_active)

	var res := Consumables.use(_run, Consumables.FAKE_IDS)
	assert_true(res.ok)
	assert_true(_run.fake_id_active)
	assert_eq(Inventory.count(_run, Consumables.FAKE_IDS), 0)

	assert_eq(Talk.police_chance(_run, Talk.SHOW_ID), 1.0)
	var outcome := Talk.resolve_police(_run, Talk.SHOW_ID, 0.5)
	assert_true(bool(outcome.free))
	assert_false(_run.fake_id_active, "cleared after use")


func test_burner_sims_cools_heat() -> void:
	_run.heat = 30
	Inventory.add_units(_run, Consumables.BURNER_SIMS, 2)

	var res := Consumables.use(_run, Consumables.BURNER_SIMS)
	assert_true(res.ok)
	assert_eq(_run.heat, 30 - Consumables.BURNER_HEAT_DROP)


func test_clone_plates_negates_roadblock_push_risk() -> void:
	assert_gt(Roadblocks.push_risk(_run), 0.0)
	Inventory.add_units(_run, Consumables.CLONE_PLATES, 1)

	var res := Consumables.use(_run, Consumables.CLONE_PLATES)
	assert_true(res.ok)
	assert_true(_run.clone_plates_active)
	assert_eq(Roadblocks.push_risk(_run), 0.0)


func test_zero_day_drive_wipes_heat_and_requires_heat() -> void:
	Inventory.add_units(_run, Consumables.ZERO_DAY_DRIVE, 1)
	_run.heat = 0
	assert_false(Consumables.can_use(_run, Consumables.ZERO_DAY_DRIVE))

	_run.heat = 40
	assert_true(Consumables.can_use(_run, Consumables.ZERO_DAY_DRIVE))
	var res := Consumables.use(_run, Consumables.ZERO_DAY_DRIVE)
	assert_true(res.ok)
	assert_eq(_run.heat, 40 - Consumables.ZERO_DAY_HEAT_DROP)


func test_network_tap_scouts_all_rivals() -> void:
	Inventory.add_units(_run, Consumables.NETWORK_TAP, 1)
	var res := Consumables.use(_run, Consumables.NETWORK_TAP)
	assert_true(res.ok)
	assert_gt(_run.scouted.size(), 0)
	for corner_id in _run.scouted:
		var entry: Dictionary = _run.scouted[corner_id]
		assert_false(bool(entry.seen))
		assert_eq(int(entry.low), int(entry.high))


func test_ransomware_kit_freezes_rival_recruitment() -> void:
	Inventory.add_units(_run, Consumables.RANSOMWARE_KIT, 1)
	var gang := Content.gang(&"jackal")
	assert_not_null(gang)

	var res := Consumables.use(_run, Consumables.RANSOMWARE_KIT, { "gang_id": &"jackal" })
	assert_true(res.ok)
	assert_eq(int(_run.rival_ransomware[&"jackal"]), _run.day + Consumables.RANSOMWARE_DAYS)

	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var notice := RivalMoves.execute_move(_run, gang, { "move": RivalMoves.Move.RECRUIT_AND_ARM }, rng)
	assert_false(notice.is_empty())
	assert_true(str(notice.line).contains("ransomware"))


func test_sniper_rifle_negates_stronghold() -> void:
	var corner := Corners.find(&"jackal_lockup")
	assert_not_null(corner)
	assert_true(corner.stronghold)

	var normal_power := War.enemy_power(_run, corner)
	_run.sniper_active = true
	var negated_power := War.enemy_power(_run, corner)
	assert_almost_eq(negated_power * War.STRONGHOLD_FACTOR, normal_power, 0.1)


func test_armory_atlas_mapping() -> void:
	for grade in [Armory.Grade.BLADE, Armory.Grade.HANDGUN, Armory.Grade.RIFLE, Armory.Grade.MILITARY]:
		var item_id := Armory.item_id(grade)
		assert_false(item_id.is_empty())
		var icon := ItemsAtlas.get_icon(item_id)
		assert_not_null(icon)
		assert_true(icon is AtlasTexture)


func test_consumables_survive_save_and_load() -> void:
	_run.fake_id_active = true
	_run.clone_plates_active = true
	_run.sniper_active = true
	_run.rival_ransomware[&"vex"] = 5

	var data := _run.to_dict()
	var restored := RunState.from_dict(data)

	assert_true(restored.fake_id_active)
	assert_true(restored.clone_plates_active)
	assert_true(restored.sniper_active)
	assert_eq(int(restored.rival_ransomware[&"vex"]), 5)
