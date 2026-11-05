extends CanvasLayer

const DIALOGUE_PANEL := "res://ui/components/dialogue_panel.tscn"
const LOAN_SHEET := "res://ui/components/loan_sheet.tscn"
const INVENTORY_SHEET := "res://ui/components/inventory_sheet.tscn"
const TURF_SHEET := "res://ui/components/turf_sheet.tscn"
const JOBS_SHEET := "res://ui/components/jobs_sheet.tscn"
const JAIL_CARD := "res://ui/components/jail_card.tscn"
const OFFER_BANNER := "res://ui/components/offer_banner.tscn"
const QUOTE_SHEET := "res://ui/components/quote_sheet.tscn"
const PROFILE_SHEET := "res://ui/components/profile_sheet.tscn"
const CREW_PICKER := "res://ui/components/crew_picker.tscn"
const TRAINING_PICKER := "res://ui/components/training_picker.tscn"
const WEAPON_PICKER := "res://ui/components/weapon_picker.tscn"
const TARGET_CARD := "res://ui/components/target_card.tscn"
const BATTLE_SCENE := "res://ui/battle/battle_scene.tscn"
const HUD_BAR := "res://ui/chrome/hud_bar.tscn"
const NAV_BAR := "res://ui/chrome/nav_bar.tscn"
const RAID_BACKDROP := "res://assets/scenes/raid.jpg"
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
const BAIL_LINE := "Bail's paid. Don't thank me, just stop carrying through Brandt's street."

var _dialogue: DialoguePanel
var _hud_margin: MarginContainer
var _hud_bar: HudBar
var _nav_bar: NavBar
var _loan_sheet: LoanSheet
var _inventory_sheet: InventorySheet
var _turf_sheet: TurfSheet
var _jobs_sheet: JobsSheet
var _quote_sheet: QuoteSheet
var _profile_sheet: ProfileSheet
var _jail_card: JailCard
var _crew_picker: CrewPicker
var _training_picker: TrainingPicker
var _weapon_picker: WeaponPicker
var _target_card: TargetCard
var _banner: OfferBanner
var _lights: PoliceLights
var _battle: BattleScene
var _raid: RaidScene
var _ambush_alert: AmbushAlert
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


var _is_setup := false


func _ready() -> void:
	layer = 50
	Palette.sync_theme()
	Palette.style_tree(get_tree().root)
	get_tree().node_added.connect(Palette.on_node_added)
	if DisplayServer.get_name() == "headless":
		ensure_setup()


func ensure_setup() -> void:
	if _is_setup:
		return
	_is_setup = true
	_dialogue = load(DIALOGUE_PANEL).instantiate()
	_loan_sheet = load(LOAN_SHEET).instantiate()
	_inventory_sheet = load(INVENTORY_SHEET).instantiate()
	_turf_sheet = load(TURF_SHEET).instantiate()
	_jobs_sheet = load(JOBS_SHEET).instantiate()
	_quote_sheet = load(QUOTE_SHEET).instantiate()
	_profile_sheet = load(PROFILE_SHEET).instantiate()
	_jail_card = load(JAIL_CARD).instantiate()
	_crew_picker = load(CREW_PICKER).instantiate()
	_training_picker = load(TRAINING_PICKER).instantiate()
	_weapon_picker = load(WEAPON_PICKER).instantiate()
	_target_card = load(TARGET_CARD).instantiate()
	_banner = load(OFFER_BANNER).instantiate()
	_lights = PoliceLights.new()
	add_child(_jail_card)
	add_child(_inventory_sheet)
	add_child(_turf_sheet)
	add_child(_jobs_sheet)
	add_child(_profile_sheet)
	add_child(_quote_sheet)
	add_child(_loan_sheet)

	_hud_margin = MarginContainer.new()
	_hud_margin.name = "HudMargin"
	_hud_margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hud_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_margin.z_index = 10
	_hud_bar = load(HUD_BAR).instantiate()
	_hud_margin.add_child(_hud_bar)
	add_child(_hud_margin)

	_nav_bar = load(NAV_BAR).instantiate()
	_nav_bar.z_index = 10
	add_child(_nav_bar)

	add_child(_banner)
	add_child(_target_card)
	add_child(_dialogue)
	add_child(_crew_picker)
	add_child(_training_picker)
	add_child(_weapon_picker)
	for modal: CanvasItem in [_quote_sheet, _loan_sheet, _banner, _target_card, _dialogue, _crew_picker, _training_picker, _weapon_picker]:
		modal.z_index = 20
	_jail_card.bail_requested.connect(_post_bail)
	_banner.opened.connect(_open_offer)
	SceneRouter.transition_started.connect(_target_card.cancel)
	_dialogue.add_backdrop_layer(_lights)
	for sheet in _sheets():
		SceneRouter.transition_started.connect(sheet.close)
	GameState.orders_missed.connect(_on_orders_missed)
	GameState.favours_missed.connect(_on_favours_missed)
	GameState.crate_lost.connect(_on_crate_lost)
	GameState.notices_posted.connect(_on_notices_posted)
	GameState.offers_posted.connect(_queue_offers)
	GameState.customer_offers_posted.connect(_queue_offers)
	GameState.run_changed.connect(_on_run_changed)
	GameState.run_loaded.connect(_on_run_loaded)
	GameState.run_started.connect(_on_run_started)
	GameState.run_ended.connect(_on_run_ended)
	_update_hud_safe_margins()
	get_tree().root.size_changed.connect(_update_hud_safe_margins)
	SceneRouter.scene_changed.connect(_on_scene_changed)
	_update_hud_visibility()


