class_name CustomerOffers

## Who posts a customer order and what it asks for. Orders are priced against the street price, the average
## asking price of the dealers who stock the goods, so they follow the market and the cheapest source beats it.
## See Customers for the entry layout.

const OFFER_PHASES := 3
const POST_CHANCE := 0.65
## Customers do not respect a new face. In Act 1 they post less often, a little more with every rank.
const ACT_ONE_POST_CHANCE := 0.3
const ACT_ONE_CHANCE_PER_RANK := 0.05
const MIN_LEAD_PHASES := 3
const MAX_LEAD_PHASES := 6
const MIN_RUSH_PHASES := 1
const MAX_RUSH_PHASES := 2
## Rush orders pay this much more per unit.
const RUSH_BONUS := 1.15
## Order value as a multiple of the district's job pay, before the temperament's size. The player keeps the margin.
const ORDER_VALUE_PER_PAY := 1.75
const MIN_QUANTITY := 2
## Share a haggler knocks off the agreed price at the handover: the floor, the usual and the steep one.
const HAGGLE_LOW := 0.08
const HAGGLE_USUAL := 0.13
const HAGGLE_HIGH := 0.2
## Undercover buyers only post once the police are active and the player is this hot or the district this strict.
const STING_MIN_HEAT := 40
const STING_HOT_DISTRICT := 1.4
## price is the unit price as a share of the street price (floor, usual, cap). size scales the order value,
## rush is the chance of a rush order and weight how often the customer gets picked to post.
const PROFILES := {
	CustomerDef.Temperament.LOWBALLER: { "price": [0.78, 0.88, 0.96], "size": 1.0, "rush": 0.0, "weight": 1.0 },
	CustomerDef.Temperament.FAIR: { "price": [1.05, 1.11, 1.2], "size": 1.0, "rush": 0.2, "weight": 1.0 },
	CustomerDef.Temperament.GENEROUS: { "price": [1.15, 1.23, 1.36], "size": 0.6, "rush": 0.35, "weight": 0.6 },
	CustomerDef.Temperament.BULK: { "price": [0.97, 1.03, 1.1], "size": 2.5, "rush": 0.0, "weight": 0.8 },
	CustomerDef.Temperament.HAGGLER: { "price": [1.12, 1.2, 1.32], "size": 1.0, "rush": 0.2, "weight": 1.0 },
	CustomerDef.Temperament.FLAKY: { "price": [1.12, 1.2, 1.34], "size": 1.0, "rush": 0.2, "weight": 0.8 },
	CustomerDef.Temperament.STING: { "price": [1.7, 1.9, 2.2], "size": 0.8, "rush": 0.0, "weight": 0.4 },
}


## Posts this phase's customer order when one comes in and the phone has room. Returns the new offers.
static func post(run: RunState) -> Array[Dictionary]:
	var posted: Array[Dictionary] = []
	if Campaign.is_over(run) or run.customer_offers.size() >= Customers.MAX_OPEN_OFFERS:
		return posted
	var id := _id_for(Calendar.stamp(run))
	if not Customers.find_offer(run, id).is_empty() or not Customers.find(run, id).is_empty():
		return posted
	var rng := Odds.rng_for(run, &"customer")
	if rng.randf() >= post_chance(run):
		return posted
	var customer := _pick(rng, eligible(run))
	if customer == null:
		return posted
	var offer := generate(run, customer)
	if offer.is_empty():
		return posted
	run.customer_offers.append(offer)
	posted.append(offer)
	return posted


static func post_chance(run: RunState) -> float:
	if Campaign.is_act_two(run):
		return POST_CHANCE
	return minf(POST_CHANCE, ACT_ONE_POST_CHANCE + StreetCred.rank(run) * ACT_ONE_CHANCE_PER_RANK)


## Customers who could post this phase: working now, ranked for, reachable and not already waiting on the player.
static func eligible(run: RunState) -> Array[CustomerDef]:
	var rank := StreetCred.rank(run)
	var waiting: Array[String] = []
	for entry in run.customer_offers + run.customer_orders:
		waiting.append(str(entry.customer))
	var list: Array[CustomerDef] = []
	for customer in Content.customers():
		var district := Content.district(customer.district_id)
		if district == null or not customer.posts_in(run.phase) or rank < customer.min_rank or waiting.has(String(customer.id)):
			continue
		if Travel.is_locked(run, district) or PayScale.outgrown(run, district.tier):
			continue
		if customer.temperament == CustomerDef.Temperament.STING and not sting_ready(run, district):
			continue
		list.append(customer)
	return list


