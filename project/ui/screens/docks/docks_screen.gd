extends Control

const ITEM_ROW := preload("res://ui/components/item_row.tscn")
const GREETING_DELAY := 0.35
const HORN_DB := -6.0
const TAKE: StringName = &"take"
const QUIET: StringName = &"quiet"
const LOUD: StringName = &"loud"
const LEAVE: StringName = &"leave"

@onready var _background: TextureRect = %Background
@onready var _margin: MarginContainer = %Margin
@onready var _header: Control = %Header
@onready var _portrait: TalkingPortrait = %Portrait
@onready var _venue_label: Label = %VenueLabel
@onready var _host_label: Label = %HostLabel
@onready var _speech: Typewriter = %Speech
@onready var _scroll: ScrollContainer = %Scroll
@onready var _list: VBoxContainer = %List
@onready var _bag_button: Button = %BagButton
@onready var _back_button: Button = %BackButton

var _venue: VenueDef
var _host: CharacterDef


func _ready() -> void:
	var district: DistrictDef = GameState.current_district() if GameState.run != null else null
	_venue = Content.venue(GameState.visiting_venue)
	_host = Content.character(_venue.host) if _venue != null else null
	if district == null or _host == null or not district.venues.has(_venue.id):
		SceneRouter.go_to.call_deferred(SceneRouter.TITLE_SCREEN if district == null else SceneRouter.DISTRICT_SCREEN)
		return

	SafeArea.apply_top_margin(_margin, 40)
	_background.texture = _venue.background if _venue.background != null else district.background
	_venue_label.text = _venue.display_name.to_upper()
	_host_label.text = _host.display_name
	_portrait.show_speaker(_host)
	_speech.finished.connect(_portrait.set_talking.bind(false))

	_bag_button.pressed.connect(GameOverlay.open_bag)
	_back_button.pressed.connect(SceneRouter.go_to.bind(SceneRouter.DISTRICT_SCREEN))
	GameState.run_changed.connect(_refresh)

	GameState.clock_active = true
	_refresh()
	_play_entrance()
	AudioService.play_sfx(Sfx.SHIP_HORN, 0.05, HORN_DB)
	var greeting := "No work for you today. You know why." if Smuggling.is_banned(GameState.run) else _host.line
	get_tree().create_timer(GREETING_DELAY).timeout.connect(_host_says.bind(greeting))


func _exit_tree() -> void:
	GameState.clock_active = false


func can_present_encounter() -> bool:
	return true


func handle_back() -> bool:
	SceneRouter.go_to(SceneRouter.DISTRICT_SCREEN)
	return true


func _host_says(line: String) -> void:
	if not is_inside_tree():
		return
	_portrait.set_talking(true)
	_speech.type_text("\"%s\"" % line)


func _refresh() -> void:
	var run := GameState.run
	_bag_button.text = "Bag %d/%d" % [Inventory.used(run), Inventory.capacity(run)]
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()

	_add_label("THIS PHASE'S SHIPMENT", &"ListHeading")
	_add_shipment_row(Hijacks.target(run))

	_add_label("YOUR CRATE", &"ListHeading")
	if Smuggling.is_carrying(run):
		var row := _add_row()
		row.show_entry(Smuggling.CRATE_ICON, "Sealed crate", Format.money(Smuggling.payout(run, run.crate)), Smuggling.describe(run.crate), "%d SLOTS" % Smuggling.slots_used(run), Palette.PRICE)
	else:
		_add_label("You are not carrying a crate.", &"MutedLabel")

	_add_label("CRATE RUNS", &"ListHeading")
	if Smuggling.is_banned(run):
		_add_label("Voronin has no work for you today. Come back tomorrow.", &"MutedLabel")
		return
	var offers := Smuggling.board(run)
	for offer in offers:
		var row := _add_row()
		row.show_entry(Smuggling.CRATE_ICON, "Sealed crate", Format.money(Smuggling.payout(run, offer)), Smuggling.describe(offer), "%d SLOTS" % int(offer.slots), Palette.PRICE)
		row.item_selected.connect(func(_item: ItemDef) -> void: _talk_about_crate(offer))
	if offers.is_empty():
		_add_label("Every crate has gone out. New runs tomorrow.", &"MutedLabel")


func _add_shipment_row(shipment: Dictionary) -> void:
	if shipment.is_empty():
		return
	var run := GameState.run
	var item: ItemDef = shipment.item
	var detail := "TAP TO PLAN"
	var detail_color := Palette.TEXT_CREAM
	if Hijacks.attempted(run):
		detail = "ALREADY HIT THIS PHASE"
		detail_color = Palette.TEXT_MUTED
	elif Hijacks.haul(run, shipment) <= 0:
		detail = "NO ROOM IN YOUR BAG"
		detail_color = Palette.TEXT_MUTED
	var row := _add_row()
	row.display(item, "x%d" % int(shipment.quantity), "Coming off a boat on the north quay", detail, detail_color)
	row.item_selected.connect(func(_item: ItemDef) -> void: _talk_about_shipment(shipment))


