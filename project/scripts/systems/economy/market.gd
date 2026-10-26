class_name Market

## Dealers buy back at this fraction of their asking price.
const SELL_SPREAD := 0.9
const DAY_SWING_MIN := 0.85
const DAY_SWING_MAX := 1.15
const PHASE_SWING_MIN := 0.96
const PHASE_SWING_MAX := 1.04

## Prices are derived from the run seed instead of stored, so every phase is reproducible after a reload.
static func asking_price_at(run: RunState, dealer: DealerDef, item: ItemDef, phase_stamp: int) -> int:
	var day_index := floori(float(phase_stamp) / RunState.Phase.size())
	var day_factor := roll(run, [day_index, dealer.id, item.id], DAY_SWING_MIN, DAY_SWING_MAX)
	var phase_factor := roll(run, [phase_stamp, dealer.id, item.id], PHASE_SWING_MIN, PHASE_SWING_MAX)
	var district_id := trading_district(run, dealer, phase_stamp)
	var event_factor := StreetEvents.price_multiplier(run, district_id, item.category, phase_stamp)
	return maxi(1, roundi(item.base_price * dealer.bias_for(item.category) * day_factor * phase_factor * event_factor))


static func buy_price(run: RunState, dealer: DealerDef, item: ItemDef) -> int:
	var asking := asking_price_at(run, dealer, item, Calendar.stamp(run))
	return maxi(1, roundi(asking * Families.buy_factor(run, dealer) * (1.0 - Skills.buy_discount(run) - Edges.buy_discount(run))))


static func sell_price(run: RunState, dealer: DealerDef, item: ItemDef) -> int:
	var stamp := Calendar.stamp(run)
	var factor := SELL_SPREAD * Turf.sell_factor(run, trading_district(run, dealer, stamp)) * Families.sell_factor(run, dealer)
	return maxi(1, floori(asking_price_at(run, dealer, item, stamp) * factor))


## Where the dealer trades in that phase. Falls back to home while a travelling dealer is off duty.
static func trading_district(run: RunState, dealer: DealerDef, phase_stamp: int) -> StringName:
	var location := Roster.dealer_location(run, dealer, phase_stamp)
	return location if not location.is_empty() else dealer.district_id


## Fractional change in asking price since the previous phase.
static func price_change(run: RunState, dealer: DealerDef, item: ItemDef) -> float:
	var current_stamp := Calendar.stamp(run)
	if current_stamp == 0:
		return 0.0
	var previous := asking_price_at(run, dealer, item, current_stamp - 1)
	return float(asking_price_at(run, dealer, item, current_stamp) - previous) / previous


## The trade good the dealer pays the most for, measured against its base price.
static func best_sale(run: RunState, dealer: DealerDef) -> ItemDef:
	var best: ItemDef = null
	var best_ratio := 0.0
	for item in Tiers.goods(dealer.tier):
		var ratio := float(sell_price(run, dealer, item)) / item.base_price
		if best == null or ratio > best_ratio:
			best = item
			best_ratio = ratio
	return best


## The open dealer in the player's district who pays the most for the item. Null when nobody here will trade.
static func best_local_buyer(run: RunState, item: ItemDef) -> DealerDef:
	var best: DealerDef = null
	for dealer in Roster.dealers_at(run, run.district_id, Calendar.stamp(run)):
		if is_open(run, dealer) and dealer.deals_in(item) and (best == null or sell_price(run, dealer, item) > sell_price(run, best, item)):
			best = dealer
	return best


static func is_open(run: RunState, dealer: DealerDef) -> bool:
	if int(run.walked_out.get(dealer.id, -1)) == Calendar.stamp(run) or Families.refuses(run, dealer):
		return false
	if Lending.is_dealer_locked_down(run, dealer.id):
		return false
	return true


static func roll(run: RunState, parts: Array, low: float, high: float) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run.price_seed] + parts)
	return rng.randf_range(low, high)
