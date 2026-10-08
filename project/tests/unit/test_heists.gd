extends GutTest

const VAN: StringName = &"armored_van"
const VAULT: StringName = &"golden_dragon_vault"
const RED_LOTUS: StringName = &"red_lotus"
const AZURE_DRAGON: StringName = &"azure_dragon"

var _run: RunState
var _van: HeistDef


func before_each() -> void:
	_run = RunState.new()
	_run.career = true
	_run.cash = 100_000
	_run.stash_level = Safehouse.UPGRADES.size()
	_run.district_id = &"old_market"
	_set_rank(8)
	_van = Content.heist(VAN)


func _set_rank(rank_number: int) -> void:
	_run.street_cred = int(StreetCred.RANKS[rank_number - 1].cred)


func _hire_for(heist: HeistDef) -> void:
	for role_id in heist.required_roles:
		if not Crew.has(_run, role_id):
			assert_eq(Crew.hire(_run, role_id), Crew.Result.OK, String(role_id))


func _ready_vault() -> HeistDef:
	var vault := Content.heist(VAULT)
	_run.district_id = vault.district_id
	_hire_for(vault)
	return vault


func test_every_heist_is_complete() -> void:
	var heists := Content.heists()
	assert_eq(heists.size(), 3)
	for heist in heists:
		assert_false(heist.display_name.is_empty(), String(heist.id))
		assert_false(heist.description.is_empty(), String(heist.id))
		assert_not_null(Content.district(heist.district_id), String(heist.id))
		assert_between(heist.min_rank, 1, StreetCred.max_rank(), String(heist.id))
		assert_false(heist.required_roles.is_empty(), String(heist.id))
		assert_lte(heist.required_roles.size(), 1 + Safehouse.UPGRADES.size(), "%s crew fits the cap" % heist.id)
		for role_id in heist.required_roles:
			assert_not_null(Content.crew_role(role_id), "%s needs %s" % [heist.id, role_id])
		assert_gt(heist.payout, 0, String(heist.id))
		if not heist.target_family.is_empty():
			assert_not_null(Content.family(heist.target_family), String(heist.id))
			assert_gt(heist.standing_loss, 0, String(heist.id))


func test_ready_heist_passes_the_check() -> void:
	_hire_for(_van)
	assert_eq(Heists.check(_run, _van), Heists.Result.OK)
	assert_eq(Heists.days_until_ready(_run, _van), 0)


func test_heists_need_a_career() -> void:
	_hire_for(_van)
	_run.career = false
	assert_eq(Heists.check(_run, _van), Heists.Result.NOT_CAREER)


func test_heists_need_the_rank() -> void:
	_hire_for(_van)
	_set_rank(_van.min_rank - 1)
	assert_eq(Heists.check(_run, _van), Heists.Result.RANK_TOO_LOW)
	_set_rank(_van.min_rank)
	assert_eq(Heists.check(_run, _van), Heists.Result.OK)


func test_heists_need_every_required_role() -> void:
	Crew.hire(_run, _van.required_roles[0])
	assert_eq(Heists.check(_run, _van), Heists.Result.MISSING_CREW)
	assert_eq(Heists.missing_roles(_run, _van), _van.required_roles.slice(1))


func test_heists_happen_in_their_district() -> void:
	_hire_for(_van)
	_run.district_id = &"docks"
	assert_eq(Heists.check(_run, _van), Heists.Result.WRONG_DISTRICT)


func test_each_required_role_raises_the_odds() -> void:
	assert_almost_eq(Heists.success_chance(_run, _van), _van.base_chance, 0.0001)
	Crew.hire(_run, _van.required_roles[0])
	assert_almost_eq(Heists.success_chance(_run, _van), _van.base_chance + Heists.ROLE_BONUS, 0.0001)
	_hire_for(_van)
	assert_almost_eq(Heists.success_chance(_run, _van), _van.base_chance + Heists.ROLE_BONUS * _van.required_roles.size(), 0.0001)


func test_unrequired_crew_adds_nothing() -> void:
	Crew.hire(_run, &"runner")
	assert_almost_eq(Heists.success_chance(_run, _van), _van.base_chance, 0.0001)


func test_district_family_helps_its_own() -> void:
	_hire_for(_van)
	var crewed := Heists.success_chance(_run, _van)
	_run.family_standing[RED_LOTUS] = Families.TRUSTED_AT
	assert_almost_eq(Heists.success_chance(_run, _van), crewed, 0.0001)
	_run.family_standing[RED_LOTUS] = Families.FAMILY_AT
	assert_almost_eq(Heists.success_chance(_run, _van), crewed + Heists.FAMILY_BONUS, 0.0001)


func test_family_does_not_help_rob_itself() -> void:
	var vault := _ready_vault()
	var crewed := Heists.success_chance(_run, vault)
	_run.family_standing[AZURE_DRAGON] = Families.MAX_STANDING
	assert_almost_eq(Heists.success_chance(_run, vault), crewed, 0.0001)


func test_success_chance_is_capped() -> void:
	var easy := HeistDef.new()
	easy.id = &"easy_job"
	easy.district_id = _run.district_id
	easy.base_chance = Heists.MAX_CHANCE
	easy.required_roles.append(&"runner")
	Crew.hire(_run, &"runner")
	assert_almost_eq(Heists.success_chance(_run, easy), Heists.MAX_CHANCE, 0.0001)


