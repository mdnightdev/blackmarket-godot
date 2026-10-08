extends GutTest

const DEBTOR_DISTRICT := "slums"
const PICKUP := "slums"
const DROP := "docks"
const PAY := 10000

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	_run.price_seed = 2468


func _go_to_stamp(stamp: int) -> void:
	_run.day = floori(float(stamp) / RunState.Phase.size()) + 1
	_run.phase = (stamp % RunState.Phase.size()) as RunState.Phase


func _take(kind: String, extra: Dictionary = {}) -> Dictionary:
	var source := { "id": "errand:test:%d" % _run.errands.size(), "kind": kind, "pay": PAY, "lead": Errands.MIN_LEAD_PHASES }
	if kind == Errands.COLLECTION:
		source.merge({ "district": DEBTOR_DISTRICT, "debtor": "Sal Kwan", "owed": roundi(PAY / Errands.COLLECTION_CUT) })
	else:
		source.merge({ "pickup_district": PICKUP, "drop_district": DROP })
	source.merge(extra, true)
	var errand := Errands.sanitize(source)
	errand.due_stamp = Calendar.stamp(_run) + Errands.MIN_LEAD_PHASES
	_run.errands.append(errand)
	return errand


func _meet_debtor() -> void:
	_take(Errands.COLLECTION)
	_run.district_id = StringName(DEBTOR_DISTRICT)
	Errands.visit(_run)


func test_offers_stay_inside_the_pay_range_and_open_districts() -> void:
	for run_seed in 40:
		_run.price_seed = run_seed
		var offer := Errands.generate(_run)
		var band: Array = PayScale.BANDS[Tiers.STREET]
		assert_between(int(offer.pay), int(band[0]), int(band[2]))
		assert_eq(int(offer.pay) % Errands.PAY_ROUNDING, 0)
		assert_between(int(offer.lead), Errands.MIN_LEAD_PHASES, Errands.MAX_LEAD_PHASES)
		assert_eq(str(offer.sender), String(Loan.LENDER))
		assert_false(Errands.sanitize(offer).is_empty(), "generated offers are valid")
		var first := Errands.target_district(offer)
		assert_ne(first, _run.district_id)
		assert_false(Travel.is_locked(_run, Content.district(first)))
		assert_eq(Content.district(first).tier, Tiers.STREET, "the Shark works the street")
	assert_eq(Errands.generate(_run), Errands.generate(_run), "same seed and phase give the same offer")


func test_pay_grows_with_rank() -> void:
	var low := 0
	var high := 0
	for run_seed in 20:
		_run.price_seed = run_seed
		_run.street_cred = 0
		low += int(Errands.generate(_run).pay)
		_run.street_cred = StreetCred.MAX
		high += int(Errands.generate(_run).pay)
	assert_gt(high, low)


func test_the_shark_posts_on_posting_phases_up_to_the_cap() -> void:
	var posted := Errands.post(_run)
	assert_eq(posted.size(), 1)
	assert_eq(_run.errand_offers.size(), 1)
	assert_true(Errands.post(_run).is_empty(), "one offer per phase")
	_go_to_stamp(RunState.Phase.NOON)
	assert_true(Errands.post(_run).is_empty(), "noon is not a posting phase")
	_go_to_stamp(RunState.Phase.EVENING)
	assert_true(Errands.post(_run).is_empty(), "the Shark posts once a day")
	_go_to_stamp(RunState.Phase.size())
	while _run.errand_offers.size() < Errands.MAX_OPEN_OFFERS:
		var filler := Errands.generate(_run)
		filler.id = "errand:filler:%d" % _run.errand_offers.size()
		_run.errand_offers.append(filler)
	assert_true(Errands.post(_run).is_empty(), "the phone is full")


func test_ignored_offers_expire() -> void:
	Errands.post(_run)
	var offer: Dictionary = _run.errand_offers[0]
	_go_to_stamp(int(offer.expires_stamp))
	Errands.expire(_run)
	assert_eq(_run.errand_offers.size(), 1, "still open in its last phase")
	_go_to_stamp(int(offer.expires_stamp) + 1)
	assert_true(Errands.expire(_run).is_empty(), "no notice for an ignored offer")
	assert_true(_run.errand_offers.is_empty())
	assert_false(Errands.accept(_run, str(offer.id)))


