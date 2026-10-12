extends GutTest

var _run: RunState
var _phones: ItemDef


func before_each() -> void:
	_run = RunState.new()
	_run.price_seed = 2024
	_phones = Content.item(&"burner_phones")


func test_a_bust_takes_less_but_costs_trust_and_time() -> void:
	Inventory.add_units(_run, _phones.id, 10)
	var trust := _run.shark_trust
	var taken := Police.comply(_run)
	assert_eq(taken.quantity, 3)
	assert_eq(Inventory.count(_run, _phones.id), 7)
	assert_eq(_run.shark_trust, trust + SharkTrust.BUSTED)
	assert_almost_eq(_run.phase_seconds_left, Calendar.PHASE_SECONDS - Police.QUESTIONING_SECONDS, 0.01)


func test_a_raid_takes_less_than_half_the_bag() -> void:
	Inventory.add_units(_run, _phones.id, 10)
	Police.arrest(_run)
	assert_eq(Inventory.count(_run, _phones.id), 7)


func test_customers_post_less_until_act_two() -> void:
	var new_face := CustomerOffers.post_chance(_run)
	assert_lt(new_face, CustomerOffers.POST_CHANCE)
	_run.street_cred = int(StreetCred.RANKS[2].cred)
	assert_gt(CustomerOffers.post_chance(_run), new_face, "respect grows with rank")
	Story.mark(_run, War.VEX_FELL)
	assert_almost_eq(CustomerOffers.post_chance(_run), CustomerOffers.POST_CHANCE, 0.001)


func test_customer_orders_fit_the_bag_now() -> void:
	assert_eq(CustomerOffers.max_slots(_run), Inventory.capacity(_run))


func test_bar_orders_are_fewer_and_fit_the_bag() -> void:
	for day in 5:
		_run.day = day + 1
		var board := Orders.board(_run, &"tran_bar")
		assert_lte(board.size(), Orders.ACT_ONE_POSTED_PER_DAY)
		for offer in board:
			assert_true(Orders.fits_in_bag(_run, offer), str(offer.id))


func test_families_give_no_favours_until_act_two() -> void:
	var family: FamilyDef = Content.families()[0]
	assert_true(Favours.board(_run, family).is_empty())
	Story.mark(_run, War.VEX_FELL)
	assert_false(Favours.board(_run, family).is_empty())


func test_only_vex_confronts_the_player_in_act_one() -> void:
	var gangs := Gangs.confronting(_run)
	assert_eq(gangs.size(), 1)
	assert_eq(gangs[0].id, War.VEX_GANG)
	Story.mark(_run, War.VEX_FELL)
	assert_eq(Gangs.confronting(_run).size(), Gangs.active(_run).size())
