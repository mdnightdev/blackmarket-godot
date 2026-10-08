extends CanvasLayer

const DIALOGUE_PANEL := preload("res://ui/components/dialogue_panel.tscn")
const LOAN_SHEET := preload("res://ui/components/loan_sheet.tscn")
const INVENTORY_SHEET := preload("res://ui/components/inventory_sheet.tscn")
const TURF_SHEET := preload("res://ui/components/turf_sheet.tscn")
const JOBS_SHEET := preload("res://ui/components/jobs_sheet.tscn")
const JAIL_CARD := preload("res://ui/components/jail_card.tscn")
const OFFER_BANNER := preload("res://ui/components/offer_banner.tscn")
const QUOTE_SHEET := preload("res://ui/components/quote_sheet.tscn")
const RAID_BACKDROP: Texture2D = preload("res://assets/scenes/raid.jpg")
## Lets a new screen settle before an encounter slides over it.
const SETTLE_SECONDS := 0.5
const POLICE_LIGHTS := 0.55
const RAID_LIGHTS := 0.85
const POLICE_SHAKE_PIXELS := 9.0
const RAID_SHAKE_PIXELS := 22.0
const HIT_SHAKE_PIXELS := 12.0
const SHAKE_DECAY_PER_SECOND := 40.0
const POLICE_VIBRATE_MS := 150
const RAID_VIBRATE_MS := 350

var _dialogue: DialoguePanel
var _loan_sheet: LoanSheet
var _inventory_sheet: InventorySheet
var _turf_sheet: TurfSheet
var _jobs_sheet: JobsSheet
var _quote_sheet: QuoteSheet
var _jail_card: JailCard
var _banner: OfferBanner
var _lights: PoliceLights
var _settled_for := 0.0
var _shake_pixels := 0.0
## Shown one at a time after any pending encounter. Kept in memory only, since missing an order is already saved.
var _missed_orders: Array[Dictionary] = []
var _missed_favours: Array[Dictionary] = []
var _lost_crates: Array[Dictionary] = []
var _notices: Array[Dictionary] = []
## Ids of new phone offers, errands and customer orders, still waiting for their banner, oldest first.
## Answered or expired ones are skipped.
var _offers: Array[String] = []
## Customer orders whose goods just came together, waiting to ask about the trip to the customer.
var _filled_orders: Array[String] = []
var _stocked_orders := StockedOrders.new()


func _ready() -> void:
	layer = 50
	_dialogue = DIALOGUE_PANEL.instantiate()
	_loan_sheet = LOAN_SHEET.instantiate()
	_inventory_sheet = INVENTORY_SHEET.instantiate()
	_turf_sheet = TURF_SHEET.instantiate()
	_jobs_sheet = JOBS_SHEET.instantiate()
	_quote_sheet = QUOTE_SHEET.instantiate()
	_jail_card = JAIL_CARD.instantiate()
	_banner = OFFER_BANNER.instantiate()
	_lights = PoliceLights.new()
	add_child(_inventory_sheet)
	add_child(_turf_sheet)
	add_child(_jobs_sheet)
	add_child(_quote_sheet)
	add_child(_loan_sheet)
	add_child(_jail_card)
	add_child(_banner)
	add_child(_dialogue)
	_jail_card.visibility_changed.connect(_close_sheets_when_jailed)
	_banner.opened.connect(_open_offer)
	_dialogue.add_backdrop_layer(_lights)
	for sheet in _sheets():
		SceneRouter.transition_started.connect(sheet.close)
	GameState.orders_missed.connect(func(orders: Array[Dictionary]) -> void: _missed_orders.append_array(orders))
	GameState.favours_missed.connect(func(favours: Array[Dictionary]) -> void: _missed_favours.append_array(favours))
	GameState.crate_lost.connect(func(crate: Dictionary) -> void: _lost_crates.append(crate))
	GameState.notices_posted.connect(func(notices: Array[Dictionary]) -> void: _notices.append_array(notices))
	GameState.offers_posted.connect(_queue_offers)
	GameState.customer_offers_posted.connect(_queue_offers)
	GameState.run_changed.connect(_on_run_changed)
	GameState.run_loaded.connect(_forget_filled_orders)
	GameState.run_started.connect(func() -> void:
		_missed_orders.clear()
		_missed_favours.clear()
		_lost_crates.clear()
		_notices.clear()
		_offers.clear()
		_forget_filled_orders()
		_banner.retract()
	)


