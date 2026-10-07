class_name Market

## Dealers buy back at this fraction of their asking price.
const SELL_SPREAD := 0.9
const DAY_SWING_MIN := 0.7
const DAY_SWING_MAX := 1.3
const PHASE_SWING_MIN := 0.94
const PHASE_SWING_MAX := 1.06
## Dealers pay less while the rival crew is buying in the same district.
const RIVAL_SELL_FACTOR := 0.9


## Prices are derived from the run seed instead of stored, so every phase is reproducible after a reload.
static func asking_price_at(run: RunState, dealer: DealerDef, item: ItemDef, phase_stamp: int) -> int:
	var day_index := floori(float(phase_stamp) / RunState.Phase.size())
	var day_factor := roll(run, [day_index, dealer.id, item.id], DAY_SWING_MIN, DAY_SWING_MAX)
	var phase_factor := roll(run, [phase_stamp, dealer.id, item.id], PHASE_SWING_MIN, PHASE_SWING_MAX)
	var district_id := trading_district(run, dealer, phase_stamp)
	var event_factor := StreetEvents.price_multiplier(run, district_id, item.category, phase_stamp)
	return maxi(1, roundi(item.base_price * dealer.bias_for(item.category) * day_factor * phase_factor * event_factor))


static func buy_price(run: RunState, dealer: DealerDef, item: ItemDef) -> int:
	return asking_price_at(run, dealer, item, Calendar.stamp(run))


static func sell_price(run: RunState, dealer: DealerDef, item: ItemDef) -> int:
	var stamp := Calendar.stamp(run)
	var factor := SELL_SPREAD
	if Roster.rival_in(run, trading_district(run, dealer, stamp), stamp):
		factor *= RIVAL_SELL_FACTOR
	return maxi(1, floori(buy_price(run, dealer, item) * factor))


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


static func is_open(run: RunState, dealer: DealerDef) -> bool:
	return int(run.walked_out.get(dealer.id, -1)) != Calendar.stamp(run)


static func roll(run: RunState, parts: Array, low: float, high: float) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run.price_seed] + parts)
	return rng.randf_range(low, high)
