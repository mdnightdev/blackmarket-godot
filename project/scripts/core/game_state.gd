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

var _store := SaveStore.new(SAVE_PATH)
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func _process(delta: float) -> void:
	if run == null or not clock_active or not Settings.real_time_phases:
		return
	if Encounters.has_pending(run) or Campaign.is_over(run):
		return
	run.phase_seconds_left -= delta
	if run.phase_seconds_left <= 0.0:
		advance_phase()


func has_saved_run() -> bool:
	return _store.exists()


func start_new_run(player_id := RunState.DEFAULT_PLAYER) -> void:
	run = RunState.new()
	run.player_id = player_id
	has_unseen_new_day = true
	save_run()
	run_started.emit()


func load_saved_run() -> bool:
	var data := _store.read()
	if data.is_empty():
		return false
	run = RunState.from_dict(data)
	if Content.district(run.district_id) == null:
		run.district_id = RunState.STARTING_DISTRICT
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
	_pass_time(Calendar.advance_phase(run), false)


func travel_to(destination: DistrictDef) -> Travel.Check:
	var result := Travel.check(run, destination)
	if result == Travel.Check.OK:
		_pass_time(Travel.travel(run, destination), true)
	return result


func buy(item: ItemDef, quantity: int, unit_price: int) -> Trade.Result:
	return _commit_trade(Trade.buy(run, item, quantity, unit_price), item, quantity)


func sell(item: ItemDef, quantity: int, unit_price: int) -> Trade.Result:
	return _commit_trade(Trade.sell(run, item, quantity, unit_price), item, quantity)


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
	Campaign.update_outcome(run)
	_commit(false)
	return true


func borrow(amount: int) -> bool:
	if not Loan.borrow(run, amount):
		return false
	_commit(false)
	return true


func continue_endless() -> void:
	Campaign.continue_endless(run)
	_commit(false)


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
	_commit(false)
	return true


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
	_commit(false)
	return true


## Returns the rumour, or an empty dictionary when nothing was sold.
func buy_rumor(venue_id: StringName) -> Dictionary:
	var rumor := Rumors.buy(run, venue_id)
	if not rumor.is_empty():
		_commit(false)
	return rumor


func accept_crate(offer: Dictionary) -> Smuggling.Result:
	var result := Smuggling.accept(run, offer)
	if result == Smuggling.Result.OK:
		_commit(false)
	return result


## Returns the pay, 0 when the crate cannot be delivered here.
func deliver_crate() -> int:
	var pay := Smuggling.deliver(run)
	if pay > 0:
		_commit(false)
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


func collect_winnings(amount: int) -> void:
	if amount <= 0:
		return
	Casino.pay_out(run, amount)
	_commit(false)


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


func _pass_time(new_day_started: bool, travelled: bool) -> void:
	var missed := Orders.expire(run)
	var missed_favours := Favours.expire(run)
	var lost_crate := Smuggling.expire(run)
	Encounters.after_time_passes(run, new_day_started, travelled, _rng, Content.events())
	_commit(new_day_started)
	if not missed.is_empty():
		orders_missed.emit(missed)
	if not missed_favours.is_empty():
		favours_missed.emit(missed_favours)
	if not lost_crate.is_empty():
		crate_lost.emit(lost_crate)


func _commit(new_day_started: bool) -> void:
	if new_day_started:
		has_unseen_new_day = true
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