## Screens opt in by defining can_present_encounter(), so encounters never interrupt animations or other modals.
func _process(delta: float) -> void:
	_update_shake(delta)
	if _lights.is_on() and not _dialogue.visible:
		_stand_down()
	if _banner.is_showing() and not _screen_is_free():
		_offers.push_front(_banner.offer_id)
		_banner.retract()
	if not _can_present():
		_settled_for = 0.0
		return
	_settled_for += delta
	if _settled_for >= SETTLE_SECONDS:
		_settled_for = 0.0
		if Encounters.has_pending(GameState.run):
			_present_encounter(GameState.run.pending_encounter)
		elif not _missed_orders.is_empty():
			_present_missed_order(_missed_orders.pop_front())
		elif not _missed_favours.is_empty():
			_present_missed_favour(_missed_favours.pop_front())
		elif not _lost_crates.is_empty():
			_present_lost_crate(_lost_crates.pop_front())
		elif not _notices.is_empty():
			_present_notice(_notices.pop_front())
		elif not _filled_orders.is_empty():
			CustomerTalk.announce_stocked(_filled_orders.pop_front())
		else:
			_show_next_offer()


func open_loan(mode := LoanSheet.Mode.REPAY) -> void:
	_loan_sheet.open_loan(mode)


func open_bag() -> void:
	_jobs_sheet.close()
	_turf_sheet.close()
	_quote_sheet.close()
	if not _inventory_sheet.visible:
		_inventory_sheet.open_inventory()


func open_turf() -> void:
	_inventory_sheet.close()
	_jobs_sheet.close()
	_quote_sheet.close()
	_turf_sheet.open_turf()


func open_jobs() -> void:
	_inventory_sheet.close()
	_turf_sheet.close()
	_quote_sheet.close()
	if not _jobs_sheet.visible:
		_jobs_sheet.open_jobs()


## Where to buy the goods for an accepted customer order.
func open_quotes(order_id: String) -> void:
	_inventory_sheet.close()
	_turf_sheet.close()
	_jobs_sheet.close()
	_quote_sheet.open_quotes(order_id)


## Opens a conversation that is not an encounter. See DialoguePanel.open for the callback contract.
func talk(speaker: SpeakerDef, line: String, choices: Array[DialogueChoice], on_choice: Callable, hint := "") -> void:
	_dialogue.open(speaker, line, choices, on_choice, hint)


func say(line: String, choices: Array[DialogueChoice], on_choice: Callable, talking := true, hint := "") -> void:
	_dialogue.say(line, choices, on_choice, talking, hint)


func end_talk() -> void:
	_dialogue.close()


func open_tutorial() -> void:
	var run := GameState.run
	var page := Tutorial.page(run)
	talk(Content.speaker(Tutorial.SPEAKER), page.line, Tutorial.choices(run), _on_tutorial_choice, page.hint)


func _on_tutorial_choice(choice: StringName) -> void:
	var run := GameState.run
	if choice == Tutorial.SKIP:
		Tutorial.finish(run)
	else:
		Tutorial.advance(run)
	GameState.save_run()
	if not Tutorial.should_show(run):
		end_talk()
		return
	var page := Tutorial.page(run)
	say(page.line, Tutorial.choices(run), _on_tutorial_choice, true, page.hint)


func is_talking() -> bool:
	return _dialogue.visible


func handle_back() -> bool:
	if _dialogue.visible:
		return _dialogue.handle_back()
	if _jail_card.visible:
		return true
	if _turf_sheet.visible and _turf_sheet.close_modal():
		return true
	if _jobs_sheet.visible and _jobs_sheet.close_modal():
		return true
	if _inventory_sheet.visible and _inventory_sheet.close_modal():
		return true
	for sheet in _sheets():
		if sheet.visible:
			sheet.close()
			return true
	return false


func _sheets() -> Array[BottomSheet]:
	var sheets: Array[BottomSheet] = [_quote_sheet, _loan_sheet, _inventory_sheet, _turf_sheet, _jobs_sheet]
	return sheets


func _close_sheets_when_jailed() -> void:
	if not _jail_card.visible:
		return
	for sheet in _sheets():
		sheet.close()


## Offer banners wait behind every card and never stack, so one shows at a time once the cards are done.
func _can_present() -> bool:
	if GameState.run == null:
		return false
	if not _has_cards() and (_banner.is_showing() or _offers.is_empty()):
		return false
	return _screen_is_free()


