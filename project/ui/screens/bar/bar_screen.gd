extends Control

const ITEM_ROW := preload("res://ui/components/item_row.tscn")
const GREETING_DELAY := 0.35
const TAKE: StringName = &"take"
const DROP: StringName = &"drop"
const LEAVE: StringName = &"leave"

@onready var _background: TextureRect = %Background
@onready var _margin: MarginContainer = %Margin
@onready var _header: Control = %Header
@onready var _portrait: TalkingPortrait = %Portrait
@onready var _venue_label: Label = %VenueLabel
@onready var _host_label: Label = %HostLabel
@onready var _speech: Typewriter = %Speech
@onready var _rumor_button: Button = %RumorButton
@onready var _scroll: ScrollContainer = %Scroll
@onready var _list: VBoxContainer = %List
@onready var _bag_button: Button = %BagButton
@onready var _back_button: Button = %BackButton
@onready var _inventory_sheet: InventorySheet = %InventorySheet

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

	_rumor_button.pressed.connect(_buy_rumor)
	_bag_button.pressed.connect(_inventory_sheet.open_inventory)
	_back_button.pressed.connect(SceneRouter.go_to.bind(SceneRouter.DISTRICT_SCREEN))
	GameState.run_changed.connect(_refresh)

	GameState.clock_active = true
	_refresh()
	_play_entrance()
	get_tree().create_timer(GREETING_DELAY).timeout.connect(_host_says.bind(_host.line))


func _exit_tree() -> void:
	GameState.clock_active = false


func can_present_encounter() -> bool:
	return not _inventory_sheet.visible


func handle_back() -> bool:
	if _inventory_sheet.visible:
		_inventory_sheet.close()
	else:
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
	_refresh_rumor_button()

	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()

	_add_label("ORDER BOARD", &"SectionLabel")
	var offers := Orders.board(run, _venue.id)
	for offer in offers:
		_add_order_row(offer, false)
	if offers.is_empty():
		_add_label("The board is empty. New work goes up tomorrow.", &"MutedLabel")

	_add_label("YOUR ORDERS %d/%d" % [run.orders.size(), Orders.MAX_ACTIVE], &"SectionLabel")
	for order in run.orders:
		_add_order_row(order, true)
	if run.orders.is_empty():
		_add_label("No orders taken. Deliver at the dealer's market before the deadline.", &"MutedLabel")


func _refresh_rumor_button() -> void:
	var run := GameState.run
	var price := Format.money(Rumors.PRICE)
	if Rumors.sold_out(run, _venue.id):
		_rumor_button.text = "Rumour heard this phase"
		_rumor_button.disabled = true
	elif not Rumors.can_afford(run):
		_rumor_button.text = "Rumour %s, not enough cash" % price
		_rumor_button.disabled = true
	else:
		_rumor_button.text = "Buy a rumour for %s" % price
		_rumor_button.disabled = false


func _add_label(text: String, variation: StringName) -> void:
	var label := Label.new()
	label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	_list.add_child(label)


func _add_order_row(order: Dictionary, taken: bool) -> void:
	var item := Content.item(StringName(order.item))
	var dealer := Content.dealer(StringName(order.dealer))
	if item == null or dealer == null:
		return
	var quantity := int(order.quantity)
	var caption := "%d for %s, %s" % [quantity, dealer.display_name, _district_name(dealer)]
	var detail := "BY %s" % Calendar.describe(int(order.due)).to_upper()
	var detail_color := Palette.TEXT_CREAM
	if taken:
		var held := Inventory.count(GameState.run, item.id)
		detail = "HAVE %d/%d" % [mini(held, quantity), quantity]
		detail_color = Palette.RISK_LOW if held >= quantity else Palette.TEXT_MUTED
	var row: ItemRow = ITEM_ROW.instantiate()
	_list.add_child(row)
	row.display(item, Format.money(Orders.total(order)), caption, detail, detail_color)
	row.item_selected.connect(func(_item: ItemDef) -> void: _talk_about_order(order, taken))


func _talk_about_order(order: Dictionary, taken: bool) -> void:
	var item := Content.item(StringName(order.item))
	var dealer := Content.dealer(StringName(order.dealer))
	var due := Calendar.describe(int(order.due)).to_lower()
	var choices: Array[DialogueChoice] = []
	if taken:
		var line := "%s is still waiting on %d %s in %s, by %s." % [dealer.display_name, int(order.quantity), item.display_name, _district_name(dealer), due]
		choices.append(DialogueChoice.new(DROP, "Drop the order"))
		choices.append(DialogueChoice.new(LEAVE, "Keep it", true, true))
		var hint := "Dropping it means %s will not trade with you this phase." % dealer.display_name
		GameOverlay.talk(_host, line, choices, _on_order_choice.bind(order), hint)
		return
	var line := "%s wants %d %s in %s by %s. %s each, %s in total." % [
		dealer.display_name, int(order.quantity), item.display_name, _district_name(dealer), due,
		Format.money(int(order.price)), Format.money(Orders.total(order)),
	]
	var full := GameState.run.orders.size() >= Orders.MAX_ACTIVE
	choices.append(DialogueChoice.new(TAKE, "Take the order", not full))
	choices.append(DialogueChoice.new(LEAVE, "Not now", true, true))
	var hint := "Miss the deadline and %s will not trade with you for a phase." % dealer.display_name
	if full:
		hint = "You already hold %d orders. Deliver or drop one first." % Orders.MAX_ACTIVE
	GameOverlay.talk(_host, line, choices, _on_order_choice.bind(order), hint)


func _on_order_choice(choice: StringName, order: Dictionary) -> void:
	var leave: Array[DialogueChoice] = [DialogueChoice.new(LEAVE, "Leave", true, true)]
	match choice:
		TAKE:
			var result := GameState.accept_order(order)
			var reply := "Good. Do not keep them waiting." if result == Orders.Result.OK else "Too late, that one is gone."
			GameOverlay.say(reply, leave, _end_talk)
		DROP:
			GameState.drop_order(order)
			GameOverlay.say("Shame. I will find someone more reliable.", leave, _end_talk)
		_:
			GameOverlay.end_talk()


func _end_talk(_choice: StringName) -> void:
	GameOverlay.end_talk()


func _buy_rumor() -> void:
	var rumor := GameState.buy_rumor(_venue.id)
	if rumor.is_empty():
		_host_says("Quiet tonight. Nothing worth your money.")
		return
	AudioService.play_sfx(Sfx.COINS_OUT)
	var item: ItemDef = rumor.item
	var dealer: DealerDef = rumor.dealer
	var district: DistrictDef = rumor.district
	_host_says("Word is %s pays %s for %s in %s right now. You did not hear it from me." % [
		dealer.display_name, Format.money(int(rumor.price)), item.display_name, district.display_name if district != null else "town",
	])


func _district_name(dealer: DealerDef) -> String:
	var district := Content.district(dealer.district_id)
	return district.display_name if district != null else "town"


func _play_entrance() -> void:
	_header.modulate.a = 0.0
	_scroll.modulate.a = 0.0
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_header, "modulate:a", 1.0, 0.4)
	tween.tween_property(_scroll, "modulate:a", 1.0, 0.45).set_delay(0.12)
