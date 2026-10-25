class_name Rumors

## Paid bar gossip: one real price from a dealer trading somewhere else right now.
## Each bar sells one rumour per phase. run.rumors_heard maps venue id to the phase stamp it was bought in.

const PRICE := 120


static func sold_out(run: RunState, venue_id: StringName) -> bool:
	return int(run.rumors_heard.get(venue_id, -1)) == Calendar.stamp(run)


static func can_afford(run: RunState) -> bool:
	return run.cash >= PRICE


## The rumour this bar would tell, as { dealer, item, price, district }. Empty when there is nothing new to tell.
static func find(run: RunState, venue_id: StringName) -> Dictionary:
	var stamp := Calendar.stamp(run)
	var candidates: Array[DealerDef] = []
	for dealer in Content.dealers():
		var location := Roster.dealer_location(run, dealer, stamp)
		if not location.is_empty() and location != run.district_id and not _seen_this_phase(run, dealer):
			candidates.append(dealer)
	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(a: DealerDef, b: DealerDef) -> bool: return String(a.id) < String(b.id))
	var pick := floori(Market.roll(run, [&"rumor", venue_id, stamp], 0.0, 1.0) * candidates.size())
	var dealer := candidates[mini(pick, candidates.size() - 1)]
	var best_item := Market.best_sale(run, dealer)
	return {
		"dealer": dealer,
		"item": best_item,
		"price": Market.sell_price(run, dealer, best_item),
		"district": Content.district(Roster.dealer_location(run, dealer, stamp)),
	}


## Charges for the rumour and adds that dealer's prices to the player's price intel.
## Returns the rumour, or an empty dictionary when nothing was sold.
static func buy(run: RunState, venue_id: StringName) -> Dictionary:
	if sold_out(run, venue_id) or not can_afford(run):
		return {}
	var rumor := find(run, venue_id)
	if rumor.is_empty():
		return {}
	run.cash -= PRICE
	run.rumors_heard[venue_id] = Calendar.stamp(run)
	PriceIntel.record(run, rumor.dealer, Content.items(ItemDef.Kind.TRADE_GOOD))
	return rumor


static func _seen_this_phase(run: RunState, dealer: DealerDef) -> bool:
	var dealer_id := String(dealer.id)
	var stamp := Calendar.stamp(run)
	for sighting in run.price_sightings:
		if sighting.dealer == dealer_id and int(sighting.stamp) == stamp:
			return true
	return false