## Screens opt in by defining can_present_encounter(), so encounters never interrupt animations or other modals.
func _process(delta: float) -> void:
	if not _is_setup:
		return
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
		elif not Tutorial.next_lesson(GameState.run).is_empty():
			_present_lesson(Tutorial.next_lesson(GameState.run))
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
	ensure_setup()
	_loan_sheet.open_loan(mode)


func open_bag() -> void:
	ensure_setup()
	_close_pages_except(_inventory_sheet)
	if not _inventory_sheet.visible:
		_inventory_sheet.open_inventory()


func open_turf() -> void:
	ensure_setup()
	_close_pages_except(_turf_sheet)
	_turf_sheet.open_turf()


func open_jobs() -> void:
	ensure_setup()
	_close_pages_except(_jobs_sheet)
	if not _jobs_sheet.visible:
		_jobs_sheet.open_jobs()


func open_profile() -> void:
	ensure_setup()
	_close_pages_except(_profile_sheet)
	if not _profile_sheet.visible:
		_profile_sheet.open_profile()


## Where to buy the goods for an accepted customer order.
func open_quotes(order_id: String) -> void:
	ensure_setup()
	_close_pages_except(_quote_sheet)
	_quote_sheet.open_quotes(order_id)


func close_pages() -> void:
	_close_pages_except(null)


func _close_pages_except(keep: BottomSheet) -> void:
	for page: BottomSheet in [_inventory_sheet, _turf_sheet, _jobs_sheet, _quote_sheet, _profile_sheet]:
		if page != null and page != keep:
			page.close()


## Opens a conversation that is not an encounter. See DialoguePanel.open for the callback contract.
## Nobody talks business with a player in a cell.
func talk(speaker: SpeakerDef, line: String, choices: Array[DialogueChoice], on_choice: Callable, hint := "") -> void:
	ensure_setup()
	if blocked_by_jail():
		return
	_dialogue.open(speaker, line, choices, on_choice, hint)


## True while the player sits in a cell, so the activity has to wait. Points the player at the jail card.
func blocked_by_jail() -> bool:
	ensure_setup()
	if GameState.run == null or not Police.is_jailed(GameState.run):
		return false
	for sheet in _sheets():
		sheet.close()
	_jail_card.nudge()
	return true


func say(line: String, choices: Array[DialogueChoice], on_choice: Callable, talking := true, hint := "") -> void:
	ensure_setup()
	_dialogue.say(line, choices, on_choice, talking, hint)


func end_talk() -> void:
	_dialogue.close()


## Asks the player who goes into a fight. on_sent receives the deployment. Back or cancel calls on_cancel.
func pick_crew(title: String, message: String, send_format: String, cancel_text: String, on_sent: Callable, on_cancel: Callable) -> void:
	ensure_setup()
	_dialogue.close()
	_crew_picker.open(title, message, send_format, cancel_text, on_sent, on_cancel)


## Asks how many men to put through a Gym course.
func pick_training(course: Gym.Course) -> void:
	ensure_setup()
	_dialogue.close()
	_training_picker.open(course)


## Sizes up a rival corner: the latest scouting report against the player's force, with Scout and Attack.
func show_target(corner: CornerDef, people: Array[SpeakerDef]) -> void:
	ensure_setup()
	_dialogue.close()
	_target_card.open(corner, people)