func _has_cards() -> bool:
	if Encounters.has_pending(GameState.run) or not _filled_orders.is_empty():
		return true
	return not (_missed_orders.is_empty() and _missed_favours.is_empty() and _lost_crates.is_empty() and _notices.is_empty())


func _screen_is_free() -> bool:
	if GameState.run == null or _dialogue.visible or SceneRouter.is_transitioning():
		return false
	if _sheets().any(func(sheet: BottomSheet) -> bool: return sheet.visible):
		return false
	var screen := get_tree().current_scene
	return screen != null and screen.has_method("can_present_encounter") and screen.can_present_encounter()


func _queue_offers(offers: Array[Dictionary]) -> void:
	for offer in offers:
		_offers.append(str(offer.id))


func _show_next_offer() -> void:
	var run := GameState.run
	while not _offers.is_empty():
		var offer_id: String = _offers.pop_front()
		var errand := Errands.find_offer(run, offer_id)
		var sender := Content.character(StringName(str(errand.get("sender", Errands.SENDER))))
		if not errand.is_empty() and sender != null:
			_banner.show_offer(offer_id, sender.portrait, sender.display_name, Errands.describe(errand), Format.money(int(errand.pay)))
			return
		var order := Customers.find_offer(run, offer_id)
		if not order.is_empty():
			_banner.show_offer(offer_id, CustomerTalk.PORTRAIT, Customers.customer_name(order), Customers.headline(order), "", Customers.district_name(order).to_upper())
			return


func _open_offer(offer_id: String) -> void:
	if Customers.find_offer(GameState.run, offer_id).is_empty():
		OfferTalk.open(offer_id)
	else:
		CustomerTalk.open(offer_id)


func _on_run_changed() -> void:
	var run := GameState.run
	if _banner.is_showing() and Errands.find_offer(run, _banner.offer_id).is_empty() and Customers.find_offer(run, _banner.offer_id).is_empty():
		_banner.retract()
	_filled_orders.append_array(_stocked_orders.check(run))


func _forget_filled_orders() -> void:
	_filled_orders.clear()
	_stocked_orders.clear()


func _present_encounter(encounter: Dictionary) -> void:
	var speaker := Content.speaker(StringName(str(encounter.get("speaker", ""))))
	if speaker == null:
		speaker = Content.player(GameState.run.player_id)
	var choices: Array[DialogueChoice] = []
	for choice in Encounters.choices(GameState.run, encounter):
		choices.append(DialogueChoice.new(choice.id, choice.label, choice.enabled))
	var type := str(encounter.get("type", ""))
	var backdrop := RAID_BACKDROP if type == Encounters.RAID else null
	_dialogue.open(speaker, str(encounter.get("body", "")), choices, _resolve_encounter, "", backdrop)
	_raise_alarm(type)


func _present_missed_order(order: Dictionary) -> void:
	var dealer := Content.dealer(StringName(order.dealer))
	var item := Content.item(StringName(order.item))
	if dealer == null or item == null:
		return
	var line := "You were meant to bring me %d %s. Come back when you can keep a promise." % [int(order.quantity), item.display_name]
	var hint := "Order missed. %s will not trade with you this phase." % dealer.display_name
	var choices: Array[DialogueChoice] = [DialogueChoice.new(Encounters.CONTINUE, "Continue", true, true)]
	_dialogue.open(dealer, line, choices, func(_id: StringName) -> void: _dialogue.close(), hint)
	AudioService.play_sfx(Sfx.HAGGLE_FAIL)


func _present_missed_favour(favour: Dictionary) -> void:
	var family := Content.family(StringName(favour.family))
	var lieutenant := Content.character(family.lieutenant) if family != null else null
	var item := Content.item(StringName(favour.item))
	if lieutenant == null or item == null:
		return
	var line := "The family waited for %d %s. Nobody keeps the %s waiting." % [int(favour.quantity), item.display_name, family.english_name]
	var hint := "Favour missed. Standing with the %s is now %s." % [family.english_name, Families.tier_name(Families.tier(GameState.run, family.id))]
	var choices: Array[DialogueChoice] = [DialogueChoice.new(Encounters.CONTINUE, "Continue", true, true)]
	_dialogue.open(lieutenant, line, choices, func(_id: StringName) -> void: _dialogue.close(), hint)
	AudioService.play_sfx(Sfx.HAGGLE_FAIL)


