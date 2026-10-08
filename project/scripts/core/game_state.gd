extends Node

signal run_started
signal run_loaded
signal run_changed
signal day_started(day: int)
signal run_ended(outcome: RunState.Outcome)
## Bar orders whose deadline passed during the last move of time.
signal orders_missed(orders: Array[Dictionary])
## A smuggling crate whose deadline passed during the last move of time.
signal crate_lost(crate: Dictionary)
## Family deliveries whose deadline passed during the last move of time.
signal favours_missed(favours: Array[Dictionary])
## Short reports for the player: { line, hint }. Finished tasks, crew walking out, raided businesses.
signal notices_posted(notices: Array[Dictionary])
## New errand offers landed on the player's phone.
signal offers_posted(offers: Array[Dictionary])
## New customer orders landed on the player's phone. See Customers for the entry layout.
signal customer_offers_posted(offers: Array[Dictionary])

const SAVE_PATH := "user://run.json"

var run: RunState = null
## Gameplay screens switch this on so the real-time phase timer only runs while playing.
var clock_active := false
## Set when a new day begins; the district screen clears it after showing the day card.
var has_unseen_new_day := false
## Dealer the market screen opens with. Empty means the district's resident dealer.
var trading_with: StringName = &""
## Venue the bar screen opens for.
var visiting_venue: StringName = &""
## District the map screen starts a trip to as soon as it opens. Empty means the player picks one.
var travelling_to: StringName = &""

var _store := SaveStore.new(SAVE_PATH)
var _rng := RandomNumberGenerator.new()
## Jobs active at the last commit, so the journal can log the ones that closed since.
var _active_jobs: Array[Dictionary] = []


func _ready() -> void:
	_rng.randomize()


func _process(delta: float) -> void:
	if run == null or not clock_active:
		return
	if Encounters.has_pending(run) or Campaign.is_over(run):
		return
	if Police.serve_time(run, delta):
		_commit(false)
	run.phase_seconds_left -= delta
	if run.phase_seconds_left <= 0.0:
		advance_phase()


func has_saved_run() -> bool:
	return _store.exists()


func start_new_run(player_id := RunState.DEFAULT_PLAYER) -> void:
	run = RunState.new()
	run.player_id = player_id
	DailyTasks.deal(run)
	var offers := Errands.post(run)
	var customer_offers := CustomerOffers.post(run)
	_active_jobs = Jobs.deadlines(run)
	has_unseen_new_day = true
	save_run()
	run_started.emit()
	if not offers.is_empty():
		offers_posted.emit(offers)
	if not customer_offers.is_empty():
		customer_offers_posted.emit(customer_offers)


func load_saved_run() -> bool:
	var data := _store.read()
	if data.is_empty():
		return false
	run = RunState.from_dict(data)
	if Content.district(run.district_id) == null:
		run.district_id = RunState.STARTING_DISTRICT
	DailyTasks.deal(run)
	_active_jobs = Jobs.deadlines(run)
	run_loaded.emit()
	return true


func current_district() -> DistrictDef:
	return Content.district(run.district_id)


func delete_run() -> void:
	run = null
	_store.delete()


func advance_phase() -> void:
	if run == null or Encounters.has_pending(run) or Campaign.is_over(run):
		return
	var finished := _close_day_if_night()
	_pass_time(Calendar.advance_phase(run), false, finished)


func travel_to(destination: DistrictDef, walking := false) -> Travel.Check:
	var result := Travel.check(run, destination, walking)
	if result != Travel.Check.OK:
		return result
	var overrun := Travel.travel(run, destination, walking)
	Smuggling.record_stop(run)
	if run.phase_seconds_left > 0.0:
		_arrive()
		return result
	var finished := _close_day_if_night()
	var new_day_started := Calendar.advance_phase(run)
	run.phase_seconds_left -= overrun
	_pass_time(new_day_started, true, finished)
	return result


func buy(item: ItemDef, quantity: int, unit_price: int) -> Trade.Result:
	return _commit_trade(Trade.buy(run, item, quantity, unit_price), item, quantity)


func sell(item: ItemDef, quantity: int, unit_price: int) -> Trade.Result:
	var result := _commit_trade(Trade.sell(run, item, quantity, unit_price), item, quantity)
	if result == Trade.Result.OK:
		_report_tasks(DailyTasks.record_sale(run, run.district_id, quantity * unit_price))
	return result


func buy_gear(item: ItemDef) -> Trade.Result:
	return _commit_trade(Trade.buy_gear(run, item))


