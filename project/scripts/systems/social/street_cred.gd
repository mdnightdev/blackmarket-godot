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


static func add(run: RunState, amount: int) -> void:
	run.street_cred = clampi(run.street_cred + amount, 0, MAX)


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
