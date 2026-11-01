class_name Fixer

## Rook's clean-up service: pay to make heat go away, once per phase.

static var CLEAN_UP_ICON: Texture2D:
	get:
		return ItemsAtlas.get_icon(&"fake_cash")
const CLEAN_UP_HEAT := 25
const CLEAN_UP_BASE_COST := 400
const CLEAN_UP_COST_PER_HEAT := 20


static func heat_removed(run: RunState) -> int:
	return mini(run.heat, CLEAN_UP_HEAT)


static func clean_up_cost(run: RunState) -> int:
	return CLEAN_UP_BASE_COST + heat_removed(run) * CLEAN_UP_COST_PER_HEAT


static func cleaned_up(run: RunState) -> bool:
	return run.cleanup_stamp == Calendar.stamp(run)


static func can_clean_up(run: RunState) -> bool:
	return run.heat > 0 and not cleaned_up(run) and run.cash >= clean_up_cost(run)


## Returns the heat removed, 0 when the service was not available.
static func clean_up(run: RunState) -> int:
	if not can_clean_up(run):
		return 0
	var removed := heat_removed(run)
	run.cash -= clean_up_cost(run)
	run.cleanup_stamp = Calendar.stamp(run)
	Heat.add(run, -removed)
	return removed
