class_name Lending

## Once the player buys the Shark out, his book is theirs. Each day a few dealers ask for money at the old office.
## A loan comes back with interest when the term ends, unless the dealer skips out. Then the Shark, now on the
## player's crew, collects part of it. run.dealer_loans holds { dealer, amount, repayment, due_day },
## at most one loan per dealer.

enum Result { OK, NOT_OWNER, NOT_HERE, GONE, NOT_ENOUGH_CASH }

const BUYOUT_PRICE := 750000
## The crew role the Shark fills, free of wages and outside the crew cap.
const ENFORCER_ROLE: StringName = &"muscle"
const REQUESTS_PER_DAY := 3
const TERM_DAYS := 5
## Share of a skipped loan the Shark collects.
const RECOVERED_SHARE := 0.75
const AMOUNTS := { Tiers.STREET: 50000, Tiers.MIDDLE: 250000, Tiers.WEALTHY: 750000 }
const INTEREST := { Tiers.STREET: 0.3, Tiers.MIDDLE: 0.2, Tiers.WEALTHY: 0.12 }
const SKIP_CHANCE := { Tiers.STREET: 0.25, Tiers.MIDDLE: 0.12, Tiers.WEALTHY: 0.05 }
const LOCKDOWN_DAYS := 3
const BLACKLIST_DAYS := 7

const SALE_OFFER := "shark_sale_offer"
const VISIT_SHARK: StringName = &"visit_shark"


static func is_dealer_locked_down(run: RunState, dealer_id: StringName) -> bool:
	return int(run.dealer_lockdowns.get(dealer_id, 0)) > run.day


static func is_dealer_blacklisted(run: RunState, dealer_id: StringName) -> bool:
	return int(run.dealer_loan_blacklist.get(dealer_id, 0)) > run.day


static func lock_down_dealer(run: RunState, dealer_id: StringName, days := LOCKDOWN_DAYS) -> void:
	run.dealer_lockdowns[dealer_id] = run.day + days


static func blacklist_dealer(run: RunState, dealer_id: StringName, days := BLACKLIST_DAYS) -> void:
	run.dealer_loan_blacklist[dealer_id] = run.day + days


static func can_buy_out(run: RunState) -> bool:
	if run.shark_bought or run.debt > 0 or Loan.is_with_vex(run):
		return false
	if run.shark_sale_day > 0 and run.day < run.shark_sale_day:
		return false
	return true


static func check_sale_offer(run: RunState) -> bool:
	if not can_buy_out(run) or run.shark_mail_sent or run.shark_sale_day == 0:
		return false
	if run.day < run.shark_sale_day or Encounters.has_pending(run):
		return false
	run.shark_mail_sent = true
	run.pending_encounter = {
		"type": SALE_OFFER,
		"speaker": String(Loan.LENDER),
		"title": "A message from The Shark",
		"body": "A week since your debt was settled. I told you I was getting old. My lending desk in Downtown is up for sale. %s takes the book, the office, and my services as muscle." % Format.money(BUYOUT_PRICE),
	}
	return true


static func buy_out(run: RunState) -> bool:
	if not can_buy_out(run) or not Loan.can_visit(run) or run.cash < BUYOUT_PRICE:
		return false
	run.cash -= BUYOUT_PRICE
	run.shark_bought = true
	Crew.join_free(run, ENFORCER_ROLE)
	run.errand_offers = run.errand_offers.filter(func(offer: Dictionary) -> bool: return not Errands.is_from_shark(offer))
	run.errands = run.errands.filter(func(errand: Dictionary) -> bool: return not Errands.is_from_shark(errand))
	return true


## Today's loan requests as { id, dealer, amount }. They come from the run seed, so a reload cannot reroll them.
static func requests(run: RunState) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	if not run.shark_bought:
		return list
	var dealers := _borrowers(run)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run.price_seed, &"lending", run.day])
	for _request in mini(REQUESTS_PER_DAY, dealers.size()):
		var dealer: DealerDef = dealers.pop_at(rng.randi_range(0, dealers.size() - 1))
		if not has_loan(run, dealer.id):
			list.append({ "id": "loan:%d:%s" % [run.day, dealer.id], "dealer": String(dealer.id), "amount": int(AMOUNTS[dealer.tier]) })
	return list


