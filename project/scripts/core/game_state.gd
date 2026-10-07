extends Node

signal run_started
signal run_loaded
signal run_changed
signal day_started(day: int)
signal run_ended(outcome: RunState.Outcome)

const SAVE_PATH := "user://run.json"

var run: RunState = null
## Gameplay screens switch this on so the real-time phase timer only runs while playing.
var clock_active := false
## Set when a new day begins; the district screen clears it after showing the day card.
var has_unseen_new_day := false
## Dealer the market screen opens with. Empty means the district's resident dealer.
var trading_with: StringName = &""

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


## Police character to district for next phase, empty when the player cannot pay.
func buy_police_tip() -> Dictionary:
	var patrols := Informant.buy_tip(run)
	if not patrols.is_empty():
		_commit(false)
	return patrols


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
	Encounters.after_time_passes(run, new_day_started, travelled, _rng, Content.events())
	_commit(new_day_started)


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