## Returns the outcome text to show the player, empty when the card can simply close.
func resolve_encounter(choice: StringName) -> String:
	var outcome := Encounters.resolve(run, choice, _rng.randf())
	Encounters.check_raid(run)
	_commit(false)
	return outcome


func repay_debt(amount: int) -> bool:
	if not Loan.repay(run, amount):
		return false
	Campaign.start_career_if_cleared(run)
	_commit(false)
	return true


func buy_out_shark() -> bool:
	if not Lending.buy_out(run):
		return false
	_commit(false)
	return true


func lend_to_dealer(request_id: String) -> Lending.Result:
	var result := Lending.lend(run, request_id)
	if result == Lending.Result.OK:
		_commit(false)
	return result


func borrow(amount: int) -> bool:
	if not Loan.borrow(run, amount):
		return false
	_commit(false)
	return true


func move_to_stash(item: ItemDef, quantity: int) -> bool:
	var moved := Inventory.move_to_stash(run, item, quantity)
	if moved:
		_commit(false)
	return moved


func take_from_stash(item: ItemDef, quantity: int) -> bool:
	var moved := Inventory.take_from_stash(run, item, quantity)
	if moved:
		_commit(false)
	return moved


func buy_stash_upgrade() -> bool:
	if not Safehouse.buy_upgrade(run):
		return false
	_commit(false)
	return true


func deposit_cash(amount: int) -> bool:
	if not Safehouse.deposit_cash(run, amount):
		return false
	_commit(false)
	return true


func withdraw_cash(amount: int) -> bool:
	if not Safehouse.withdraw_cash(run, amount):
		return false
	_commit(false)
	return true


## Spends the next phase at the safehouse. Normal time passes, with extra cooling.
func lie_low() -> bool:
	if Encounters.has_pending(run) or Campaign.is_over(run) or not Safehouse.lie_low(run):
		return false
	advance_phase()
	return true


## Returns the heat removed, 0 when the Fixer would not do it.
func clean_up_heat() -> int:
	var removed := Fixer.clean_up(run)
	if removed > 0:
		_commit(false)
	return removed


## Returns the dealers whose prices were recorded, empty when the player cannot pay.
func buy_price_hack(district_id: StringName) -> Array[DealerDef]:
	var dealers := Hacker.hack(run, district_id)
	if not dealers.is_empty():
		_commit(false)
	return dealers


## Police character to district for next phase, empty when the player cannot pay.
func buy_police_tip() -> Dictionary:
	var patrols := Informant.buy_tip(run)
	if not patrols.is_empty():
		_commit(false)
	return patrols


func accept_order(offer: Dictionary) -> Orders.Result:
	var result := Orders.accept(run, offer)
	if result == Orders.Result.OK:
		_commit(false)
	return result


func deliver_order(order: Dictionary) -> bool:
	var item := Content.item(StringName(order.item))
	if not Orders.deliver(run, order):
		return false
	Heat.add(run, Heat.for_trade(run, item, int(order.quantity)))
	Encounters.check_raid(run)
	var finished := DailyTasks.record_delivery(run)
	_commit(false)
	_report_tasks(finished)
	return true


## Returns the pay, 0 when the runner could not take the job.
func send_runner(job: Dictionary) -> int:
	var pay := Crew.send_runner(run, job)
	if pay <= 0:
		return 0
	var finished := DailyTasks.record_delivery(run)
	_commit(false)
	_report_tasks(finished)
	return pay


func drop_order(order: Dictionary) -> void:
	Orders.drop(run, order)
	_commit(false)


func accept_favour(offer: Dictionary) -> Favours.Result:
	var result := Favours.accept(run, offer)
	if result == Favours.Result.OK:
		_commit(false)
	return result


func deliver_favour(favour: Dictionary) -> bool:
	var item := Content.item(StringName(favour.item))
	if not Favours.deliver(run, favour):
		return false
	Heat.add(run, Heat.for_trade(run, item, int(favour.quantity)))
	Encounters.check_raid(run)
	var finished := DailyTasks.record_delivery(run)
	_commit(false)
	_report_tasks(finished)
	return true


## Returns the rumour, or an empty dictionary when nothing was sold.
func buy_rumor(venue_id: StringName) -> Dictionary:
	var rumor := Rumors.buy(run, venue_id)
	if not rumor.is_empty():
		_commit(false)
	return rumor


func accept_crate(offer: Dictionary, route: Array[StringName] = [], invoice := false) -> Smuggling.Result:
	var result := Smuggling.accept(run, offer, route, invoice)
	if result == Smuggling.Result.OK:
		_commit(false)
	return result