func _add_row() -> ItemRow:
	var row: ItemRow = ITEM_ROW.instantiate()
	_list.add_child(row)
	return row


func _add_label(text: String, variation: StringName) -> void:
	var label := Label.new()
	label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	_list.add_child(label)


func _talk_about_crate(offer: Dictionary) -> void:
	var place := Smuggling.destination(offer)
	var line := "This one goes to %s. %d slots, and you have %d phases once you take it. %s when it arrives." % [
		place.display_name if place != null else "the drop", int(offer.slots), int(offer.lead), Format.money(Smuggling.payout(GameState.run, offer)),
	]
	var check := Smuggling.check_accept(GameState.run, offer)
	var hint := "Police stops can take it. Lose it and I have no work for you for the rest of the day."
	match check:
		Smuggling.Result.CARRYING:
			hint = "You are already carrying one of my crates."
		Smuggling.Result.NO_ROOM:
			hint = "You need %d free bag slots." % int(offer.slots)
	var choices: Array[DialogueChoice] = [
		DialogueChoice.new(TAKE, "Take the crate", check == Smuggling.Result.OK),
		DialogueChoice.new(LEAVE, "Not now", true, true),
	]
	GameOverlay.talk(_host, line, choices, _on_crate_choice.bind(offer), hint)


func _on_crate_choice(choice: StringName, offer: Dictionary) -> void:
	if choice != TAKE:
		GameOverlay.end_talk()
		return
	var result := GameState.accept_crate(offer)
	var reply := "Good. Do not open it, and do not get stopped." if result == Smuggling.Result.OK else "Not this one. Ask me again."
	if result == Smuggling.Result.OK:
		AudioService.play_sfx(Sfx.CRATE_LIFT)
	GameOverlay.say(reply, _leave_choice(), _end_talk)


func _talk_about_shipment(shipment: Dictionary) -> void:
	var run := GameState.run
	var item: ItemDef = shipment.item
	if Hijacks.attempted(run):
		_host_says("You already hit one boat this phase. Let the quay cool off.")
		return
	var haul := Hijacks.haul(run, shipment)
	if haul <= 0:
		_host_says("Your bag is full. Make room before you go stealing.")
		return
	var line := "A boat is unloading %s right now, %d units. Go in quiet, or go in loud?" % [item.display_name, int(shipment.quantity)]
	var quiet := Hijacks.Approach.QUIET
	var loud := Hijacks.Approach.LOUD
	var choices: Array[DialogueChoice] = [
		DialogueChoice.new(QUIET, "Quiet, %d%% chance" % roundi(Hijacks.SUCCESS_CHANCE[quiet] * 100.0)),
		DialogueChoice.new(LOUD, "Loud, %d%% chance" % roundi(Hijacks.SUCCESS_CHANCE[loud] * 100.0)),
		DialogueChoice.new(LEAVE, "Not now", true, true),
	]
	var hint := "Quiet adds %d heat, loud adds %d. If it fails, %d more and the police arrive." % [Hijacks.HEAT[quiet], Hijacks.HEAT[loud], Hijacks.FAILED_HEAT]
	if haul < int(shipment.quantity):
		hint += " Your bag fits %d." % haul
	GameOverlay.talk(_host, line, choices, _on_shipment_choice.bind(shipment), hint)


func _on_shipment_choice(choice: StringName, shipment: Dictionary) -> void:
	if choice != QUIET and choice != LOUD:
		GameOverlay.end_talk()
		return
	var approach := Hijacks.Approach.QUIET if choice == QUIET else Hijacks.Approach.LOUD
	AudioService.play_sfx(Sfx.HIJACK_QUIET if approach == Hijacks.Approach.QUIET else Sfx.HIJACK_LOUD)
	var item: ItemDef = shipment.item
	var taken := GameState.hijack(shipment, approach)
	if taken > 0:
		AudioService.play_sfx(Sfx.CRATE_LIFT)
		GameOverlay.say("Clean job. %d %s, and nobody saw a thing." % [taken, item.display_name], _leave_choice(), _end_talk)
	else:
		GameOverlay.say("It went wrong. Move, the police are already on the quay.", _leave_choice(), _end_talk)


func _leave_choice() -> Array[DialogueChoice]:
	var choices: Array[DialogueChoice] = [DialogueChoice.new(LEAVE, "Leave", true, true)]
	return choices


func _end_talk(_choice: StringName) -> void:
	GameOverlay.end_talk()


func _play_entrance() -> void:
	_header.modulate.a = 0.0
	_scroll.modulate.a = 0.0
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_header, "modulate:a", 1.0, 0.4)
	tween.tween_property(_scroll, "modulate:a", 1.0, 0.45).set_delay(0.12)