func _present_lost_crate(crate: Dictionary) -> void:
	var pier := Content.venue(Smuggling.VENUE)
	var voronin := Content.character(pier.host) if pier != null else null
	if voronin == null:
		return
	var destination := Smuggling.destination(crate)
	var place := destination.display_name if destination != null else "the drop"
	var line := "My crate never reached %s. I do not pay for late, and I do not forget." % place
	var hint := "Crate lost. Voronin has no work for you for the rest of the day."
	var choices: Array[DialogueChoice] = [DialogueChoice.new(Encounters.CONTINUE, "Continue", true, true)]
	_dialogue.open(voronin, line, choices, func(_id: StringName) -> void: _dialogue.close(), hint)
	AudioService.play_sfx(Sfx.HAGGLE_FAIL)


func _present_notice(notice: Dictionary) -> void:
	var choices: Array[DialogueChoice] = [DialogueChoice.new(Encounters.CONTINUE, "Continue", true, true)]
	var player := Content.player(GameState.run.player_id)
	_dialogue.open(player, str(notice.get("line", "")), choices, func(_id: StringName) -> void: _dialogue.close(), str(notice.get("hint", "")))
	AudioService.play_sfx(Sfx.EVENT)


func _raise_alarm(type: String) -> void:
	match type:
		Encounters.POLICE:
			_lights.switch_on(POLICE_LIGHTS)
			AudioService.start_siren()
			_shake(POLICE_SHAKE_PIXELS, POLICE_VIBRATE_MS)
		Encounters.RAID:
			_lights.switch_on(RAID_LIGHTS)
			AudioService.start_siren()
			AudioService.play_sfx(Sfx.RAID_HIT)
			_shake(RAID_SHAKE_PIXELS, RAID_VIBRATE_MS)
		Encounters.ENFORCERS:
			AudioService.play_sfx(Sfx.CAUGHT)
			_shake(HIT_SHAKE_PIXELS, POLICE_VIBRATE_MS)
		Vex.GATE, Vex.HUNT, Ambush.TYPE:
			AudioService.play_sfx(Sfx.TURF_CLASH)
			_shake(POLICE_SHAKE_PIXELS, POLICE_VIBRATE_MS)
		Turf.VICTORY, Campaign.CAREER_START:
			AudioService.play_sfx(Sfx.TURF_WON)
		Families.SHAKEDOWN:
			AudioService.play_sfx(Sfx.SHAKEDOWN)
			_shake(POLICE_SHAKE_PIXELS, POLICE_VIBRATE_MS)
		_:
			AudioService.play_sfx(Sfx.EVENT)


func _stand_down() -> void:
	_lights.switch_off()
	AudioService.stop_siren()


func _resolve_encounter(choice: StringName) -> void:
	var run := GameState.run
	var cash_before := run.cash
	var bag_before := Inventory.used(run)
	var outcome := GameState.resolve_encounter(choice)
	_stand_down()
	if outcome.is_empty():
		_dialogue.close()
		return
	_play_outcome(choice, run.cash < cash_before or Inventory.used(run) < bag_before)
	var next: Array[DialogueChoice] = [DialogueChoice.new(Encounters.CONTINUE, "Continue", true, true)]
	_dialogue.say(outcome, next, func(_id: StringName) -> void: _dialogue.close(), false)


func _play_outcome(choice: StringName, lost_something: bool) -> void:
	if choice in [Encounters.BRIBE, Encounters.PAY, Vex.BRIBE, Vex.PAY, Families.PAY_UP, Ambush.PAY]:
		AudioService.play_sfx(Sfx.COINS_OUT)
	elif lost_something:
		AudioService.play_sfx(Sfx.CAUGHT)
		_shake(HIT_SHAKE_PIXELS, POLICE_VIBRATE_MS)


func _shake(pixels: float, vibrate_ms: int) -> void:
	if Settings.vibration:
		Input.vibrate_handheld(vibrate_ms)
	if Settings.screen_shake:
		_shake_pixels = maxf(_shake_pixels, pixels)


## Moves both the game screen and this overlay, since CanvasLayers ignore the viewport transform.
func _update_shake(delta: float) -> void:
	if _shake_pixels <= 0.0:
		return
	_shake_pixels = move_toward(_shake_pixels, 0.0, SHAKE_DECAY_PER_SECOND * delta)
	var jolt := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_pixels
	offset = jolt
	get_viewport().canvas_transform = Transform2D(0.0, jolt)
