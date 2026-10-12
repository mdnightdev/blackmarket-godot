class_name Businesses

## Fronts the player owns in held districts. Each one sells its stocked goods every phase.
## Entry layout: { "business": id, "district": id, "stock": { item id: units }, "closed_until": day }.
## Ids are stored as String so entries look the same before and after a save.

enum Result { OK, NOT_CAREER, UNKNOWN, NOT_HELD, RANK_TOO_LOW, NO_SLOT, NOT_ENOUGH_CASH, NO_STOCK, NO_ROOM, CLOSED }

## Fraction of the local sell price a business gets for its goods.
const SALE_FACTOR := 0.9
## Share of the takings the home family keeps unless it trusts the player.
const PROTECTION_CUT := 0.1
const BASE_RAID_CHANCE := 0.04
const RAID_PER_HEAT := 0.0005
## Lookouts in a held district keep raids on its businesses down.
const RAID_HELD_REDUCTION := 0.02
const MIN_RAID_CHANCE := 0.01
const HOSTILE_RAID_FACTOR := 2.0
const LUXURY: StringName = &"luxury"


## Returns an empty entry when the business or district no longer exists.
static func sanitize(entry: Dictionary) -> Dictionary:
	var business := Content.business(StringName(str(entry.get("business", ""))))
	var district_id := str(entry.get("district", ""))
	if business == null or Content.district(StringName(district_id)) == null:
		return {}
	var stock := {}
	var saved_stock: Variant = entry.get("stock", {})
	if saved_stock is Dictionary:
		for key: Variant in saved_stock:
			var units := int(saved_stock[key])
			if units > 0 and Content.item(StringName(str(key))) != null:
				stock[str(key)] = units
	return {
		"business": String(business.id),
		"district": district_id,
		"stock": stock,
		"closed_until": maxi(0, int(entry.get("closed_until", 0))),
	}


static func definition(entry: Dictionary) -> BusinessDef:
	return Content.business(StringName(str(entry.get("business", ""))))


static func district_of(entry: Dictionary) -> StringName:
	return StringName(str(entry.get("district", "")))


