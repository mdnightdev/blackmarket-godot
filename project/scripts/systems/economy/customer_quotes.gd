class_name CustomerQuotes

## Where a customer order could be filled from and what it would clear. One entry per option:
## { source, district, unit_cost, known, seen_stamp, fares, profit, basis_profit, fits_bag, locked, open }
## source is BAG for goods already carried, otherwise a dealer id, and district is where that source trades now.
## A dealer's price is known when they trade where the player stands, or from a sighting no older than
## PriceIntel.MAX_AGE_PHASES; seen_stamp is the phase it was seen in, -1 while unknown. unit_cost is 0 for the bag and
## while unknown. fares is the trip to the source plus the trip on to the customer. profit is the order's pay minus
## goods and fares, 0 while unknown; for the bag it ignores what the goods cost and basis_profit takes that off using
## run.cost_basis (elsewhere basis_profit equals profit). fits_bag says whether the whole order fits in the free space,
## locked that the source's district is still closed and open that the source is trading this phase.
## Known options come first, best profit first.

const BAG := "bag"


static func quotes(run: RunState, order: Dictionary) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var item := Content.item(StringName(str(order.get("item", ""))))
	var destination := Content.district(StringName(str(order.get("district", ""))))
	if item == null or destination == null:
		return list
	var quantity := int(order.quantity)
	var pay := Customers.total(order)
	if Inventory.count(run, item.id) >= quantity:
		var fares := Travel.trip_fare(run, run.district_id, destination)
		list.append({
			"source": BAG,
			"district": String(run.district_id),
			"unit_cost": 0,
			"known": true,
			"seen_stamp": Calendar.stamp(run),
			"fares": fares,
			"profit": pay - fares,
			"basis_profit": pay - fares - int(run.cost_basis.get(item.id, 0)) * quantity,
			"fits_bag": true,
			"locked": false,
			"open": true,
		})
	var fits := item.slots * quantity <= Inventory.free_space(run)
	for dealer in Content.dealers():
		if not dealer.sells(item):
			continue
		var quote := _dealer_quote(run, dealer, item, destination, quantity, pay)
		if not quote.is_empty():
			quote.fits_bag = fits
			list.append(quote)
	list.sort_custom(_better)
	return list


## "Your bag" or the dealer's name.
static func source_name(quote: Dictionary) -> String:
	var source := str(quote.get("source", ""))
	if source == BAG:
		return "Your bag"
	var dealer := Content.dealer(StringName(source))
	return dealer.display_name if dealer != null else source


## What the goods cost, for example "$150 each, seen 2 phases ago".
static func price_text(run: RunState, quote: Dictionary) -> String:
	if str(quote.get("source", "")) == BAG:
		return "Already in your bag"
	if not bool(quote.get("known", false)):
		return "Price unknown"
	var price := "%s each" % Format.money(int(quote.unit_cost))
	if int(quote.seen_stamp) >= Calendar.stamp(run):
		return price
	return "%s, seen %s" % [price, PriceIntel.age_text(run, { "stamp": int(quote.seen_stamp) })]


## Signed profit, for example "+$1,200". A question mark while the price is unknown.
static func profit_text(quote: Dictionary) -> String:
	if not bool(quote.get("known", false)):
		return "?"
	return Format.signed_money(int(quote.profit))


## The most serious thing standing in the way of this option, empty when nothing does.
static func warning(quote: Dictionary) -> String:
	if bool(quote.get("locked", false)):
		return "Locked"
	if not bool(quote.get("open", true)):
		return "Closed now"
	if not bool(quote.get("fits_bag", true)):
		return "Bag too small"
	return ""


static func _dealer_quote(run: RunState, dealer: DealerDef, item: ItemDef, destination: DistrictDef, quantity: int, pay: int) -> Dictionary:
	var stamp := Calendar.stamp(run)
	var source := Content.district(Market.trading_district(run, dealer, stamp))
	if source == null:
		return {}
	var open := Roster.dealer_location(run, dealer, stamp) == source.id and Market.is_open(run, dealer)
	var unit_cost := 0
	var seen_stamp := -1
	if open and source.id == run.district_id:
		unit_cost = Market.buy_price(run, dealer, item)
		seen_stamp = stamp
	else:
		var sighting := PriceIntel.sighting_at(run, item, dealer)
		if not sighting.is_empty() and int(sighting.buy) > 0:
			unit_cost = int(sighting.buy)
			seen_stamp = int(sighting.stamp)
	var known := unit_cost > 0
	var fares := Travel.trip_fare(run, run.district_id, source) + Travel.trip_fare(run, source.id, destination)
	var profit := pay - unit_cost * quantity - fares if known else 0
	return {
		"source": String(dealer.id),
		"district": String(source.id),
		"unit_cost": unit_cost,
		"known": known,
		"seen_stamp": seen_stamp,
		"fares": fares,
		"profit": profit,
		"basis_profit": profit,
		"fits_bag": false,
		"locked": Travel.is_locked(run, source),
		"open": open,
	}


static func _better(a: Dictionary, b: Dictionary) -> bool:
	if bool(a.known) != bool(b.known):
		return bool(a.known)
	if bool(a.known) and int(a.profit) != int(b.profit):
		return int(a.profit) > int(b.profit)
	if int(a.fares) != int(b.fares):
		return int(a.fares) < int(b.fares)
	return str(a.source) < str(b.source)
