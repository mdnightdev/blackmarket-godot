extends GutTest

var _run: RunState
var _phones: ItemDef


func before_each() -> void:
	_run = RunState.new()
	_run.day = 10
	_phones = Content.item(&"burner_phones")
	Inventory.add_units(_run, _phones.id, 8)


func test_ramos_follows_the_sharks_book() -> void:
	assert_eq(Ramos.book(_run), Ramos.Book.SHARK)
	assert_false(Ramos.is_asset(_run))
	_run.shark_bought = true
	assert_eq(Ramos.book(_run), Ramos.Book.PLAYER)
	assert_true(Ramos.is_asset(_run))
	_run.shark_bought = false
	_run.lender = Loan.VEX_LENDER
	assert_true(Ramos.is_hostile(_run))
	Story.mark(_run, War.BOOK_BURNED)
	assert_eq(Ramos.book(_run), Ramos.Book.NOBODY)


func test_a_raid_becomes_a_tip_once_he_is_the_players() -> void:
	_run.heat = Heat.MAX
	assert_eq(str(Encounters.raid_or_warning(_run).type), Encounters.RAID)
	_run.heat = Heat.MAX
	_run.shark_bought = true
	assert_eq(str(Encounters.raid_or_warning(_run).type), Ramos.TIP)


func test_clearing_out_leaves_brandt_nothing_but_raises_the_leak_hunt() -> void:
	_run.shark_bought = true
	_run.heat = Heat.MAX
	var result := Ramos.resolve(_run, Ramos.CLEAR_OUT)
	assert_false(result.found)
	assert_eq(Inventory.count(_run, _phones.id), 8)
	assert_eq(_run.leak_suspicion, 1)
	assert_eq(_run.heat, Police.HEAT_AFTER_ARREST)
	assert_eq(_run.busts, 0, "an empty raid is not a bust")


func test_leaving_goods_feeds_brandt_and_calms_the_leak_hunt() -> void:
	_run.shark_bought = true
	_run.leak_suspicion = 2
	var result := Ramos.resolve(_run, Ramos.LEAVE_GOODS)
	assert_true(result.found)
	assert_eq(result.units, 2)
	assert_eq(Inventory.count(_run, _phones.id), 6)
	assert_eq(_run.leak_suspicion, 1)


func test_too_many_empty_raids_send_him_quiet() -> void:
	_run.shark_bought = true
	for raid in Ramos.LEAK_LIMIT:
		Ramos.resolve(_run, Ramos.CLEAR_OUT)
	assert_true(Ramos.is_lying_low(_run))
	assert_false(Ramos.can_tip(_run))
	assert_eq(_run.leak_suspicion, 0)
	_run.heat = Heat.MAX
	assert_ne(str(Encounters.raid_or_warning(_run).type), Ramos.TIP)
	_run.day += Ramos.QUIET_DAYS
	assert_true(Ramos.can_tip(_run))


func test_he_returns_rabbits_medal_when_he_comes_over() -> void:
	_run.rabbit_medal_held = true
	var pages := Ramos.join_player(_run)
	assert_eq(pages.size(), 1 + Ramos.MEDAL_LINES.size())
	assert_false(_run.rabbit_medal_held)
	assert_eq(Ramos.join_player(_run).size(), 1, "only once")


func test_vexs_ramos_raids_the_stash_too() -> void:
	_run.lender = Loan.VEX_LENDER
	_run.stash = { _phones.id: 10 }
	var raid := Encounters.raid(_run)
	assert_eq(StringName(raid.speaker), Ramos.ID)
	assert_lt(int(_run.stash.get(_phones.id, 0)), 10)


func test_brandts_raid_leaves_the_stash_alone() -> void:
	_run.stash = { _phones.id: 10 }
	var raid := Encounters.raid(_run)
	assert_eq(StringName(raid.speaker), Police.BRANDT)
	assert_eq(int(_run.stash[_phones.id]), 10)


func test_leak_state_survives_a_save() -> void:
	_run.leak_suspicion = 2
	_run.ramos_quiet_until = 14
	var loaded := RunState.from_dict(JSON.parse_string(JSON.stringify(_run.to_dict())))
	assert_eq(loaded.leak_suspicion, 2)
	assert_eq(loaded.ramos_quiet_until, 14)