## Asks how many weapons to buy from Rook or sell back to him. on_closed gets true when the deal went through.
func pick_weapons(grade: Armory.Grade, selling: bool, on_closed: Callable) -> void:
	ensure_setup()
	_dialogue.close()
	_weapon_picker.open(grade, selling, on_closed)


## Plays a fight that is already decided over the current screen, then calls on_done.
func play_battle(player_side: BattleSide, enemy_side: BattleSide, result_line: String, battle_seed: int, on_done: Callable) -> void:
	ensure_setup()
	_dialogue.close()
	_battle = load(BATTLE_SCENE).instantiate()
	add_child(_battle)
	_battle.finished.connect(func() -> void:
		_battle.queue_free()
		_battle = null
		on_done.call())
	_battle.play(player_side, enemy_side, result_line, battle_seed)


func play_raid(officer: SpeakerDef, result_line: String, on_done: Callable) -> void:
	ensure_setup()
	_dialogue.close()
	_raid = RaidScene.new()
	add_child(_raid)
	_raid.finished.connect(func() -> void:
		_raid.queue_free()
		_raid = null
		on_done.call())
	_raid.play(officer, result_line)


func handle_back() -> bool:
	if not _is_setup:
		return false
	if _battle != null or _raid != null or _ambush_alert != null:
		return true
	if _crew_picker.visible:
		_crew_picker.cancel()
		return true
	for picker: AmountPicker in [_training_picker, _weapon_picker]:
		if picker.visible:
			picker.cancel()
			return true
	if _target_card.visible:
		_target_card.cancel()
		return true
	if _dialogue.visible:
		return _dialogue.handle_back()
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
	if not _is_setup:
		return []
	var sheets: Array[BottomSheet] = [_quote_sheet, _loan_sheet, _inventory_sheet, _turf_sheet, _jobs_sheet, _profile_sheet]
	return sheets


func _post_bail() -> void:
	if not GameState.post_bail():
		_jail_card.nudge()
		return
	AudioService.play_sfx(Sfx.COINS_OUT)
	var rabbit := Content.speaker(RabbitCells.FRIEND)
	if rabbit != null:
		_dialogue.open(rabbit, BAIL_LINE, [DialogueChoice.new(Encounters.CONTINUE, "Continue", true, true)], func(_id: StringName) -> void: _dialogue.close())


## A booked player is walked back to the street, since every other place is closed to them.
func _leave_for_the_cell() -> void:
	var screen := get_tree().current_scene
	if screen != null and screen.scene_file_path != SceneRouter.DISTRICT_SCREEN:
		SceneRouter.go_to(SceneRouter.DISTRICT_SCREEN)


## Offer banners wait behind every card and never stack, so one shows at a time once the cards are done.
func _can_present() -> bool:
	if GameState.run == null:
		return false
	if not _has_cards() and (_banner.is_showing() or _offers.is_empty() or _offers_held()):
		return false
	return _screen_is_free()


## Offers stay in the Jobs list without ringing while the player is in a cell or asked not to be disturbed.
func _offers_held() -> bool:
	return Settings.do_not_disturb or Police.is_jailed(GameState.run)


func _has_cards() -> bool:
	if Encounters.has_pending(GameState.run) or not _filled_orders.is_empty():
		return true
	if not Tutorial.next_lesson(GameState.run).is_empty():
		return true
	return not (_missed_orders.is_empty() and _missed_favours.is_empty() and _lost_crates.is_empty() and _notices.is_empty())


func _screen_is_free() -> bool:
	if GameState.run == null or _dialogue.visible or _crew_picker.visible or _training_picker.visible or _weapon_picker.visible or _target_card.visible or _battle != null or _raid != null or _ambush_alert != null or SceneRouter.is_transitioning():
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
			_banner.show_offer(offer_id, sender.portrait, sender.display_name, Errands.describe(errand), Errands.pay_label(errand))
			return
		var order := Customers.find_offer(run, offer_id)
		if not order.is_empty():
			_banner.show_offer(offer_id, CustomerTalk.PORTRAIT, Customers.customer_name(order), Customers.headline(order), "", Customers.district_name(order).to_upper())
			return
		var ping := JobPings.find(run, offer_id)
		var caller := JobPings.sender(ping) if not ping.is_empty() else null
		if caller != null:
			var place := JobPings.destination(ping)
			_banner.show_offer(offer_id, caller.portrait, caller.display_name, JobPings.headline(ping), Format.money(JobPings.total_pay(ping)), place.display_name.to_upper() if place != null else "")
			return


