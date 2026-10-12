extends GutTest

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	Story.mark(_run, War.VEX_FELL)
	_run.price_seed = 1357
	_run.district_id = Smuggling.ORIGIN


func _first_offer() -> Dictionary:
	return Smuggling.board(_run)[0]


func test_board_posts_crates_to_other_districts_within_limits() -> void:
	var offers := Smuggling.board(_run)
	assert_eq(offers.size(), Smuggling.POSTED_PER_DAY)
	for offer in offers:
		assert_ne(offer.destination, String(Smuggling.ORIGIN))
		assert_not_null(Smuggling.destination(offer))
		assert_between(int(offer.slots), Smuggling.MIN_SLOTS, Smuggling.MAX_SLOTS)
		assert_between(int(offer.lead), Smuggling.MIN_LEAD_PHASES, Smuggling.MAX_LEAD_PHASES)
		var band: Array = PayScale.BANDS[Smuggling.destination(offer).tier]
		var floor_pay := roundi(band[0] * Smuggling.RISK_PREMIUM) - Smuggling.PAY_ROUNDING
		var ceiling_pay := ceili(band[2] * Smuggling.RISK_PREMIUM * (1.0 + Smuggling.DISTANCE_BONUS * sqrt(2.0)))
		assert_between(int(offer.pay), floor_pay, ceiling_pay)
		assert_eq(int(offer.pay) % Smuggling.PAY_ROUNDING, 0)
	assert_eq(Smuggling.board(_run), offers, "same seed and day give the same board")


func test_accepting_fills_bag_and_starts_the_clock() -> void:
	var offer := _first_offer()
	assert_eq(Smuggling.accept(_run, offer), Smuggling.Result.OK)
	assert_true(Smuggling.is_carrying(_run))
	assert_eq(Inventory.used(_run), int(offer.slots))
	assert_eq(int(_run.crate.due), Calendar.stamp(_run) + int(offer.lead))
	assert_false(Smuggling.board(_run).any(func(entry: Dictionary) -> bool: return entry.id == offer.id))
	assert_eq(Smuggling.accept(_run, Smuggling.board(_run)[0]), Smuggling.Result.CARRYING)


func test_needs_room_in_the_bag() -> void:
	var offer := _first_offer()
	Inventory.add_units(_run, &"burner_sims", Inventory.capacity(_run) - int(offer.slots) + 1)
	assert_eq(Smuggling.accept(_run, offer), Smuggling.Result.NO_ROOM)
	assert_false(Smuggling.is_carrying(_run))


func test_crate_raises_police_attention_and_bribes() -> void:
	var offer := _first_offer()
	Smuggling.accept(_run, offer)
	assert_eq(Heat.carried_risk(_run), int(offer.slots) * Smuggling.RISK_PER_SLOT)
	assert_gt(Police.stop_chance(_run), 0.0)
	assert_eq(Police.carried_value(_run), int(offer.pay))


func test_delivers_only_at_the_destination_before_the_deadline() -> void:
	var offer := _first_offer()
	Smuggling.accept(_run, offer)
	assert_eq(Smuggling.deliver(_run), 0, "still at the docks")
	_run.district_id = StringName(offer.destination)
	var cash_before := _run.cash
	assert_eq(Smuggling.deliver(_run), int(offer.pay))
	assert_eq(_run.cash, cash_before + int(offer.pay))
	assert_false(Smuggling.is_carrying(_run))
	assert_eq(Inventory.used(_run), 0)


func test_late_crate_is_lost_and_voronin_stops_giving_work() -> void:
	var offer := _first_offer()
	Smuggling.accept(_run, offer)
	for i in int(offer.lead):
		Calendar.advance_phase(_run)
	assert_true(Smuggling.expire(_run).is_empty(), "the last phase still counts")
	Calendar.advance_phase(_run)
	var lost := Smuggling.expire(_run)
	assert_eq(lost.id, offer.id)
	assert_false(Smuggling.is_carrying(_run))
	assert_true(Smuggling.is_banned(_run))
	assert_true(Smuggling.board(_run).is_empty())
	assert_eq(Smuggling.accept(_run, offer), Smuggling.Result.BANNED)


func test_a_delivery_streak_raises_pay_and_a_seizure_resets_it() -> void:
	var offer := _first_offer()
	Smuggling.accept(_run, offer)
	_run.crate_streak = 3
	_run.district_id = StringName(offer.destination)
	assert_eq(Smuggling.deliver(_run), roundi(int(offer.pay) * (1.0 + 3 * Smuggling.STREAK_BONUS)))
	assert_eq(_run.crate_streak, 4)
	_run.district_id = Smuggling.ORIGIN
	Smuggling.accept(_run, Smuggling.board(_run)[0])
	Smuggling.seize(_run)
	assert_eq(_run.crate_streak, 0)


func test_streak_bonus_is_capped() -> void:
	_run.crate_streak = Smuggling.MAX_STREAK_BONUS * 3
	assert_almost_eq(Smuggling.streak_bonus(_run), Smuggling.MAX_STREAK_BONUS * Smuggling.STREAK_BONUS, 0.0001)


func test_police_take_the_crate_first_when_you_comply() -> void:
	Smuggling.accept(_run, _first_offer())
	Inventory.add_units(_run, &"zero_day_drive", 1)
	var taken := Police.comply(_run)
	assert_true(taken.has("crate"))
	assert_false(Smuggling.is_carrying(_run))
	assert_eq(Inventory.count(_run, &"zero_day_drive"), 1, "the rest of the bag is left alone")
	assert_true(Smuggling.is_banned(_run))


func test_a_raid_takes_the_crate_too() -> void:
	Smuggling.accept(_run, _first_offer())
	Police.arrest(_run)
	assert_false(Smuggling.is_carrying(_run))


func test_crate_survives_a_save() -> void:
	var offer := _first_offer()
	Smuggling.accept(_run, offer)
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(_run.to_dict())))
	assert_eq(restored.crate.id, offer.id)
	assert_eq(int(restored.crate.due), int(_run.crate.due))
	assert_eq(restored.taken_crates, _run.taken_crates)
	assert_eq(Inventory.used(restored), int(offer.slots))


func test_taken_ids_reset_the_next_day() -> void:
	var offer := _first_offer()
	Smuggling.accept(_run, offer)
	_run.district_id = StringName(offer.destination)
	Smuggling.deliver(_run)
	for i in RunState.Phase.size():
		Calendar.advance_phase(_run)
	Smuggling.expire(_run)
	assert_true(_run.taken_crates.is_empty())
	assert_eq(Smuggling.board(_run).size(), Smuggling.POSTED_PER_DAY)