## Takes an errand off the phone. Starting it where the player already stands picks up or meets the debtor now.
func accept_offer(id: String) -> bool:
	if not Errands.accept(run, id):
		return false
	var notices := Errands.visit(run)
	_commit(false)
	if not notices.is_empty():
		notices_posted.emit(notices)
	return true


func decline_offer(id: String) -> void:
	if Errands.decline(run, id):
		_commit(false)


func accept_ping(id: String) -> JobPings.Result:
	var result := JobPings.accept(run, id)
	if result == JobPings.Result.OK:
		_commit(false)
	return result


func decline_ping(id: String) -> void:
	if JobPings.decline(run, id):
		_commit(false)


## Takes a customer order off the phone. Accepting where the customer waits with the goods in the bag queues the handover.
func accept_customer_offer(id: String) -> bool:
	if not Customers.accept(run, id):
		return false
	Customers.visit(run)
	_commit(false)
	return true


func decline_customer_offer(id: String) -> void:
	if Customers.decline(run, id):
		_commit(false)


## Queues the handover card for an order that can be handed over where the player stands.
func queue_handover(id: String) -> bool:
	var order := Customers.find(run, id)
	if order.is_empty() or Encounters.has_pending(run) or not Customers.can_hand_over(run, order):
		return false
	run.pending_encounter = CustomerHandover.start(run, order)
	_commit(false)
	return true


## Returns the Customers.hand_over result, empty when the handover cannot happen now. An undercover buyer leaves a
## police stop pending. A haggler's counter offer waits for answer_haggle.
func hand_over_customer_order(id: String) -> Dictionary:
	var order := Customers.find(run, id)
	if order.is_empty():
		return {}
	CustomerHandover.dismiss(run, id)
	if Encounters.has_pending(run):
		return {}
	return _finish_handover(Customers.hand_over(run, order, _rng.randf()))


## Takes the haggler's lower price, or holds firm when accept is false. Returns the same layout as hand_over_customer_order.
func answer_haggle(id: String, accept: bool) -> Dictionary:
	var order := Customers.find(run, id)
	if order.is_empty():
		return {}
	CustomerHandover.dismiss(run, id)
	if Encounters.has_pending(run):
		return {}
	return _finish_handover(Customers.answer_haggle(run, order, accept, _rng.randf()))


func _finish_handover(result: Dictionary) -> Dictionary:
	if result.is_empty():
		return result
	Encounters.check_raid(run)
	_commit(false)
	var finished: Array[Dictionary] = []
	finished.assign(result.get("tasks", []))
	_report_tasks(finished)
	return result


func buy_recon() -> bool:
	if not Routes.buy_recon(run):
		return false
	_commit(false)
	return true


## Returns the pay, 0 when the crate cannot be delivered here.
func deliver_crate() -> int:
	return _finish_crate(Smuggling.deliver(run))


## Returns the pay, 0 when the buyer cannot meet here.
func meet_crate_buyer() -> int:
	return _finish_crate(Smuggling.meet_halfway(run))


func _finish_crate(pay: int) -> int:
	if pay > 0:
		var finished := DailyTasks.record_delivery(run)
		_commit(false)
		_report_tasks(finished)
	return pay


## Returns the units taken, 0 when the job failed or could not start.
func hijack(shipment: Dictionary, approach: Hijacks.Approach) -> int:
	if not Hijacks.can_attempt(run, shipment):
		return 0
	var taken := Hijacks.attempt(run, shipment, approach, _rng.randf())
	Encounters.check_raid(run)
	_commit(false)
	return taken


func send_muscle() -> bool:
	if not Turf.send_muscle(run):
		return false
	Encounters.check_raid(run)
	_commit(false)
	return true


func place_bet(casino: CasinoDef, amount: int) -> bool:
	if not Casino.place_bet(run, casino, amount):
		return false
	_commit(false)
	return true


func collect_winnings(amount: int, stake: int) -> void:
	if amount <= 0:
		return
	Casino.pay_out(run, amount)
	var finished: Array[Dictionary] = []
	if amount > stake:
		finished = DailyTasks.record_casino_win(run)
	_commit(false)
	_report_tasks(finished)


func level_up_turf(district_id: StringName) -> Turf.LevelResult:
	var result := Turf.level_up(run, district_id)
	if result == Turf.LevelResult.OK:
		_commit(false)
	return result


