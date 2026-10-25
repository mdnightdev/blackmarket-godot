class_name Hacker

## Hana sells a look at every dealer's prices in another district, once per phase.
## The prices go into the player's price intel, so trade hints use them right away.

const PRICE := 300


static func hacked_this_phase(run: RunState) -> bool:
	return run.hack_stamp == Calendar.stamp(run)


static func can_hack(run: RunState) -> bool:
	return not hacked_this_phase(run) and run.cash >= PRICE


## Other districts with at least one dealer trading there this phase, in catalog order.
static func targets(run: RunState) -> Array[DistrictDef]:
	var stamp := Calendar.stamp(run)
	var list: Array[DistrictDef] = []
	for district in Content.districts():
		if district.id != run.district_id and not Roster.dealers_at(run, district.id, stamp).is_empty():
			list.append(district)
	return list


## Charges for the hack and records the prices of every dealer in the district.
## Returns those dealers, empty when nothing was sold.
static func hack(run: RunState, district_id: StringName) -> Array[DealerDef]:
	var dealers := Roster.dealers_at(run, district_id, Calendar.stamp(run))
	if dealers.is_empty() or district_id == run.district_id or not can_hack(run):
		return []
	run.cash -= PRICE
	run.hack_stamp = Calendar.stamp(run)
	var goods := Content.items(ItemDef.Kind.TRADE_GOOD)
	for dealer in dealers:
		PriceIntel.record(run, dealer, goods)
	return dealers
