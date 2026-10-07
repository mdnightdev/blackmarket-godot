extends CanvasLayer

const DIALOGUE_PANEL := preload("res://ui/components/dialogue_panel.tscn")
const LOAN_SHEET := preload("res://ui/components/loan_sheet.tscn")
const INVENTORY_SHEET := preload("res://ui/components/inventory_sheet.tscn")
const FAMILIES_SHEET := preload("res://ui/components/families_sheet.tscn")
const JOBS_SHEET := preload("res://ui/components/jobs_sheet.tscn")
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
var _families_sheet: FamiliesSheet
var _jobs_sheet: JobsSheet
var _lights: PoliceLights
var _settled_for := 0.0
var _shake_pixels := 0.0
## Shown one at a time after any pending encounter. Kept in memory only, since missing an order is already saved.
var _missed_orders: Array[Dictionary] = []
var _missed_favours: Array[Dictionary] = []
var _lost_crates: Array[Dictionary] = []


func _ready() -> void:
	layer = 50
	_dialogue = DIALOGUE_PANEL.instantiate()
	_loan_sheet = LOAN_SHEET.instantiate()
	_inventory_sheet = INVENTORY_SHEET.instantiate()
	_families_sheet = FAMILIES_SHEET.instantiate()
	_jobs_sheet = JOBS_SHEET.instantiate()
	_lights = PoliceLights.new()
	add_child(_inventory_sheet)
	add_child(_families_sheet)
	add_child(_jobs_sheet)
	add_child(_loan_sheet)
	add_child(_dialogue)
	_dialogue.add_backdrop_layer(_lights)
	for sheet: BottomSheet in [_loan_sheet, _inventory_sheet, _families_sheet, _jobs_sheet]:
		SceneRouter.transition_started.connect(sheet.close)
	GameState.orders_missed.connect(func(orders: Array[Dictionary]) -> void: _missed_orders.append_array(orders))
	GameState.favours_missed.connect(func(favours: Array[Dictionary]) -> void: _missed_favours.append_array(favours))
	GameState.crate_lost.connect(func(crate: Dictionary) -> void: _lost_crates.append(crate))
	GameState.run_started.connect(func() -> void:
		_missed_orders.clear()
		_missed_favours.clear()
		_lost_crates.clear()
	)


## Screens opt in by defining can_present_encounter(), so encounters never interrupt animations or other modals.
func _process(delta: float) -> void:
	_update_shake(delta)
	if _lights.is_on() and not _dialogue.visible:
		_stand_down()
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
		else:
			_present_lost_crate(_lost_crates.pop_front())


func open_loan(mode := LoanSheet.Mode.REPAY) -> void:
	_loan_sheet.open_loan(mode)


func open_bag() -> void:
	_inventory_sheet.open_inventory()


func open_families() -> void:
	_families_sheet.open_families()


func open_jobs() -> void:
	_jobs_sheet.open_jobs()


## Opens a conversation that is not an encounter. See DialoguePanel.open for the callback contract.
func talk(speaker: SpeakerDef, line: String, choices: Array[DialogueChoice], on_choice: Callable, hint := "") -> void:
	_dialogue.open(speaker, line, choices, on_choice, hint)


func say(line: String, choices: Array[DialogueChoice], on_choice: Callable, talking := true) -> void:
	_dialogue.say(line, choices, on_choice, talking)


func end_talk() -> void:
	_dialogue.close()


func is_talking() -> bool:
	return _dialogue.visible


func handle_back() -> bool:
	if _dialogue.visible:
		return _dialogue.handle_back()
	for sheet: BottomSheet in [_loan_sheet, _inventory_sheet, _families_sheet, _jobs_sheet]:
		if sheet.visible:
			sheet.close()
			return true
	return false


func _can_present() -> bool:
	if GameState.run == null:
		return false
	if not Encounters.has_pending(GameState.run) and _missed_orders.is_empty() and _missed_favours.is_empty() and _lost_crates.is_empty():
		return false
	if _dialogue.visible or _loan_sheet.visible or _inventory_sheet.visible or _families_sheet.visible or _jobs_sheet.visible or SceneRouter.is_transitioning():
		return false
	var screen := get_tree().current_scene
	return screen != null and screen.has_method("can_present_encounter") and screen.can_present_encounter()


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
		Turf.CLASH:
			AudioService.play_sfx(Sfx.TURF_CLASH)
			_shake(POLICE_SHAKE_PIXELS, POLICE_VIBRATE_MS)
		Turf.VICTORY:
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
	if choice in [Encounters.BRIBE, Encounters.PAY, Turf.TRIBUTE, Families.PAY_UP]:
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
