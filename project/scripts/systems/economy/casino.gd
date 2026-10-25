class_name Casino

## Table rules for the casino games. Payouts are the total handed back, stake included, so 0 means the stake is lost.

enum SicBoBet { SMALL, BIG }

## Bet sizes offered, as multiples of the table minimum.
const BET_STEPS: Array[int] = [1, 2, 5, 10, 20]

const SIC_BO_SMALL_MAX := 10
const SIC_BO_BIG_MIN := 11

const BLACKJACK := 21
const DEALER_STANDS_ON := 17
## A natural blackjack pays 3 to 2.
const NATURAL_PAYOUT := 2.5

## Reel symbols are trade goods, from most to least common.
const SLOT_SYMBOLS: Array[StringName] = [&"burner_sims", &"burner_phones", &"fake_ids", &"rare_watches", &"vault_keys", &"zero_day_drive"]
const SLOT_WEIGHTS: Array[int] = [8, 6, 5, 3, 2, 1]
## Stake multiple paid for three of the symbol.
const SLOT_THREE_PAYS: Array[int] = [5, 10, 20, 50, 150, 500]
## Stake multiple paid for exactly two of the symbol.
const SLOT_PAIR_PAYS: Array[int] = [1, 0, 0, 0, 2, 3]


static func bet_levels(casino: CasinoDef) -> Array[int]:
	var levels: Array[int] = []
	for step in BET_STEPS:
		var amount := casino.min_bet * step
		if amount <= casino.max_bet:
			levels.append(amount)
	return levels


static func can_enter(run: RunState, casino: CasinoDef) -> bool:
	return run.cash >= casino.entry_cash


static func can_bet(run: RunState, casino: CasinoDef, amount: int) -> bool:
	return amount >= casino.min_bet and amount <= casino.max_bet and amount <= run.cash


## Takes the stake up front, so closing the game mid-hand cannot undo a loss.
static func place_bet(run: RunState, casino: CasinoDef, amount: int) -> bool:
	if not can_bet(run, casino, amount):
		return false
	run.cash -= amount
	return true


static func pay_out(run: RunState, amount: int) -> void:
	run.cash += maxi(0, amount)


static func roll_dice(rng: RandomNumberGenerator) -> Array[int]:
	var dice: Array[int] = []
	for i in 3:
		dice.append(rng.randi_range(1, 6))
	return dice


## Big and Small pay even money. Any triple loses both.
static func sic_bo_payout(dice: Array[int], bet: SicBoBet, stake: int) -> int:
	if dice[0] == dice[1] and dice[1] == dice[2]:
		return 0
	var total: int = dice[0] + dice[1] + dice[2]
	var won := total <= SIC_BO_SMALL_MAX if bet == SicBoBet.SMALL else total >= SIC_BO_BIG_MIN
	return stake * 2 if won else 0


## Cards are ranks 1 to 13, ace to king, drawn from an endless shoe.
static func draw_card(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(1, 13)


static func hand_value(cards: Array[int]) -> int:
	var total := 0
	var aces := 0
	for rank in cards:
		total += mini(rank, 10)
		if rank == 1:
			aces += 1
	if aces > 0 and total + 10 <= BLACKJACK:
		total += 10
	return total


static func is_natural(cards: Array[int]) -> bool:
	return cards.size() == 2 and hand_value(cards) == BLACKJACK


static func dealer_should_hit(cards: Array[int]) -> bool:
	return hand_value(cards) < DEALER_STANDS_ON


static func blackjack_payout(player: Array[int], dealer: Array[int], stake: int, natural_payout := NATURAL_PAYOUT) -> int:
	var player_total := hand_value(player)
	var dealer_total := hand_value(dealer)
	if player_total > BLACKJACK:
		return 0
	if is_natural(player) and not is_natural(dealer):
		return roundi(stake * natural_payout)
	if is_natural(dealer) and not is_natural(player):
		return 0
	if dealer_total > BLACKJACK or player_total > dealer_total:
		return stake * 2
	if player_total == dealer_total:
		return stake
	return 0


static func spin_reel(rng: RandomNumberGenerator) -> int:
	var total := 0
	for weight in SLOT_WEIGHTS:
		total += weight
	var pick := rng.randi_range(0, total - 1)
	for index in SLOT_WEIGHTS.size():
		pick -= SLOT_WEIGHTS[index]
		if pick < 0:
			return index
	return 0


static func slot_payout(reels: Array[int], stake: int) -> int:
	if reels[0] == reels[1] and reels[1] == reels[2]:
		return stake * SLOT_THREE_PAYS[reels[0]]
	var pair := -1
	if reels[0] == reels[1] or reels[0] == reels[2]:
		pair = reels[0]
	elif reels[1] == reels[2]:
		pair = reels[1]
	return stake * SLOT_PAIR_PAYS[pair] if pair >= 0 else 0


## Long-run share of stakes the slots pay back, worked out exactly over every reel combination.
static func slot_return_rate() -> float:
	var total_weight := 0
	for weight in SLOT_WEIGHTS:
		total_weight += weight
	var expected := 0.0
	var symbols := SLOT_WEIGHTS.size()
	for a in symbols:
		for b in symbols:
			for c in symbols:
				var chance := float(SLOT_WEIGHTS[a] * SLOT_WEIGHTS[b] * SLOT_WEIGHTS[c]) / pow(total_weight, 3)
				var reels: Array[int] = [a, b, c]
				expected += chance * slot_payout(reels, 1)
	return expected
