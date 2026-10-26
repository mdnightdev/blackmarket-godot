class_name Money

## Dirty cash vs Clean money operations, 3-day laundering pipeline, and weighted seizures.

const CARRIED_DIRTY_THRESHOLD := 20000
const WITHDRAWAL_HEAT_THRESHOLD := 5000
const WITHDRAWAL_FRENZY_SECONDS := 240.0
const LAUNDER_DAYS := 3

## Severity weights 1 to 10 (sum = 100).
## 1-3: ~6%, 4-5: ~20%, 6-8: ~60%, 9: 10%, 10: 4% (capped at 50% max).
const SEVERITY_WEIGHTS: Array[int] = [1, 2, 3, 8, 12, 20, 22, 18, 10, 4]
const SEVERITY_SHARES: Array[float] = [0.10, 0.12, 0.15, 0.20, 0.25, 0.30, 0.33, 0.35, 0.40, 0.50]


const INSTRUMENTS: Dictionary = {
	&"swiss_ledgers": {
		"id": &"swiss_ledgers",
		"name": "Swiss Bank Ledgers",
		"cap": 100000,
		"fee": 0.15,
		"days": 3,
	},
	&"shell_company": {
		"id": &"shell_company",
		"name": "Shell Company",
		"cap": 500000,
		"fee": 0.10,
		"days": 2,
	},
	&"offshore_access": {
		"id": &"offshore_access",
		"name": "Offshore Account Access",
		"cap": 2000000,
		"fee": 0.05,
		"days": 1,
	},
}


static func instrument_def(id: StringName) -> Dictionary:
	return INSTRUMENTS.get(id, {})


static func all_instruments() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for id: StringName in INSTRUMENTS:
		list.append(INSTRUMENTS[id].duplicate())
	return list


static func has_instrument(run: RunState, instrument_id: StringName) -> bool:
	return Inventory.count(run, instrument_id) > 0 or Inventory.stashed(run, instrument_id) > 0


static func instrument_capacity_free(run: RunState, instrument_id: StringName) -> int:
	if not has_instrument(run, instrument_id):
		return 0
	var def: Dictionary = INSTRUMENTS.get(instrument_id, {})
	if def.is_empty():
		return 0
	var cap: int = int(def.get("cap", 0))
	var committed := 0
	var inst_str := String(instrument_id)
	for batch in run.laundering:
		if str(batch.get("instrument", "")) == inst_str or str(batch.get("business", "")) == inst_str:
			committed += int(batch.get("dirty_amount", 0))
	return maxi(0, cap - committed)


static func start_instrument_laundering(run: RunState, instrument_id: StringName, amount: int) -> bool:
	if amount <= 0 or amount > run.cash:
		return false
	if not has_instrument(run, instrument_id):
		return false
	var def: Dictionary = INSTRUMENTS.get(instrument_id, {})
	if def.is_empty():
		return false
	if amount > instrument_capacity_free(run, instrument_id):
		return false
	run.cash -= amount
	run.laundering.append({
		"instrument": String(instrument_id),
		"business": String(instrument_id),
		"dirty_amount": amount,
		"days_left": int(def.get("days", 3)),
		"fee": float(def.get("fee", 0.15)),
	})
	return true


static func total_laundering_in_transit(run: RunState) -> int:
	var total := 0
	for batch in run.laundering:
		total += int(batch.get("dirty_amount", 0))
	return total


static func roll_seizure(roll := -1.0) -> Dictionary:
	var value := randf() if roll < 0.0 else clampf(roll, 0.0, 0.9999)
	var accumulated := 0.0
	for i in SEVERITY_WEIGHTS.size():
		accumulated += float(SEVERITY_WEIGHTS[i]) / 100.0
		if value < accumulated or i == SEVERITY_WEIGHTS.size() - 1:
			return {
				"level": i + 1,
				"share": SEVERITY_SHARES[i],
			}
	return { "level": 7, "share": 0.33 }


static func launder_capacity_free(run: RunState, entry: Dictionary) -> int:
	var business := Businesses.definition(entry)
	if business == null:
		return 0
	var cap := business.effective_launder_capacity()
	if cap <= 0:
		return 0
	var committed := 0
	var biz_id := String(business.id)
	var dist_id := String(Businesses.district_of(entry))
	for batch in run.laundering:
		if str(batch.get("business", "")) == biz_id and str(batch.get("district", "")) == dist_id:
			committed += int(batch.get("dirty_amount", 0))
	return maxi(0, cap - committed)


static func start_laundering(run: RunState, entry: Dictionary, amount: int) -> bool:
	if amount <= 0 or amount > run.cash:
		return false
	if not Businesses.is_open(run, entry):
		return false
	var business := Businesses.definition(entry)
	if business == null:
		return false
	if amount > launder_capacity_free(run, entry):
		return false
	run.cash -= amount
	run.laundering.append({
		"business": String(business.id),
		"district": String(Businesses.district_of(entry)),
		"dirty_amount": amount,
		"days_left": LAUNDER_DAYS,
		"fee": business.launder_fee,
	})
	return true


static func advance_laundering(run: RunState) -> Dictionary:
	var cleaned_clean := 0
	var washed_dirty := 0
	var completed_batches := 0
	var remaining: Array[Dictionary] = []

	for batch in run.laundering:
		var days_left := int(batch.get("days_left", LAUNDER_DAYS)) - 1
		var dirty := int(batch.get("dirty_amount", 0))
		var fee := float(batch.get("fee", 0.2))

		if days_left <= 0:
			var fee_cut := floori(dirty * fee)
			var net_clean := dirty - fee_cut
			run.clean += net_clean
			cleaned_clean += net_clean
			washed_dirty += dirty
			completed_batches += 1
		else:
			batch.days_left = days_left
			remaining.append(batch)

	run.laundering = remaining
	return {
		"cleaned_clean": cleaned_clean,
		"washed_dirty": washed_dirty,
		"completed_batches": completed_batches,
	}


static func raid_front(run: RunState, district_id: StringName, business_id: StringName, seizure_share: float) -> int:
	var total_seized := 0
	var dist_str := String(district_id)
	var biz_str := String(business_id)
	for batch in run.laundering:
		if str(batch.get("district", "")) == dist_str and str(batch.get("business", "")) == biz_str:
			var dirty := int(batch.get("dirty_amount", 0))
			var seized := floori(dirty * seizure_share)
			batch.dirty_amount = dirty - seized
			total_seized += seized
	return total_seized


static func withdraw_clean(run: RunState, amount: int) -> bool:
	if amount <= 0 or amount > run.clean:
		return false
	run.clean -= amount
	run.cash += amount
	if amount >= WITHDRAWAL_HEAT_THRESHOLD:
		Heat.activate_frenzy(run, WITHDRAWAL_FRENZY_SECONDS)
		Heat.add(run, clampi(floori(float(amount) / 2000.0), 5, 25))
	return true


static func check_carried_seizure(run: RunState, roll := -1.0) -> Dictionary:
	if run.cash <= CARRIED_DIRTY_THRESHOLD:
		return { "seized": 0, "level": 0, "share": 0.0 }
	var seizure := roll_seizure(roll)
	var excess := run.cash - CARRIED_DIRTY_THRESHOLD
	var seized := floori(excess * seizure.share)
	run.cash -= seized
	return {
		"seized": seized,
		"level": seizure.level,
		"share": seizure.share,
	}


## Cash in the vault (stashed_cash) is secure and never seized.
static func check_stash_seizure(_run: RunState, _roll := -1.0) -> Dictionary:
	return { "seized": 0, "level": 0, "share": 0.0 }