func _open_offer(offer_id: String) -> void:
	var run := GameState.run
	if not Customers.find_offer(run, offer_id).is_empty():
		CustomerTalk.open(offer_id)
	elif not JobPings.find(run, offer_id).is_empty():
		JobTalk.open(offer_id)
	else:
		OfferTalk.open(offer_id)


func _on_run_changed() -> void:
	var run := GameState.run
	_update_hud_visibility()
	if _banner.is_showing() and not _is_open_offer(run, _banner.offer_id):
		_banner.retract()
	_filled_orders.append_array(_stocked_orders.check(run))


func _clear_transient_queues() -> void:
	_missed_orders.clear()
	_missed_favours.clear()
	_lost_crates.clear()
	_notices.clear()
	_offers.clear()
	_forget_filled_orders()
	if _banner != null:
		_banner.retract()


func _on_scene_changed(scene_path: String) -> void:
	if scene_path == SceneRouter.TITLE_SCREEN or scene_path == SceneRouter.CHARACTER_SELECT:
		_clear_transient_queues()
	_update_hud_visibility(scene_path)


func _update_hud_visibility(scene_path: String = "") -> void:
	if _hud_margin == null:
		return
	if GameState.run == null:
		_hud_margin.visible = false
		if _nav_bar != null:
			_nav_bar.visible = false
		return
	var current := scene_path
	if current.is_empty():
		var cs := get_tree().current_scene
		current = cs.scene_file_path if cs != null else ""
	var hide_bars := current in [SceneRouter.TITLE_SCREEN, SceneRouter.CHARACTER_SELECT, SceneRouter.END_SCREEN, SceneRouter.SETTINGS_SCREEN]
	if hide_bars:
		_hud_margin.visible = false
		if _nav_bar != null:
			_nav_bar.visible = false
		return
	_hud_margin.visible = true
	if _nav_bar != null:
		_nav_bar.visible = true
	_hud_bar.refresh()


func _update_hud_safe_margins() -> void:
	if _hud_margin == null:
		return
	_hud_margin.add_theme_constant_override("margin_top", 0)
	_hud_margin.add_theme_constant_override("margin_left", 0)
	_hud_margin.add_theme_constant_override("margin_right", 0)
	if _hud_bar != null:
		SafeArea.apply_top_bar_margin(_hud_bar, 8)


func _is_open_offer(run: RunState, offer_id: String) -> bool:
	return not (Errands.find_offer(run, offer_id).is_empty() and Customers.find_offer(run, offer_id).is_empty() and JobPings.find(run, offer_id).is_empty())


func _forget_filled_orders() -> void:
	_filled_orders.clear()
	_stocked_orders.clear()


func _on_orders_missed(orders: Array[Dictionary]) -> void:
	_missed_orders.append_array(orders)


func _on_favours_missed(favours: Array[Dictionary]) -> void:
	_missed_favours.append_array(favours)


func _on_crate_lost(crate: Dictionary) -> void:
	_lost_crates.append(crate)


func _on_notices_posted(notices: Array[Dictionary]) -> void:
	_notices.append_array(notices)


func _on_run_loaded() -> void:
	_clear_transient_queues()
	_update_hud_visibility()


func _on_run_started() -> void:
	_clear_transient_queues()
	_update_hud_visibility()


func _on_run_ended(_outcome: RunState.Outcome) -> void:
	_update_hud_visibility()


func _present_encounter(encounter: Dictionary) -> void:
	var speaker := Content.speaker(StringName(str(encounter.get("speaker", ""))))
	if speaker == null:
		speaker = Content.player(GameState.run.player_id)
	var choices: Array[DialogueChoice] = []
	for choice in Encounters.choices(GameState.run, encounter):
		var plain := choice.id == Encounters.CONTINUE
		choices.append(DialogueChoice.new(choice.id, choice.label, choice.enabled, plain, plain))
	var type := str(encounter.get("type", ""))
	if type == RivalStrike.TYPE:
		_sound_ambush(encounter)
		return
	var open_card := func() -> void:
		_dialogue.open(speaker, str(encounter.get("body", "")), choices, _resolve_encounter, "", load(RAID_BACKDROP) if type == Encounters.RAID else null)
		_raise_alarm(type)
	if type == Encounters.RAID:
		play_raid(speaker, "EVIDENCE BAGGED", open_card)
	else:
		open_card.call()


