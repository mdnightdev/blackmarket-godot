class_name Edges

## The small edge each background brings to a run, picked with the character. See PlayerDef.Edge.

const ROUTES_TRIP_FACTOR := 0.75
const ROUTES_PUSH_RISK_FACTOR := 0.5
const VENUE_ORDER_BONUS := 0.1
const VENUE_NATURAL_PAYOUT := 3.0
const CREDIT_DEFAULT_FACTOR := 0.25
const BUY_DISCOUNT := 0.05


static func of(run: RunState) -> PlayerDef.Edge:
	var player := Content.player(run.player_id)
	return player.edge if player != null else PlayerDef.Edge.NONE


static func has(run: RunState, edge: PlayerDef.Edge) -> bool:
	return of(run) == edge


## Jin's old contacts warn of one raid a day, sharing the lookout's daily warning.
static func hears_of_raid(run: RunState) -> bool:
	return has(run, PlayerDef.Edge.INTEL) and run.raid_warning_day != run.day


static func use_raid_tip(run: RunState) -> void:
	run.raid_warning_day = run.day


## The gang whose boss Jin hears will work the district next phase, or null.
static func boss_next_phase(run: RunState, district_id: StringName) -> GangDef:
	if not has(run, PlayerDef.Edge.INTEL):
		return null
	return Gangs.in_district(run, district_id, Calendar.stamp(run) + 1)


static func trip_factor(run: RunState) -> float:
	return ROUTES_TRIP_FACTOR if has(run, PlayerDef.Edge.ROUTES) else 1.0


static func push_risk_factor(run: RunState) -> float:
	return ROUTES_PUSH_RISK_FACTOR if has(run, PlayerDef.Edge.ROUTES) else 1.0


static func spots_sting(run: RunState, order: Dictionary) -> bool:
	return has(run, PlayerDef.Edge.STINGS) and int(order.get("temperament", -1)) == CustomerDef.Temperament.STING


static func order_pay_factor(run: RunState) -> float:
	return 1.0 + VENUE_ORDER_BONUS if has(run, PlayerDef.Edge.VENUES) else 1.0


static func natural_payout(run: RunState) -> float:
	return VENUE_NATURAL_PAYOUT if has(run, PlayerDef.Edge.VENUES) else Casino.NATURAL_PAYOUT


static func default_factor(run: RunState) -> float:
	return CREDIT_DEFAULT_FACTOR if has(run, PlayerDef.Edge.CREDIT) else 1.0


static func buy_discount(run: RunState) -> float:
	return BUY_DISCOUNT if has(run, PlayerDef.Edge.BUY_PRICES) else 0.0