func learn_skill(skill_id: StringName) -> Skills.Result:
	var result := Skills.upgrade(run, skill_id)
	if result == Skills.Result.OK:
		_commit(false)
	return result


func respec_skills() -> Skills.Result:
	var result := Skills.respec(run)
	if result == Skills.Result.OK:
		_commit(false)
	return result


func hire_crew(role_id: StringName) -> Crew.Result:
	var result := Crew.hire(run, role_id)
	if result == Crew.Result.OK:
		_commit(false)
	return result


func fire_crew(role_id: StringName) -> Crew.Result:
	var result := Crew.fire(run, role_id)
	if result == Crew.Result.OK:
		_commit(false)
	return result


func buy_business(business: BusinessDef, district_id: StringName) -> Businesses.Result:
	var result := Businesses.buy(run, business, district_id)
	if result == Businesses.Result.OK:
		_commit(false)
	return result


## Fills the shelves from the bag, most valuable goods first. Returns the units moved.
func stock_business(entry: Dictionary) -> int:
	if run.district_id != Businesses.district_of(entry):
		return 0
	var moved := 0
	for item in _carried_by_value():
		var units := Businesses.max_load(run, entry, item)
		if units > 0 and Businesses.load_stock(run, entry, item, units) == Businesses.Result.OK:
			moved += units
	if moved > 0:
		_commit(false)
	return moved


## Packs the shelves back into the bag, most valuable goods first. Returns the units moved.
func unstock_business(entry: Dictionary) -> int:
	if run.district_id != Businesses.district_of(entry):
		return 0
	var moved := 0
	var items: Array[ItemDef] = []
	for item_id: String in entry.get("stock", {}):
		var item := Content.item(StringName(item_id))
		if item != null:
			items.append(item)
	items.sort_custom(_by_value)
	for item in items:
		var units := Businesses.max_unload(run, entry, item)
		if units > 0 and Businesses.unload_stock(run, entry, item, units) == Businesses.Result.OK:
			moved += units
	if moved > 0:
		_commit(false)
	return moved


## Returns { success, payout, lost_role }. Nothing happens when Heists.check() does not pass.
func pull_heist(heist: HeistDef) -> Dictionary:
	if Heists.check(run, heist) != Heists.Result.OK:
		return {}
	var outcome := Heists.attempt(run, heist, _rng.randf(), _rng.randf())
	Encounters.check_raid(run)
	_commit(false)
	return outcome


## Shared by the casino tables. Unseeded on purpose: bets are paid before the result, so reloading cannot fish for a win.
func casino_rng() -> RandomNumberGenerator:
	return _rng


## Saves without emitting run_changed, so screens can call it while refreshing.
func remember_prices(dealer: DealerDef) -> void:
	if PriceIntel.record(run, dealer, Content.items(ItemDef.Kind.TRADE_GOOD)):
		save_run()


func dealer_walked_out(dealer: DealerDef) -> void:
	run.walked_out[dealer.id] = Calendar.stamp(run)
	_commit(false)


func save_run() -> void:
	if run == null:
		return
	var error := _store.write(run.to_dict())
	if error != OK:
		push_error("Run save failed: %s" % error_string(error))


func _commit_trade(result: Trade.Result, goods: ItemDef = null, quantity := 0) -> Trade.Result:
	if result != Trade.Result.OK:
		return result
	if goods != null:
		Heat.add(run, Heat.for_trade(run, goods, quantity))
		Encounters.check_raid(run)
	_commit(false)
	return result


## A trip that ended inside the current phase: no time effects, only what can happen on arrival.
func _arrive() -> void:
	Encounters.after_arrival(run, _rng)
	var notices := Errands.visit(run)
	Customers.visit(run)
	notices.append_array(_task_notices(DailyTasks.record_arrival(run, run.district_id)))
	_commit(false)
	if not notices.is_empty():
		notices_posted.emit(notices)