static func in_district(run: RunState, district_id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in run.businesses:
		if district_of(entry) == district_id:
			result.append(entry)
	return result


static func slots_free(run: RunState, district_id: StringName) -> int:
	return maxi(0, Turf.business_slots(run, district_id) - in_district(run, district_id).size())


static func check_buy(run: RunState, business: BusinessDef, district_id: StringName) -> Result:
	if not Campaign.is_act_two(run):
		return Result.NOT_CAREER
	if business == null:
		return Result.UNKNOWN
	if not Turf.holds(run, district_id):
		return Result.NOT_HELD
	if StreetCred.rank(run) < business.min_rank:
		return Result.RANK_TOO_LOW
	if slots_free(run, district_id) <= 0:
		return Result.NO_SLOT
	if run.cash < business.price:
		return Result.NOT_ENOUGH_CASH
	return Result.OK


static func buy(run: RunState, business: BusinessDef, district_id: StringName) -> Result:
	var result := check_buy(run, business, district_id)
	if result != Result.OK:
		return result
	run.cash -= business.price
	run.businesses.append({
		"business": String(business.id),
		"district": String(district_id),
		"stock": {},
		"closed_until": 0,
	})
	return Result.OK


static func stocked(entry: Dictionary, item_id: StringName) -> int:
	var stock: Dictionary = entry.get("stock", {})
	return int(stock.get(String(item_id), 0))


## Units of one item on the shelves of every business.
static func total_stocked(run: RunState, item_id: StringName) -> int:
	var total := 0
	for entry in run.businesses:
		total += stocked(entry, item_id)
	return total


static func stock_used(entry: Dictionary) -> int:
	var total := 0
	var stock: Dictionary = entry.get("stock", {})
	for item_id: String in stock:
		total += int(stock[item_id])
	return total


static func stock_free(entry: Dictionary) -> int:
	var business := definition(entry)
	return maxi(0, business.stock_capacity - stock_used(entry)) if business != null else 0


static func max_load(run: RunState, entry: Dictionary, item: ItemDef) -> int:
	return mini(Inventory.count(run, item.id), stock_free(entry))


static func max_unload(run: RunState, entry: Dictionary, item: ItemDef) -> int:
	return mini(stocked(entry, item.id), floori(float(Inventory.free_space(run)) / item.slots))


## Moves carried units onto the shelves. Their price paid stays in run.cost_basis.
static func load_stock(run: RunState, entry: Dictionary, item: ItemDef, quantity: int) -> Result:
	if definition(entry) == null:
		return Result.UNKNOWN
	if not is_open(run, entry):
		return Result.CLOSED
	if quantity <= 0 or quantity > Inventory.count(run, item.id):
		return Result.NO_STOCK
	if quantity > stock_free(entry):
		return Result.NO_ROOM
	Inventory.add_units(run, item.id, -quantity)
	_add_stock(entry, item.id, quantity)
	return Result.OK


## Works while the business is closed so stock is never stranded after a raid or a lost district.
static func unload_stock(run: RunState, entry: Dictionary, item: ItemDef, quantity: int) -> Result:
	if definition(entry) == null:
		return Result.UNKNOWN
	if quantity <= 0 or quantity > stocked(entry, item.id):
		return Result.NO_STOCK
	if item.slots * quantity > Inventory.free_space(run):
		return Result.NO_ROOM
	_add_stock(entry, item.id, -quantity)
	Inventory.add_units(run, item.id, quantity)
	return Result.OK


static func is_open(run: RunState, entry: Dictionary) -> bool:
	return run.day >= int(entry.get("closed_until", 0)) and Turf.holds(run, district_of(entry))


## What the business gets for one unit before the protection cut. Uses the district's resident
## dealer, or the base price where no dealer lives.
static func sale_price(run: RunState, entry: Dictionary, item: ItemDef) -> int:
	var business := definition(entry)
	var dealer := Content.dealer_in(district_of(entry))
	var local_price := Market.sell_price(run, dealer, item) if dealer != null else item.base_price
	var bonus := business.luxury_bonus if business != null and item.category == LUXURY else 0.0
	return maxi(1, floori(local_price * SALE_FACTOR * (1.0 + bonus)))


static func pays_protection(run: RunState, district_id: StringName) -> bool:
	var family := Turf.home_family(district_id)
	return family != null and Families.tier(run, family.id) < Families.Tier.TRUSTED


## Sells from every open business, most valuable goods first. Returns the cash earned.
static func sell_phase(run: RunState) -> int:
	var earned := 0
	for entry in run.businesses:
		var business := definition(entry)
		if business == null or not is_open(run, entry):
			continue
		var takings := 0
		var paid := 0
		var remaining := business.sales_per_phase
		for sale in _sales_by_value(run, entry):
			if remaining <= 0:
				break
			var item: ItemDef = sale.item
			var units := mini(remaining, stocked(entry, item.id))
			var unit_price := int(sale.price)
			takings += unit_price * units
			paid += int(run.cost_basis.get(item.id, unit_price)) * units
			remaining -= units
			_add_stock(entry, item.id, -units)
			_forget_basis_if_gone(run, item.id)
		if takings == 0:
			continue
		if pays_protection(run, district_of(entry)):
			takings -= floori(takings * PROTECTION_CUT)
		run.cash += takings
		run.profit += takings - paid
		earned += takings
	return earned


static func raid_chance(run: RunState, entry: Dictionary) -> float:
	var district_id := district_of(entry)
	var chance := BASE_RAID_CHANCE + run.heat * RAID_PER_HEAT - (RAID_HELD_REDUCTION if Turf.holds(run, district_id) else 0.0)
	chance = maxf(chance, MIN_RAID_CHANCE)
	if Families.hostile_family_in(run, district_id) != null:
		chance *= HOSTILE_RAID_FACTOR
	return chance


## Pays upkeep, cools heat and rolls raids. rolls[i] is for run.businesses[i] and must be in [0, 1);
## a missing roll means no raid. Returns { "upkeep": int, "raided": Array[String] of display names }.
static func morning(run: RunState, rolls: Array[float]) -> Dictionary:
	var upkeep := 0
	for entry in run.businesses:
		var business := definition(entry)
		if business == null:
			continue
		if run.cash >= business.daily_upkeep:
			run.cash -= business.daily_upkeep
			upkeep += business.daily_upkeep
		else:
			_close_for_today(run, entry)
		if is_open(run, entry):
			Heat.add(run, -business.daily_heat_drop)

	var raided: Array[String] = []
	for index in run.businesses.size():
		var entry := run.businesses[index]
		var business := definition(entry)
		if business == null or index >= rolls.size() or rolls[index] >= raid_chance(run, entry):
			continue
		var lost: Dictionary = entry.get("stock", {})
		entry.stock = {}
		for item_id: String in lost:
			_forget_basis_if_gone(run, StringName(item_id))
		_close_for_today(run, entry)
		raided.append(business.display_name)
	return { "upkeep": upkeep, "raided": raided }


static func _sales_by_value(run: RunState, entry: Dictionary) -> Array[Dictionary]:
	var sales: Array[Dictionary] = []
	var stock: Dictionary = entry.get("stock", {})
	for item_id: String in stock:
		var item := Content.item(StringName(item_id))
		if item != null:
			sales.append({ "item": item, "price": sale_price(run, entry, item) })
	sales.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.price != b.price:
			return a.price > b.price
		return str(a.item.id) < str(b.item.id))
	return sales


static func _add_stock(entry: Dictionary, item_id: StringName, quantity: int) -> void:
	if not entry.has("stock"):
		entry.stock = {}
	var stock: Dictionary = entry.stock
	var key := String(item_id)
	var total := int(stock.get(key, 0)) + quantity
	if total > 0:
		stock[key] = total
	else:
		stock.erase(key)


static func _close_for_today(run: RunState, entry: Dictionary) -> void:
	entry.closed_until = maxi(int(entry.get("closed_until", 0)), run.day + 1)


static func _forget_basis_if_gone(run: RunState, item_id: StringName) -> void:
	if Inventory.count(run, item_id) == 0 and Inventory.stashed(run, item_id) == 0 and total_stocked(run, item_id) == 0:
		run.cost_basis.erase(item_id)