func test_phases_left_counts_down_to_expiry() -> void:
	Errands.post(_run)
	var offer: Dictionary = _run.errand_offers[0]
	assert_eq(Errands.phases_left(_run, offer), Errands.OFFER_PHASES)
	_go_to_stamp(int(offer.expires_stamp))
	assert_eq(Errands.phases_left(_run, offer), 1, "last phase still counts")
	_go_to_stamp(int(offer.expires_stamp) + 1)
	assert_eq(Errands.phases_left(_run, offer), 0)


func test_next_stop_follows_the_errand_and_is_empty_when_there() -> void:
	var collection := _take(Errands.COLLECTION)
	assert_eq(Errands.next_stop(_run, collection).id, StringName(DEBTOR_DISTRICT))
	_run.district_id = StringName(DEBTOR_DISTRICT)
	assert_null(Errands.next_stop(_run, collection))
	var delivery := _take(Errands.DELIVERY)
	assert_null(Errands.next_stop(_run, delivery), "standing at the pickup")
	delivery.picked_up = true
	assert_eq(Errands.next_stop(_run, delivery).id, StringName(DROP))


func test_accept_starts_the_clock_and_decline_removes_the_offer() -> void:
	Errands.post(_run)
	var offer: Dictionary = _run.errand_offers[0]
	assert_true(Errands.accept(_run, str(offer.id)))
	assert_true(_run.errand_offers.is_empty())
	assert_eq(int(_run.errands[0].due_stamp), Calendar.stamp(_run) + int(offer.lead))
	assert_false(Errands.accept(_run, str(offer.id)), "cannot take it twice")
	_go_to_stamp(RunState.Phase.size())
	Errands.post(_run)
	var second: Dictionary = _run.errand_offers[0]
	assert_true(Errands.decline(_run, str(second.id)))
	assert_true(_run.errand_offers.is_empty())
	assert_eq(_run.errands.size(), 1)


func test_hands_full_refuses_more_errands() -> void:
	for index in Errands.MAX_ACTIVE:
		_take(Errands.DELIVERY)
	Errands.post(_run)
	assert_false(Errands.can_accept(_run))
	assert_false(Errands.accept(_run, str(_run.errand_offers[0].id)))
	assert_eq(_run.errand_offers.size(), 1)


func test_package_is_picked_up_then_dropped_for_pay() -> void:
	_run.career = true
	var errand := _take(Errands.DELIVERY)
	assert_eq(Errands.target_district(errand), StringName(PICKUP))
	assert_string_contains(Errands.describe(errand), "Pick up a package in")
	_run.district_id = StringName(DROP)
	assert_true(Errands.visit(_run).is_empty(), "nothing to drop before the pickup")
	_run.district_id = StringName(PICKUP)
	assert_eq(Errands.visit(_run).size(), 1)
	assert_true(bool(errand.picked_up))
	assert_eq(Errands.target_district(errand), StringName(DROP))
	var cash := _run.cash
	var cred := _run.street_cred
	_run.district_id = StringName(DROP)
	assert_eq(Errands.visit(_run).size(), 1)
	assert_true(_run.errands.is_empty())
	assert_eq(_run.cash, cash + PAY)
	assert_eq(_run.street_cred, cred + StreetCred.ERRAND_DONE)


func test_act_one_pay_is_split_between_the_debt_and_cash() -> void:
	var cash := _run.cash
	var debt := _run.debt
	var paid := Errands.pay_out(_run, PAY)
	var to_debt := roundi(PAY * Errands.DEBT_SHARE)
	assert_eq(int(paid.debt), to_debt)
	assert_eq(int(paid.cash), PAY - to_debt)
	assert_eq(_run.debt, debt - to_debt)
	assert_eq(_run.cash, cash + PAY - to_debt)
	assert_eq(_run.paid_this_period, to_debt, "counts toward the weekly payment")
	assert_string_contains(Errands.describe_payout(paid), "off your debt")


func test_clearing_the_debt_with_an_errand_starts_the_career() -> void:
	_run.debt = 1000
	var paid := Errands.pay_out(_run, PAY)
	assert_eq(int(paid.debt), 1000)
	assert_eq(_run.debt, 0)
	assert_true(_run.career)


func test_career_pay_is_all_cash() -> void:
	_run.career = true
	var cash := _run.cash
	var debt := _run.debt
	var paid := Errands.pay_out(_run, PAY)
	assert_eq(int(paid.debt), 0)
	assert_eq(_run.cash, cash + PAY)
	assert_eq(_run.debt, debt)