func test_success_pays_out() -> void:
	_hire_for(_van)
	var cash_before := _run.cash
	var cred_before := _run.street_cred
	var outcome := Heists.attempt(_run, _van, 0.0, 0.0)
	assert_eq(outcome, { "success": true, "payout": _van.payout, "lost_role": "" })
	assert_eq(_run.cash, cash_before + _van.payout)
	assert_eq(_run.profit, _van.payout)
	assert_eq(_run.heat, _van.heat)
	assert_eq(_run.street_cred, cred_before + _van.cred)
	assert_false(Encounters.has_pending(_run))
	assert_eq(_run.crew.size(), _van.required_roles.size(), "a clean job keeps the crew")


func test_robbing_a_family_costs_standing() -> void:
	var vault := _ready_vault()
	var rival := Content.family(AZURE_DRAGON).rival
	var outcome := Heists.attempt(_run, vault, 0.0, 0.0)
	assert_true(outcome.success)
	assert_eq(Families.standing(_run, AZURE_DRAGON), -vault.standing_loss)
	assert_eq(Families.standing(_run, rival), 0)


func test_failure_brings_heat_and_the_police() -> void:
	_hire_for(_van)
	var cash_before := _run.cash
	var outcome := Heists.attempt(_run, _van, 0.99, 0.99)
	assert_eq(outcome, { "success": false, "payout": 0, "lost_role": "" })
	assert_eq(_run.cash, cash_before)
	assert_eq(_run.profit, 0)
	assert_eq(_run.heat, Heists.FAILED_HEAT)
	assert_eq(_run.pending_encounter.type, Encounters.POLICE)
	assert_eq(_run.crew.size(), _van.required_roles.size())


func test_a_roll_at_the_odds_fails() -> void:
	_hire_for(_van)
	var outcome := Heists.attempt(_run, _van, Heists.success_chance(_run, _van), 0.99)
	assert_false(outcome.success)


func test_failure_keeps_an_encounter_already_waiting() -> void:
	_hire_for(_van)
	_run.pending_encounter = { "type": Encounters.RAID }
	Heists.attempt(_run, _van, 0.99, 0.99)
	assert_eq(_run.pending_encounter.type, Encounters.RAID)


func test_failure_can_cost_a_crew_member() -> void:
	var cases := [
		[0.0, _van.required_roles[0]],
		[Heists.CREW_LOSS_CHANCE * 0.75, _van.required_roles[1]],
	]
	for entry: Array in cases:
		_run.heist_cooldowns.clear()
		_run.pending_encounter = {}
		_hire_for(_van)
		var outcome := Heists.attempt(_run, _van, 0.99, float(entry[0]))
		var lost: StringName = entry[1]
		assert_eq(outcome.lost_role, String(lost))
		assert_false(Crew.has(_run, lost), String(lost))
		assert_eq(_run.crew.size(), _van.required_roles.size() - 1)


func test_lost_role_is_picked_across_the_whole_crew() -> void:
	var vault := _ready_vault()
	var count := vault.required_roles.size()
	var crew_roll := Heists.CREW_LOSS_CHANCE * (count - 1.5) / count
	var outcome := Heists.attempt(_run, vault, 0.99, crew_roll)
	assert_eq(outcome.lost_role, String(vault.required_roles[count - 2]))


func test_crew_roll_above_the_chance_keeps_everyone() -> void:
	_hire_for(_van)
	var outcome := Heists.attempt(_run, _van, 0.99, Heists.CREW_LOSS_CHANCE)
	assert_eq(outcome.lost_role, "")
	assert_eq(_run.crew.size(), _van.required_roles.size())


func test_heists_rest_after_an_attempt() -> void:
	_hire_for(_van)
	_run.day = 5
	Heists.attempt(_run, _van, 0.99, 0.99)
	assert_eq(int(_run.heist_cooldowns[VAN]), 5 + Heists.COOLDOWN_DAYS)
	assert_eq(Heists.check(_run, _van), Heists.Result.COOLDOWN)
	assert_eq(Heists.days_until_ready(_run, _van), Heists.COOLDOWN_DAYS)
	_run.day += Heists.COOLDOWN_DAYS - 1
	assert_eq(Heists.days_until_ready(_run, _van), 1)
	_run.day += 1
	assert_eq(Heists.days_until_ready(_run, _van), 0)
	assert_eq(Heists.check(_run, _van), Heists.Result.OK)


func test_blocked_attempt_changes_nothing() -> void:
	_hire_for(_van)
	_run.heist_cooldowns[VAN] = _run.day + 1
	var cash_before := _run.cash
	var outcome := Heists.attempt(_run, _van, 0.0, 0.0)
	assert_eq(outcome, { "success": false, "payout": 0, "lost_role": "" })
	assert_eq(_run.cash, cash_before)
	assert_eq(_run.heat, 0)
	assert_eq(int(_run.heist_cooldowns[VAN]), _run.day + 1)
	assert_false(Encounters.has_pending(_run))
	assert_eq(_run.crew.size(), _van.required_roles.size())


func test_cooldowns_survive_a_save() -> void:
	_hire_for(_van)
	_run.day = 9
	Heists.attempt(_run, _van, 0.0, 0.0)
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(_run.to_dict())))
	assert_eq(Heists.days_until_ready(restored, _van), Heists.COOLDOWN_DAYS)
