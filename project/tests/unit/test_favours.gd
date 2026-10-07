extends GutTest

var _run: RunState
var _family: FamilyDef


func before_each() -> void:
	_run = RunState.new()
	_run.price_seed = 777
	_run.cash = 20000
	_family = Content.family(&"red_lotus")


## Advances whole days until the family posts an offer of that kind.
func _find_offer(kind: Favours.Kind) -> Dictionary:
	for attempt in 30:
		for offer in Favours.board(_run, _family):
			if int(offer.kind) == kind:
				return offer
		_run.day += 1
	fail_test("No %s offer showed up" % Favours.Kind.keys()[kind])
	return {}


func test_board_is_stable_for_a_day() -> void:
	var board := Favours.board(_run, _family)
	assert_eq(board.size(), Favours.POSTED_PER_DAY)
	assert_eq(Favours.board(_run, _family), board)
	for offer in board:
		assert_eq(offer.family, "red_lotus")
		assert_true(String(offer.id).begins_with("red_lotus:0:"))


func test_accepting_a_delivery_stores_it_once() -> void:
	var offer := _find_offer(Favours.Kind.DELIVERY)
	assert_eq(Favours.accept(_run, offer), Favours.Result.OK)
	assert_eq(Favours.active_for(_run, _family.id).id, offer.id)
	assert_false(Favours.board(_run, _family).any(func(entry: Dictionary) -> bool: return entry.id == offer.id))
	assert_eq(Favours.accept(_run, offer), Favours.Result.TAKEN)


func test_one_delivery_per_family_at_a_time() -> void:
	var offer := _find_offer(Favours.Kind.DELIVERY)
	Favours.accept(_run, offer)
	var second := offer.duplicate()
	second.id = "red_lotus:%d:9" % (_run.day - 1)
	assert_eq(Favours.accept(_run, second), Favours.Result.BUSY)


func test_tribute_is_paid_on_the_spot() -> void:
	var offer := _find_offer(Favours.Kind.TRIBUTE)
	assert_eq(Favours.accept(_run, offer), Favours.Result.OK)
	assert_eq(_run.cash, 20000 - int(offer.price))
	assert_true(_run.favours.is_empty())
	assert_eq(Families.standing(_run, _family.id), Favours.DONE_GAIN)
	assert_eq(Families.standing(_run, _family.rival), -Favours.RIVAL_LOSS)


func test_tribute_needs_the_cash() -> void:
	var offer := _find_offer(Favours.Kind.TRIBUTE)
	_run.cash = 0
	assert_eq(Favours.accept(_run, offer), Favours.Result.NOT_ENOUGH_CASH)
	assert_eq(Families.standing(_run, _family.id), 0)


func test_delivering_pays_and_raises_standing() -> void:
	var offer := _find_offer(Favours.Kind.DELIVERY)
	Favours.accept(_run, offer)
	var favour := Favours.active_for(_run, _family.id)
	assert_false(Favours.deliver(_run, favour), "nothing in the bag yet")
	Inventory.add_units(_run, StringName(favour.item), int(favour.quantity))
	var cash_before := _run.cash
	assert_true(Favours.deliver(_run, favour))
	assert_eq(_run.cash, cash_before + Favours.total(favour))
	assert_true(_run.favours.is_empty())
	assert_eq(Families.standing(_run, _family.id), Favours.DONE_GAIN)
	assert_eq(Families.standing(_run, _family.rival), -Favours.RIVAL_LOSS)


func test_missed_deliveries_cost_standing() -> void:
	var offer := _find_offer(Favours.Kind.DELIVERY)
	Favours.accept(_run, offer)
	while Calendar.stamp(_run) <= int(offer.due):
		Calendar.advance_phase(_run)
	var missed := Favours.expire(_run)
	assert_eq(missed.size(), 1)
	assert_true(_run.favours.is_empty())
	assert_eq(Families.standing(_run, _family.id), -Favours.MISSED_LOSS)


func test_expire_forgets_yesterdays_taken_offers() -> void:
	_run.taken_favours = ["red_lotus:0:0", "red_lotus:1:1"]
	_run.day = 2
	Favours.expire(_run)
	assert_eq(_run.taken_favours, ["red_lotus:1:1"] as Array[String])


func test_favours_survive_a_save_and_drop_broken_entries() -> void:
	var offer := _find_offer(Favours.Kind.DELIVERY)
	Favours.accept(_run, offer)
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(_run.to_dict())))
	assert_eq(restored.favours, _run.favours)
	assert_eq(restored.taken_favours, _run.taken_favours)
	restored = RunState.from_dict({"favours": [
		{"id": "x", "family": "nobody", "item": "burner_phones", "quantity": 2, "price": 10, "due": 5},
		{"id": "y", "family": "red_lotus", "item": "nothing", "quantity": 2, "price": 10, "due": 5},
	]})
	assert_true(restored.favours.is_empty())