func test_arriving_at_the_debtor_queues_the_collection() -> void:
	_meet_debtor()
	assert_eq(str(_run.pending_encounter.get("type")), Collections.TYPE)
	var ids := Encounters.choices(_run, _run.pending_encounter).map(func(choice: Encounters.Choice) -> StringName: return choice.id)
	assert_eq(ids, [Collections.TALK, Collections.LEAN, Collections.SLIDE])


func test_a_waiting_encounter_holds_the_debtor_back() -> void:
	_take(Errands.COLLECTION)
	_run.district_id = StringName(DEBTOR_DISTRICT)
	_run.pending_encounter = Encounters.police_stop(_run)
	Errands.visit(_run)
	assert_eq(str(_run.pending_encounter.type), Encounters.POLICE)


func test_talking_well_collects_everything() -> void:
	_run.career = true
	_meet_debtor()
	var cash := _run.cash
	assert_ne(Encounters.resolve(_run, Collections.TALK, 0.0), "")
	assert_eq(_run.cash, cash + PAY)
	assert_true(_run.errands.is_empty())
	assert_false(Encounters.has_pending(_run))


func test_talking_badly_collects_part() -> void:
	_run.career = true
	_meet_debtor()
	var cash := _run.cash
	Encounters.resolve(_run, Collections.TALK, 0.999)
	assert_eq(_run.cash, cash + roundi(PAY * Collections.FAIL_SHARE))
	assert_true(_run.errands.is_empty())


func test_leaning_adds_heat_and_beats_talking() -> void:
	_run.career = true
	assert_gt(Collections.lean_chance(_run), Collections.talk_chance(_run))
	_meet_debtor()
	var cash := _run.cash
	Encounters.resolve(_run, Collections.LEAN, 0.0)
	assert_eq(_run.heat, Collections.LEAN_HEAT)
	assert_eq(_run.cash, cash + PAY)


func test_letting_some_slide_is_guaranteed() -> void:
	_run.career = true
	_meet_debtor()
	var cash := _run.cash
	Encounters.resolve(_run, Collections.SLIDE, 0.999)
	assert_eq(_run.cash, cash + roundi(PAY * Collections.SLIDE_SHARE))
	assert_eq(_run.heat, 0)


func test_an_overdue_errand_fails() -> void:
	_run.street_cred = 100
	var errand := _take(Errands.DELIVERY)
	_go_to_stamp(int(errand.due_stamp))
	assert_true(Errands.expire(_run).is_empty(), "still due in its last phase")
	_go_to_stamp(int(errand.due_stamp) + 1)
	var notices := Errands.expire(_run)
	assert_eq(notices.size(), 1)
	assert_true(_run.errands.is_empty())
	assert_eq(_run.street_cred, 100 + StreetCred.JOB_MISSED)


func test_errands_show_up_in_job_deadlines() -> void:
	var errand := _take(Errands.COLLECTION)
	var jobs := Jobs.deadlines(_run)
	assert_eq(jobs.size(), 1)
	assert_eq(int(jobs[0].due), int(errand.due_stamp))
	assert_eq(str(jobs[0].place), Content.district(StringName(DEBTOR_DISTRICT)).display_name)


func test_sanitize_rejects_junk() -> void:
	assert_true(Errands.sanitize({}).is_empty())
	assert_true(Errands.sanitize({ "id": "x", "kind": "heist", "pay": PAY }).is_empty())
	assert_true(Errands.sanitize({ "id": "x", "kind": Errands.COLLECTION, "pay": PAY, "district": "nowhere", "debtor": "A", "owed": 5 }).is_empty())
	assert_true(Errands.sanitize({ "id": "x", "kind": Errands.COLLECTION, "pay": 0, "district": DEBTOR_DISTRICT, "debtor": "A", "owed": 5 }).is_empty())
	assert_true(Errands.sanitize({ "id": "x", "kind": Errands.DELIVERY, "pay": PAY, "pickup_district": PICKUP, "drop_district": PICKUP }).is_empty())


func test_saved_errands_survive_a_reload_and_junk_is_dropped() -> void:
	var errand := _take(Errands.DELIVERY, { "picked_up": true })
	Errands.post(_run)
	var data := _run.to_dict()
	data.errands.append({ "id": "junk" })
	var loaded := RunState.from_dict(JSON.parse_string(JSON.stringify(data)))
	assert_eq(loaded.errands.size(), 1)
	assert_eq(str(loaded.errands[0].id), str(errand.id))
	assert_true(bool(loaded.errands[0].picked_up))
	assert_eq(int(loaded.errands[0].due_stamp), int(errand.due_stamp))
	assert_eq(loaded.errand_offers.size(), 1)