func _pass_time(new_day_started: bool, travelled: bool, finished_tasks: Array[Dictionary] = []) -> void:
	var missed := Orders.expire(run)
	var missed_favours := Favours.expire(run)
	var lost_crate := Smuggling.expire(run)
	var notices := _task_notices(finished_tasks)
	notices.append_array(Errands.expire(run))
	notices.append_array(Customers.expire(run))
	JobPings.expire(run)
	Encounters.after_time_passes(run, new_day_started, travelled, _rng, Content.events())
	if new_day_started and not Campaign.is_over(run):
		notices.append_array(_start_morning())
	Businesses.sell_phase(run)
	if not Campaign.is_over(run) and not Police.is_jailed(run):
		notices.append_array(Errands.visit(run))
		if travelled:
			Customers.visit(run)
	var offers := Errands.post(run)
	offers.append_array(JobPings.post(run))
	var customer_offers := CustomerOffers.post(run)
	if travelled:
		finished_tasks = DailyTasks.record_arrival(run, run.district_id)
		notices.append_array(_task_notices(finished_tasks))
	notices.append_array(_deadline_notices())
	_commit(new_day_started)
	if not notices.is_empty():
		notices_posted.emit(notices)
	if not offers.is_empty():
		offers_posted.emit(offers)
	if not customer_offers.is_empty():
		customer_offers_posted.emit(customer_offers)
	if not missed.is_empty():
		orders_missed.emit(missed)
	if not missed_favours.is_empty():
		favours_missed.emit(missed_favours)
	if not lost_crate.is_empty():
		crate_lost.emit(lost_crate)


## Settles the night-only task while the finished day is still current. Returns the tasks it completed.
func _close_day_if_night() -> Array[Dictionary]:
	if run.phase != RunState.Phase.NIGHT:
		var none: Array[Dictionary] = []
		return none
	return DailyTasks.close_day(run)


func _start_morning() -> Array[Dictionary]:
	var notices: Array[Dictionary] = []
	DailyTasks.deal(run)
	var report := Crew.report_line(run)
	run.crew_report.clear()
	if not report.is_empty():
		notices.append({ "line": report, "hint": "Crew wages: %s a day." % Format.money(Crew.daily_wages(run)) })
	for invoice in Invoices.settle(run):
		var amount := Format.money(int(invoice.amount))
		if bool(invoice.paid):
			notices.append({ "line": "%s paid the %s invoice." % [invoice.client, amount], "hint": "+%s cash" % amount })
		else:
			notices.append({ "line": "%s never paid the %s invoice. That money is gone." % [invoice.client, amount], "hint": "Higher street cred makes buyers less likely to skip out." })
	notices.append_array(Lending.settle(run))
	for role in Crew.pay_wages(run):
		notices.append({
			"line": "Your %s walked out after two days without pay." % role.display_name.to_lower(),
			"hint": "%+d cred" % StreetCred.CREW_WALKED,
		})
	var rolls: Array[float] = []
	for entry in run.businesses:
		rolls.append(_rng.randf())
	for business_name: String in Businesses.morning(run, rolls).raided:
		notices.append({
			"line": "The police raided your %s overnight and took the stock." % business_name.to_lower(),
			"hint": "It stays shut until tomorrow.",
		})
	return notices


func _deadline_notices() -> Array[Dictionary]:
	var notices: Array[Dictionary] = []
	for job in Jobs.in_last_phase(run):
		var place := " in %s" % job.place if not str(job.place).is_empty() else ""
		notices.append({
			"line": "Last phase to deliver %s%s." % [job.title, place],
			"hint": "Due by the end of %s." % Calendar.describe(int(job.due)).to_lower(),
		})
	return notices


func _task_notices(tasks: Array[Dictionary]) -> Array[Dictionary]:
	var notices: Array[Dictionary] = []
	for task in tasks:
		notices.append({
			"line": "Task done: %s." % DailyTasks.describe(task),
			"hint": "+%s and %+d cred" % [Format.money(DailyTasks.reward(run)), StreetCred.TASK_DONE],
		})
	return notices


func _report_tasks(tasks: Array[Dictionary]) -> void:
	var notices := _task_notices(tasks)
	if notices.is_empty():
		return
	save_run()
	run_changed.emit()
	notices_posted.emit(notices)


func _carried_by_value() -> Array[ItemDef]:
	var items: Array[ItemDef] = []
	for item_id: StringName in run.inventory:
		var item := Content.item(item_id)
		if item != null and item.kind == ItemDef.Kind.TRADE_GOOD:
			items.append(item)
	items.sort_custom(_by_value)
	return items


func _by_value(a: ItemDef, b: ItemDef) -> bool:
	if a.base_price != b.base_price:
		return a.base_price > b.base_price
	return String(a.id) < String(b.id)


func _commit(new_day_started: bool) -> void:
	if new_day_started:
		has_unseen_new_day = true
	Journal.record_finished(run, _active_jobs)
	_active_jobs = Jobs.deadlines(run)
	save_run()
	run_changed.emit()
	if Campaign.is_over(run):
		run_ended.emit(run.outcome)
		return
	if new_day_started:
		day_started.emit(run.day)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST:
			save_run()