static func sting_ready(run: RunState, district: DistrictDef) -> bool:
	return not Police.is_quiet(run) and (run.heat >= STING_MIN_HEAT or district.heat_multiplier >= STING_HOT_DISTRICT)


## The customer's order for this phase. It comes from the run seed, so a reload cannot reroll it.
## From Act 2 quantities can outgrow the bag by the next bag upgrade, so bigger orders ask for a bigger bag.
## Empty when none of the goods they want exist.
static func generate(run: RunState, customer: CustomerDef) -> Dictionary:
	var district := Content.district(customer.district_id)
	var tier := district.tier if district != null else Tiers.STREET
	var goods: Array[ItemDef] = []
	for item in Tiers.goods(tier):
		if customer.wants.has(item.category):
			goods.append(item)
	if goods.is_empty():
		return {}
	var rng := Odds.rng_for(run, StringName("customer:%s" % customer.id))
	var profile: Dictionary = PROFILES[customer.temperament]
	var target := PayScale.roll(rng, run, tier) * ORDER_VALUE_PER_PAY * float(profile.size)
	var item := _pick_goods(run, rng, goods, target)
	var street := street_price(run, item)
	var rush := rng.randf() < float(profile.rush)
	var price_range: Array = profile.price
	var factor := Odds.bell(rng, price_range[0], price_range[1], price_range[2]) * (RUSH_BONUS if rush else 1.0)
	var unit_price := maxi(1, roundi(street * factor))
	var most := maxi(MIN_QUANTITY, floori(float(max_slots(run)) / item.slots))
	var counter_price := 0
	if customer.temperament == CustomerDef.Temperament.HAGGLER:
		counter_price = maxi(1, roundi(unit_price * (1.0 - Odds.bell(rng, HAGGLE_LOW, HAGGLE_USUAL, HAGGLE_HIGH))))
	var stamp := Calendar.stamp(run)
	return {
		"id": _id_for(stamp),
		"customer": String(customer.id),
		"item": String(item.id),
		"quantity": clampi(roundi(target / unit_price), MIN_QUANTITY, most),
		"unit_price": unit_price,
		"street_price": street,
		"district": String(customer.district_id),
		"temperament": customer.temperament,
		"rush": rush,
		"lead": rng.randi_range(MIN_RUSH_PHASES, MAX_RUSH_PHASES) if rush else rng.randi_range(MIN_LEAD_PHASES, MAX_LEAD_PHASES),
		"posted_stamp": stamp,
		"expires_stamp": stamp + OFFER_PHASES - 1,
		"due_stamp": -1,
		"counter_price": counter_price,
		"countered": false,
	}


## The average asking price this phase across the dealers who stock the item and are trading.
static func street_price(run: RunState, item: ItemDef) -> int:
	var stamp := Calendar.stamp(run)
	var total := 0
	var sellers := 0
	for dealer in Content.dealers():
		if dealer.sells(item) and not Roster.dealer_location(run, dealer, stamp).is_empty():
			total += Market.asking_price_at(run, dealer, item, stamp)
			sellers += 1
	if sellers == 0:
		return item.base_price
	return maxi(1, roundi(float(total) / sellers))


## The most bag slots an order can ask for: the bag now plus the next upgrade, or only the bag now in Act 1.
static func max_slots(run: RunState) -> int:
	if not Campaign.is_act_two(run):
		return Inventory.capacity(run)
	return Inventory.capacity(run) + Gear.next_capacity_bonus(run)


## A random pick among the goods the order value buys at least MIN_QUANTITY of and still fits in max_slots.
## When none do, the dearest, so a big order fills the bag instead of shrinking to cheap goods.
static func _pick_goods(run: RunState, rng: RandomNumberGenerator, goods: Array[ItemDef], target: float) -> ItemDef:
	var fitting: Array[ItemDef] = []
	var dearest := goods[0]
	for item in goods:
		var units := target / street_price(run, item)
		if units >= MIN_QUANTITY and units <= float(max_slots(run)) / item.slots:
			fitting.append(item)
		if item.base_price > dearest.base_price:
			dearest = item
	if fitting.is_empty():
		return dearest
	return fitting[rng.randi_range(0, fitting.size() - 1)]


static func _pick(rng: RandomNumberGenerator, candidates: Array[CustomerDef]) -> CustomerDef:
	var total_weight := 0.0
	for customer in candidates:
		total_weight += float(PROFILES[customer.temperament].weight)
	if total_weight <= 0.0:
		return null
	var target := rng.randf() * total_weight
	for customer in candidates:
		target -= float(PROFILES[customer.temperament].weight)
		if target < 0.0:
			return customer
	return candidates[-1]


static func _id_for(stamp: int) -> String:
	return "customer:%d" % stamp
