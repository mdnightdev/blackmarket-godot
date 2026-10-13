extends GutTest

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	_run.price_seed = 9090
	_run.district_id = Corners.HOME
	_run.cash = 50000


func _clear_debt() -> void:
	_run.debt = 0
	_run.career = true


func test_old_market_is_split_into_four_corners_held_by_vex() -> void:
	assert_eq(Corners.of(Corners.HOME).size(), 4)
	assert_eq(Turf.share(_run, Corners.HOME), 0)
	assert_eq(Turf.holder(_run, Corners.HOME), Turf.Holder.GANG)
	assert_true(Corners.has_corners(&"slums"))
	assert_false(Corners.has_corners(&"golden_mile"))


func test_corner_sellers_work_their_corner_every_phase_whoever_holds_it() -> void:
	Corners.take(_run, Corners.MAMA_LIN)
	for step in RunState.Phase.size() * 2:
		var people: Dictionary = Corners.people_at(_run, Corners.HOME)
		for corner in Corners.of(Corners.HOME):
			if corner.seller.is_empty():
				continue
			var ids: Array = people[corner.id].map(func(person: SpeakerDef) -> StringName: return person.id)
			assert_true(ids.has(corner.seller), "%s at %s, step %d" % [corner.seller, corner.id, step])
		Calendar.advance_phase(_run)


func test_everyone_in_old_market_stands_at_one_corner() -> void:
	var people := Corners.people_at(_run, Corners.HOME)
	assert_eq(people.size(), 4)
	var placed := 0
	for corner in Corners.of(Corners.HOME):
		placed += people[corner.id].size()
	var stamp := Calendar.stamp(_run)
	var working := Roster.dealers_at(_run, Corners.HOME, stamp).size() + Roster.characters_at(_run, Corners.HOME, stamp).size()
	assert_eq(placed, working)
	assert_eq(Corners.people_at(_run, Corners.HOME), people, "The same phase places people the same way")
	assert_true(Corners.people_at(_run, &"golden_mile").is_empty())


func test_sellers_stand_at_their_own_corner() -> void:
	var people := Corners.people_at(_run, Corners.HOME)
	var stamp := Calendar.stamp(_run)
	for dealer in Roster.dealers_at(_run, Corners.HOME, stamp):
		for corner in Corners.of(Corners.HOME):
			if corner.seller == dealer.id:
				assert_true(people[corner.id].has(dealer), "%s works their own corner" % dealer.display_name)


func test_mama_lin_sells_only_after_the_debt() -> void:
	assert_false(Corners.is_for_sale(_run))
	assert_eq(Corners.buy_mama_lin(_run), Corners.Result.NOT_FOR_SALE)
	_clear_debt()
	assert_true(Corners.is_for_sale(_run))


func test_mama_lin_sells_on_the_vex_branch_once_rabbit_has_spoken() -> void:
	_run.lender = Loan.VEX_LENDER
	assert_false(Corners.is_for_sale(_run))
	_run.rabbit_offer = DebtSale.RabbitOffer.REFUSED
	assert_true(Corners.is_for_sale(_run))


func test_buying_the_corner_brings_rabbit_and_rook_in() -> void:
	_clear_debt()
	assert_eq(Corners.buy_mama_lin(_run), Corners.Result.OK)
	assert_eq(_run.cash, 50000 - Corners.MAMA_LIN_PRICE)
	assert_true(Corners.holds(_run, Corners.MAMA_LIN))
	assert_eq(Turf.share(_run, Corners.HOME), 25)
	assert_true(Armory.unlocked(_run))
	assert_true(Crew.is_free_role(_run, Corners.RABBIT_ROLE))
	assert_false(Corners.is_for_sale(_run))


func test_needs_the_full_price() -> void:
	_clear_debt()
	_run.cash = Corners.MAMA_LIN_PRICE - 1
	assert_eq(Corners.buy_mama_lin(_run), Corners.Result.NOT_ENOUGH_CASH)
	assert_false(Corners.holds(_run, Corners.MAMA_LIN))


func test_tran_tips_the_player_off_once() -> void:
	_clear_debt()
	assert_false(Corners.check(_run, false), "only in the morning")
	assert_true(Corners.check(_run, true))
	assert_eq(str(_run.pending_encounter.type), Corners.TIP)
	_run.pending_encounter = {}
	assert_false(Corners.check(_run, true))


func test_vex_smashes_the_stall_the_next_morning() -> void:
	_clear_debt()
	Story.mark(_run, Corners.TIP_SENT)
	Corners.buy_mama_lin(_run)
	_run.stash = { &"burner_sims": 8 }
	_run.crew.append({ "role": "runner", "hired_day": 1, "unpaid_days": 0, "free": false })
	assert_true(Corners.check(_run, true))
	var encounter := _run.pending_encounter
	assert_eq(str(encounter.type), Corners.STALL_SMASHED)
	assert_eq(int(_run.stash[&"burner_sims"]), 6)
	assert_false(Crew.has(_run, &"runner"), "the paid hand quits")
	assert_true(Crew.is_free_role(_run, Corners.RABBIT_ROLE), "Rabbit stays")
	assert_string_contains(Corners.resolve(_run, encounter, Encounters.CONTINUE), "2 units")
	_run.pending_encounter = {}
	assert_false(Corners.check(_run, true), "it happens once")


func test_held_corners_pay_every_morning() -> void:
	Corners.take(_run, Corners.MAMA_LIN)
	assert_eq(Turf.daily_cut(_run), Corners.find(Corners.MAMA_LIN).daily_cut())


func test_vex_stays_while_she_holds_corners_outside_old_market() -> void:
	Corners.take_all(_run, Corners.HOME)
	Turf.check_victory(_run)
	assert_false(_run.gangs_gone.has(&"vex"))


func test_corners_survive_a_save_and_drop_unknown_ids() -> void:
	Corners.take(_run, Corners.MAMA_LIN)
	var data := _run.to_dict()
	data.corners_held.append("nowhere")
	var loaded := RunState.from_dict(JSON.parse_string(JSON.stringify(data)))
	assert_eq(loaded.corners_held, ["mama_lin_corner"] as Array[String])
