extends GutTest

var _run: RunState
var _casino: CasinoDef
var _vip: CasinoDef


func before_each() -> void:
	_run = RunState.new()
	_casino = Content.venue(&"casino") as CasinoDef
	_vip = Content.venue(&"vip_casino") as CasinoDef


func _cards(ranks: Array) -> Array[int]:
	var cards: Array[int] = []
	cards.assign(ranks)
	return cards


func test_both_casinos_load_with_their_stakes() -> void:
	assert_not_null(_casino)
	assert_not_null(_vip)
	assert_eq([_casino.min_bet, _casino.max_bet, _casino.entry_cash], [50, 1000, 0])
	assert_eq([_vip.min_bet, _vip.max_bet, _vip.entry_cash], [1000, 20000, 20000])
	assert_eq(Content.character(_casino.host).role, CharacterDef.Role.CASINO_HOST)
	assert_eq(Content.character(_vip.host).role, CharacterDef.Role.CASINO_HOST)


func test_bet_levels_stay_inside_table_limits() -> void:
	assert_eq(Casino.bet_levels(_casino), [50, 100, 250, 500, 1000] as Array[int])
	assert_eq(Casino.bet_levels(_vip), [1000, 2000, 5000, 10000, 20000] as Array[int])


func test_vip_door_needs_cash_on_hand() -> void:
	_run.cash = 19_999
	assert_false(Casino.can_enter(_run, _vip))
	assert_true(Casino.can_enter(_run, _casino))
	_run.cash = 20_000
	assert_true(Casino.can_enter(_run, _vip))


func test_bet_is_taken_up_front_and_checked() -> void:
	_run.cash = 300
	assert_false(Casino.place_bet(_run, _casino, 500), "more than the player carries")
	assert_false(Casino.place_bet(_run, _casino, 20), "under the table minimum")
	assert_true(Casino.place_bet(_run, _casino, 250))
	assert_eq(_run.cash, 50)
	Casino.pay_out(_run, 500)
	assert_eq(_run.cash, 550)


func test_sic_bo_pays_even_money_and_triples_lose() -> void:
	assert_eq(Casino.sic_bo_payout(_cards([1, 2, 3]), Casino.SicBoBet.SMALL, 100), 200)
	assert_eq(Casino.sic_bo_payout(_cards([1, 2, 3]), Casino.SicBoBet.BIG, 100), 0)
	assert_eq(Casino.sic_bo_payout(_cards([6, 5, 1]), Casino.SicBoBet.BIG, 100), 200)
	assert_eq(Casino.sic_bo_payout(_cards([4, 4, 2]), Casino.SicBoBet.SMALL, 100), 200, "10 is small")
	assert_eq(Casino.sic_bo_payout(_cards([4, 4, 3]), Casino.SicBoBet.BIG, 100), 200, "11 is big")
	assert_eq(Casino.sic_bo_payout(_cards([2, 2, 2]), Casino.SicBoBet.SMALL, 100), 0)
	assert_eq(Casino.sic_bo_payout(_cards([5, 5, 5]), Casino.SicBoBet.BIG, 100), 0)


func test_hand_value_counts_aces_soft_and_hard() -> void:
	assert_eq(Casino.hand_value(_cards([1, 13])), 21)
	assert_eq(Casino.hand_value(_cards([1, 1, 9])), 21)
	assert_eq(Casino.hand_value(_cards([1, 6, 10])), 17)
	assert_eq(Casino.hand_value(_cards([12, 11, 5])), 25)
	assert_true(Casino.is_natural(_cards([1, 11])))
	assert_false(Casino.is_natural(_cards([7, 7, 7])))


func test_dealer_stands_on_seventeen() -> void:
	assert_true(Casino.dealer_should_hit(_cards([10, 6])))
	assert_false(Casino.dealer_should_hit(_cards([10, 7])))
	assert_false(Casino.dealer_should_hit(_cards([1, 6])), "stands on soft 17")


func test_blackjack_payouts() -> void:
	assert_eq(Casino.blackjack_payout(_cards([1, 13]), _cards([10, 9]), 100), 250, "natural pays 3 to 2")
	assert_eq(Casino.blackjack_payout(_cards([1, 13]), _cards([1, 12]), 100), 100, "two naturals push")
	assert_eq(Casino.blackjack_payout(_cards([10, 9, 2]), _cards([1, 10]), 100), 0, "dealer natural beats 21")
	assert_eq(Casino.blackjack_payout(_cards([10, 9]), _cards([10, 6, 8]), 100), 200, "dealer bust")
	assert_eq(Casino.blackjack_payout(_cards([10, 8, 5]), _cards([10, 6, 8]), 100), 0, "player bust loses first")
	assert_eq(Casino.blackjack_payout(_cards([10, 8]), _cards([9, 9]), 100), 100)
	assert_eq(Casino.blackjack_payout(_cards([10, 7]), _cards([10, 8]), 100), 0)


func test_slot_payouts() -> void:
	assert_eq(Casino.slot_payout(_cards([5, 5, 5]), 10), 5000, "three drives")
	assert_eq(Casino.slot_payout(_cards([0, 0, 0]), 10), 50, "three sims")
	assert_eq(Casino.slot_payout(_cards([0, 3, 0]), 10), 10, "pair of sims returns the stake")
	assert_eq(Casino.slot_payout(_cards([2, 4, 4]), 10), 20, "pair of keys")
	assert_eq(Casino.slot_payout(_cards([1, 1, 2]), 10), 0, "pair of phones pays nothing")
	assert_eq(Casino.slot_payout(_cards([0, 1, 2]), 10), 0)


func test_slot_symbols_are_real_items_and_house_keeps_an_edge() -> void:
	for item_id in Casino.SLOT_SYMBOLS:
		assert_not_null(Content.item(item_id), String(item_id))
	var return_rate := Casino.slot_return_rate()
	assert_between(return_rate, 0.85, 0.97)


func test_random_rolls_stay_in_range() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in 50:
		for face in Casino.roll_dice(rng):
			assert_between(face, 1, 6)
		assert_between(Casino.draw_card(rng), 1, 13)
		assert_between(Casino.spin_reel(rng), 0, Casino.SLOT_SYMBOLS.size() - 1)