func _sound_ambush(encounter: Dictionary) -> void:
	_ambush_alert = AmbushAlert.new()
	add_child(_ambush_alert)
	_ambush_alert.show_ambush(encounter)
	_shake(RAID_SHAKE_PIXELS, RAID_VIBRATE_MS)
	_ambush_alert.decided.connect(func(choice: StringName) -> void:
		_ambush_alert.queue_free()
		_ambush_alert = null
		AmbushTalk.answer(choice))


func _present_lesson(lesson: String, page := 0) -> void:
	var lines := Tutorial.lines(lesson)
	var last := page >= lines.size() - 1
	var hint := Tutorial.hint(lesson) if last else ""
	var on_choice := _on_lesson_choice.bind(lesson, page)
	if page == 0:
		talk(Content.speaker(Tutorial.SPEAKER), str(lines[page]), Tutorial.choices(last), on_choice, hint)
	else:
		say(str(lines[page]), Tutorial.choices(last), on_choice, true, hint)


func _on_lesson_choice(choice: StringName, lesson: String, page: int) -> void:
	var run := GameState.run
	if choice == Tutorial.SKIP:
		Tutorial.switch_off(run)
	elif page < Tutorial.lines(lesson).size() - 1:
		_present_lesson(lesson, page + 1)
		return
	else:
		Tutorial.finish_lesson(run, lesson)
	GameState.save_run()
	end_talk()


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
	var line := VoroninTalk.LOST_CRATE_LINE
	var hint := "Crate never reached %s. No work from Voronin for the rest of the day, and his pay bonus for a streak starts over." % place
	var choices: Array[DialogueChoice] = [DialogueChoice.new(Encounters.CONTINUE, "Continue", true, true)]
	_dialogue.open(voronin, line, choices, func(_id: StringName) -> void: _dialogue.close(), hint)
	AudioService.play_sfx(Sfx.HAGGLE_FAIL)


func _present_notice(notice: Dictionary) -> void:
	var choices: Array[DialogueChoice] = [DialogueChoice.new(Encounters.CONTINUE, "Continue", true, true)]
	var speaker: SpeakerDef = Content.speaker(StringName(str(notice.get("speaker", ""))))
	if speaker == null:
		speaker = Content.player(GameState.run.player_id)
	_dialogue.open(speaker, str(notice.get("line", "")), choices, func(_id: StringName) -> void: _dialogue.close(), str(notice.get("hint", "")))
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
		Encounters.ENFORCERS, DebtSale.VEX_VISIT:
			AudioService.play_sfx(Sfx.CAUGHT)
			_shake(HIT_SHAKE_PIXELS, POLICE_VIBRATE_MS)
		Gangs.GATE, Gangs.HUNT, Ambush.TYPE:
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
	var encounter_type := str(run.pending_encounter.get("type", ""))
	var cash_before := run.cash
	var bag_before := Inventory.used(run)
	var raided := str(run.pending_encounter.get("type", "")) == Ramos.TIP
	var outcome := GameState.resolve_encounter(choice)
	_stand_down()
	if encounter_type == Lending.SALE_OFFER and choice == Lending.VISIT_SHARK:
		_dialogue.close()
		run.district_id = &"downtown"
		StreetTalk.talk_to(Content.character(Loan.LENDER))
		return
	if outcome.is_empty():
		_dialogue.close()
		return
	var next: Array[DialogueChoice] = [DialogueChoice.new(Encounters.CONTINUE, "Continue", true, true)]
	if raided:
		var brandt := Content.speaker(Police.BRANDT)
		var found := Inventory.used(run) < bag_before
		play_raid(brandt, "EVIDENCE BAGGED" if found else "NOTHING FOUND", func() -> void:
			_dialogue.open(Content.player(run.player_id), outcome, next, func(_id: StringName) -> void: _dialogue.close()))
		return
	_play_outcome(choice, run.cash < cash_before or Inventory.used(run) < bag_before)
	var jailed := Police.is_jailed(run)
	_dialogue.say(outcome, next, func(_id: StringName) -> void:
		_dialogue.close()
		if jailed:
			_leave_for_the_cell(), false)


func _play_outcome(choice: StringName, lost_something: bool) -> void:
	if choice in [Encounters.BRIBE, Encounters.PAY, Gangs.BRIBE, Gangs.PAY, Families.PAY_UP, Ambush.PAY]:
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