static func has_loan(run: RunState, dealer_id: StringName) -> bool:
	return run.dealer_loans.any(func(loan: Dictionary) -> bool: return StringName(str(loan.dealer)) == dealer_id)


static func repayment(dealer: DealerDef, amount: int) -> int:
	return roundi(amount * (1.0 + float(INTEREST[dealer.tier])))


static func outstanding(run: RunState) -> int:
	var total := 0
	for loan in run.dealer_loans:
		total += int(loan.amount)
	return total


static func lend(run: RunState, request_id: String) -> Result:
	if not run.shark_bought:
		return Result.NOT_OWNER
	if not Loan.can_visit(run):
		return Result.NOT_HERE
	var found := {}
	for request in requests(run):
		if str(request.id) == request_id:
			found = request
	if found.is_empty():
		return Result.GONE
	var amount := int(found.amount)
	if run.cash < amount:
		return Result.NOT_ENOUGH_CASH
	var dealer := Content.dealer(StringName(str(found.dealer)))
	run.cash -= amount
	run.dealer_loans.append({
		"dealer": String(dealer.id),
		"amount": amount,
		"repayment": repayment(dealer, amount),
		"due_day": run.day + TERM_DAYS,
	})
	return Result.OK


## Collects every loan that has come due. Returns a notice for each one.
static func settle(run: RunState) -> Array[Dictionary]:
	var notices: Array[Dictionary] = []
	for loan in run.dealer_loans.duplicate():
		if run.day < int(loan.due_day):
			continue
		run.dealer_loans.erase(loan)
		var dealer := Content.dealer(StringName(str(loan.dealer)))
		var amount := int(loan.amount)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([run.price_seed, &"loan_skip", dealer.id, int(loan.due_day)])
		if rng.randf() < float(SKIP_CHANCE[dealer.tier]):
			var recovered := roundi(amount * RECOVERED_SHARE)
			run.cash += recovered
			lock_down_dealer(run, dealer.id)
			blacklist_dealer(run, dealer.id)
			notices.append({
				"line": "%s skipped out on the %s loan. The Shark broke their door, seized %s, and shuttered their stall for %d days." % [
					dealer.display_name, Format.money(amount), Format.money(recovered), LOCKDOWN_DAYS
				],
				"hint": "-%s lost | Stall closed %dd | Barred from loans %dd" % [
					Format.money(amount - recovered), LOCKDOWN_DAYS, BLACKLIST_DAYS
				],
			})
		else:
			var paid := int(loan.repayment)
			run.cash += paid
			notices.append({
				"line": "%s paid back %s on the %s loan." % [dealer.display_name, Format.money(paid), Format.money(amount)],
				"hint": "+%s profit" % Format.money(paid - amount),
			})
	return notices


## Returns an empty dictionary when the dealer no longer exists.
static func sanitize(source: Dictionary) -> Dictionary:
	var dealer := Content.dealer(StringName(str(source.get("dealer", ""))))
	if dealer == null:
		return {}
	var amount := maxi(1, int(source.get("amount", 1)))
	return {
		"dealer": String(dealer.id),
		"amount": amount,
		"repayment": maxi(amount, int(source.get("repayment", amount))),
		"due_day": maxi(1, int(source.get("due_day", 1))),
	}


## Resident dealers in districts the player can reach, in a stable order.
static func _borrowers(run: RunState) -> Array[DealerDef]:
	var list: Array[DealerDef] = []
	for dealer in Content.dealers():
		var home := Content.district(dealer.district_id)
		if dealer.is_resident() and home != null and not Travel.is_locked(run, home):
			if not is_dealer_blacklisted(run, dealer.id):
				list.append(dealer)
	list.sort_custom(func(a: DealerDef, b: DealerDef) -> bool: return String(a.id) < String(b.id))
	return list
