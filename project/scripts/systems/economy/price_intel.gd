class_name PriceIntel

## Sightings older than this many phases are forgotten, so hints never point at stale prices.
const MAX_AGE_PHASES := 8


## Sightings are stored as { item, dealer, district, buy, sell, stamp }. buy is 0 when the dealer does not stock the item.
## Returns true when the stored sightings changed.
static func record(run: RunState, dealer: DealerDef, goods: Array[ItemDef]) -> bool:
	var stamp := Calendar.stamp(run)
	var district_id := String(Market.trading_district(run, dealer, stamp))
	var dealer_id := String(dealer.id)
	var fresh: Array[Dictionary] = []
	for item in goods:
		fresh.append({
			"item": String(item.id),
			"dealer": dealer_id,
			"district": district_id,
			"buy": Market.buy_price(run, dealer, item) if dealer.sells(item) else 0,
			"sell": Market.sell_price(run, dealer, item) if dealer.deals_in(item) else 0,
			"stamp": stamp,
		})
	var previous := run.price_sightings.filter(func(sighting: Dictionary) -> bool: return sighting.dealer == dealer_id)
	if previous == fresh:
		return false
	prune(run)
	run.price_sightings = run.price_sightings.filter(func(sighting: Dictionary) -> bool: return sighting.dealer != dealer_id)
	run.price_sightings.append_array(fresh)
	return true


## The highest price another dealer was seen paying for the item. Empty when nothing is known.
static func best_sale(run: RunState, item: ItemDef, excluded_dealer: DealerDef) -> Dictionary:
	var best := {}
	for sighting in _fresh_sightings(run, item, excluded_dealer):
		if int(sighting.sell) > 0 and (best.is_empty() or int(sighting.sell) > int(best.sell)):
			best = sighting
	return best


## The lowest asking price seen at another dealer that stocks the item. Empty when nothing is known.
static func best_purchase(run: RunState, item: ItemDef, excluded_dealer: DealerDef) -> Dictionary:
	var best := {}
	for sighting in _fresh_sightings(run, item, excluded_dealer):
		if int(sighting.buy) > 0 and (best.is_empty() or int(sighting.buy) < int(best.buy)):
			best = sighting
	return best


## The latest fresh sighting of the item at one dealer. Empty when it was not seen there recently.
static func sighting_at(run: RunState, item: ItemDef, dealer: DealerDef) -> Dictionary:
	var dealer_id := String(dealer.id)
	var latest := {}
	for sighting in _fresh_sightings(run, item, null):
		if sighting.dealer == dealer_id and (latest.is_empty() or int(sighting.stamp) > int(latest.stamp)):
			latest = sighting
	return latest


static func age_text(run: RunState, sighting: Dictionary) -> String:
	var age := Calendar.stamp(run) - int(sighting.stamp)
	if age <= 0:
		return "this phase"
	if age == 1:
		return "last phase"
	return "%d phases ago" % age


static func prune(run: RunState) -> void:
	var oldest := Calendar.stamp(run) - MAX_AGE_PHASES
	run.price_sightings = run.price_sightings.filter(func(sighting: Dictionary) -> bool: return int(sighting.stamp) >= oldest)


static func sanitize_sighting(source: Dictionary) -> Dictionary:
	return {
		"item": str(source.get("item", "")),
		"dealer": str(source.get("dealer", "")),
		"district": str(source.get("district", "")),
		"buy": maxi(0, int(source.get("buy", 0))),
		"sell": maxi(0, int(source.get("sell", 0))),
		"stamp": int(source.get("stamp", -MAX_AGE_PHASES - 1)),
	}


static func _fresh_sightings(run: RunState, item: ItemDef, excluded_dealer: DealerDef) -> Array[Dictionary]:
	var oldest := Calendar.stamp(run) - MAX_AGE_PHASES
	var item_id := String(item.id)
	var excluded_id := String(excluded_dealer.id) if excluded_dealer != null else ""
	var list: Array[Dictionary] = []
	for sighting in run.price_sightings:
		if sighting.item == item_id and sighting.dealer != excluded_id and int(sighting.stamp) >= oldest:
			list.append(sighting)
	return list
