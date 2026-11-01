class_name StreetCred

const MAX := 3000
const SALE_VALUE_PER_POINT := 500
const MAX_SALE_GAIN := 3
const DAILY_TRADING_CAP := 30

const ORDER_DELIVERED := 8
const FAVOUR_DONE := 10
const CRATE_DELIVERED := 12
const ERRAND_DONE := 12
const HIJACK_SUCCESS := 10
const FIGHT_WON := 6
const TASK_DONE := 15
const GANG_BEATEN := 100

const BUSTED := -25
const JOB_MISSED := -10
const CRATE_LOST := -15
const BACKED_OFF := -5
const CREW_WALKED := -10
const CUSTOMER_MISSED := -5

const RANKS: Array[Dictionary] = [
	{ "name": "Nobody", "cred": 0 },
	{ "name": "Corner Kid", "cred": 50 },
	{ "name": "Runner", "cred": 150 },
	{ "name": "Hustler", "cred": 300 },
	{ "name": "Earner", "cred": 500 },
	{ "name": "Connected", "cred": 800 },
	{ "name": "Shot Caller", "cred": 1200 },
	{ "name": "Underboss", "cred": 1700 },
	{ "name": "Boss", "cred": 2300 },
	{ "name": "Kingpin", "cred": 3000 },
]


## Ranks run from 1 to RANKS.size().
static func rank(run: RunState) -> int:
	return rank_for(run.street_cred)


static func rank_for(cred: int) -> int:
	var reached := 1
	for index in RANKS.size():
		if cred >= int(RANKS[index].cred):
			reached = index + 1
	return reached


static func rank_name(rank_number: int) -> String:
	return str(RANKS[clampi(rank_number, 1, RANKS.size()) - 1].name)


static func max_rank() -> int:
	return RANKS.size()


## Cred needed for the rank after this one, -1 at the top rank.
static func next_rank_cred(rank_number: int) -> int:
	if rank_number >= RANKS.size():
		return -1
	return int(RANKS[rank_number].cred)


static func add(run: RunState, amount: int) -> Dictionary:
	var old_rank := rank(run)
	run.street_cred = clampi(run.street_cred + amount, 0, MAX)
	var new_rank := rank(run)
	if new_rank > old_rank:
		return _grant_rank_pack(run, new_rank)
	return {}


static func _grant_rank_pack(run: RunState, new_rank: int) -> Dictionary:
	match new_rank:
		2: # Corner Kid: $5k cash, 2x burner_sims, 1x fake_ids
			run.cash += 5000
			Inventory.add_units(run, &"burner_sims", 2)
			Inventory.add_units(run, &"fake_ids", 1)
			return { "rank": new_rank, "title": "Corner Kid", "reward": "$5,000, 2x Burner SIMs, 1x Fake ID" }
		3: # Runner: $10k cash, 10x Lunatics
			run.cash += 10000
			Army.add(run, Army.Tier.LUNATICS, Army.State.ACTIVE, 10)
			return { "rank": new_rank, "title": "Runner", "reward": "$10,000, 10x Lunatics recruits" }
		4: # Hustler: $25k cash, 25x Lunatics, 5x ammo_9mm
			run.cash += 25000
			Army.add(run, Army.Tier.LUNATICS, Army.State.ACTIVE, 25)
			Inventory.add_units(run, &"ammo_9mm", 5)
			return { "rank": new_rank, "title": "Hustler", "reward": "$25,000, 25x recruits, 5x 9mm Ammo" }
		5: # Earner: $50k clean, 50x Guards, burner_phones
			run.clean_bank_cash += 50000
			Army.add(run, Army.Tier.GUARDS, Army.State.ACTIVE, 50)
			Inventory.add_units(run, &"burner_phones", 1)
			return { "rank": new_rank, "title": "Earner", "reward": "$50,000 clean, 50x Guards, Burner Phone" }
		6: # Connected: $100k dirty, zero_day_drive, 2x clone_plates
			run.cash += 100000
			Inventory.add_units(run, &"zero_day_drive", 1)
			Inventory.add_units(run, &"clone_plates", 2)
			return { "rank": new_rank, "title": "Connected", "reward": "$100,000, Zero-Day Drive, 2x Clone Plates" }
		7: # Shot Caller: $150k clean, 100x Guards, 5x combat_stims
			run.clean_bank_cash += 150000
			Army.add(run, Army.Tier.GUARDS, Army.State.ACTIVE, 100)
			Inventory.add_units(run, &"combat_stims", 5)
			return { "rank": new_rank, "title": "Shot Caller", "reward": "$150,000 clean, 100x Guards, 5x Combat Stims" }
		8: # Underboss: $300k clean, 25x Black Hand, network_tap
			run.clean_bank_cash += 300000
			Army.add(run, Army.Tier.BLACK_HAND, Army.State.ACTIVE, 25)
			Inventory.add_units(run, &"network_tap", 1)
			return { "rank": new_rank, "title": "Underboss", "reward": "$300,000 clean, 25x Black Hand, Network Tap" }
	return {}


## Sales earn a little cred, capped per sale and per day so grinding trades cannot carry the whole climb.
static func add_from_sale(run: RunState, sale_value: int) -> int:
	if run.cred_day != run.day:
		run.cred_day = run.day
		run.trading_cred_today = 0
	var gain := mini(MAX_SALE_GAIN, floori(float(sale_value) / SALE_VALUE_PER_POINT))
	gain = mini(gain, DAILY_TRADING_CAP - run.trading_cred_today)
	if gain <= 0:
		return 0
	run.trading_cred_today += gain
	add(run, gain)
	return gain
