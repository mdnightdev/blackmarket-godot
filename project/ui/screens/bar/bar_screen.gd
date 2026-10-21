extends BaseScreen

const ITEM_ROW := preload("res://ui/components/item_row.tscn")
const GREETING_DELAY := 0.35
const TAKE: StringName = &"take"
const DROP: StringName = &"drop"
const LEAVE: StringName = &"leave"
const HIRE: StringName = &"hire"
const HIRING_VENUE: StringName = &"tran_bar"

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

var _venue: VenueDef
var _host: CharacterDef


func _ready() -> void:
	var district: DistrictDef = GameState.current_district() if GameState.run != null else null
	_venue = Content.venue(GameState.visiting_venue)
	_host = Content.character(_venue.host) if _venue != null else null
	if district == null or _host == null or not district.venues.has(_venue.id):
		SceneRouter.go_to.call_deferred(SceneRouter.TITLE_SCREEN if district == null else SceneRouter.DISTRICT_SCREEN)
		return

	SafeArea.apply_top_margin(_margin, 64)
	_background.texture = _venue.background if _venue.background != null else district.background
	_venue_label.text = _venue.display_name.to_upper()
	_host_label.text = _host.display_name
	_portrait.show_speaker(_host)
	_speech.finished.connect(_portrait.set_talking.bind(false))

	_rumor_button.pressed.connect(_buy_rumor)
	_bag_button.pressed.connect(GameOverlay.open_bag)
	_back_button.pressed.connect(SceneRouter.go_to.bind(SceneRouter.DISTRICT_SCREEN))
	GameState.run_changed.connect(_refresh)

	GameState.clock_active = true
	_refresh()
	_play_entrance()
	get_tree().create_timer(GREETING_DELAY).timeout.connect(_host_says.bind(_host.line))


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
	_bag_button.text = Inventory.bag_text(run)
	_refresh_rumor_button()
	Utils.clear_container(_list)

	if _venue.id == HIRING_VENUE and Corners.is_for_sale(run):
		_add_label("FOR SALE", &"ListHeading")
		_add_corner_sale_row()
	if _venue.id == HIRING_VENUE and War.unit_on_offer(run):
		_add_label("FOR THE WAR", &"ListHeading")
		_add_unit_row()

	_add_label("ORDER BOARD", &"ListHeading")
	var offers := Orders.board(run, _venue.id)
	for offer in offers:
		_add_order_row(offer, false)
	if offers.is_empty():
		_add_label("The board is empty. New work goes up tomorrow.", &"MutedLabel")

	_add_label("YOUR ORDERS %d/%d" % [run.orders.size(), Orders.MAX_ACTIVE], &"ListHeading")
	for order in run.orders:
		_add_order_row(order, true)
	if run.orders.is_empty():
		_add_label("No orders taken. Deliver at the dealer's market before the deadline.", &"MutedLabel")

	if _venue.id == HIRING_VENUE and Campaign.is_act_two(run):
		_add_label("HIRE CREW %d/%d" % [Crew.hired_count(run), Crew.cap(run)], &"ListHeading")
		for role in Content.crew_roles():
			_add_crew_row(role)


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


func _add_corner_sale_row() -> void:
	var seller := Content.dealer(CornerTalk.MAMA_LIN)
	var affordable := GameState.run.cash >= Corners.MAMA_LIN_PRICE
	var row: ItemRow = ITEM_ROW.instantiate()
	_list.add_child(row)
	row.show_entry(seller.portrait if seller != null else null, "Mama Lin's corner", Format.money(Corners.MAMA_LIN_PRICE), "Vex squeezed her dry. She wants out.", "TAP TO TALK" if affordable else "NOT ENOUGH CASH", Palette.TEXT_CREAM if affordable else Palette.TEXT_MUTED)
	row.item_selected.connect(func(_item: ItemDef) -> void: CornerTalk.offer_mama_lin(_host))


func _add_unit_row() -> void:
	var rabbit := Content.speaker(WarTalk.RABBIT)
	var row: ItemRow = ITEM_ROW.instantiate()
	_list.add_child(row)
	row.show_entry(rabbit.portrait if rabbit != null else null, "Rabbit's unit", Format.money(War.RABBIT_UNIT_PRICE), "%d of his friends from the army. The first of the Black Hand." % War.RABBIT_UNIT_SIZE, "TAP TO TALK", Palette.TEXT_CREAM)
	row.item_selected.connect(func(_item: ItemDef) -> void: WarTalk.offer_unit())


func _add_crew_row(role: CrewRoleDef) -> void:
	var result := Crew.check_hire(GameState.run, role.id)
	var detail := ""
	var detail_color := Palette.TEXT_MUTED
	match result:
		Crew.Result.OK:
			detail = "HIRE"
			detail_color = Palette.TEXT_CREAM
		Crew.Result.ALREADY_HIRED:
			detail = "ON YOUR CREW"
			detail_color = Palette.RISK_LOW
		Crew.Result.RANK_TOO_LOW:
			detail = "NEEDS %s" % StreetCred.rank_name(role.min_rank).to_upper()
		Crew.Result.CREW_FULL:
			detail = "CREW FULL"
		Crew.Result.NOT_ENOUGH_CASH:
			detail = "NOT ENOUGH CASH"
	var row: ItemRow = ITEM_ROW.instantiate()
	_list.add_child(row)
	row.show_entry(role.icon, role.display_name, Format.money(role.hire_cost), "%s. %s a day." % [Crew.effects(role), Format.money(role.daily_wage)], detail, detail_color)
	row.item_selected.connect(func(_item: ItemDef) -> void: _talk_about_crew(role))


func _talk_about_crew(role: CrewRoleDef) -> void:
	var run := GameState.run
	var result := Crew.check_hire(run, role.id)
	var line := "I know a %s who could use the work. %s %s up front, then %s every morning." % [role.display_name.to_lower(), role.description, Format.money(role.hire_cost), Format.money(role.daily_wage)]
	var hint := "%s. Miss two mornings of wages and they walk." % Crew.effects(role)
	match result:
		Crew.Result.ALREADY_HIRED:
			line = "Your %s is already working for you. Treat them well." % role.display_name.to_lower()
		Crew.Result.RANK_TOO_LOW:
			line = "Nobody good works for a %s. Come back when people know your name." % StreetCred.rank_name(StreetCred.rank(run)).to_lower()
			hint = "Needs %s." % StreetCred.rank_name(role.min_rank)
		Crew.Result.CREW_FULL:
			hint = "Your crew is full. A bigger safehouse makes room for more."
		Crew.Result.NOT_ENOUGH_CASH:
			hint = "You need %s to hire." % Format.money(role.hire_cost)
	var choices: Array[DialogueChoice] = []
	if result != Crew.Result.ALREADY_HIRED and result != Crew.Result.RANK_TOO_LOW:
		choices.append(DialogueChoice.new(HIRE, "Hire for %s" % Format.money(role.hire_cost), result == Crew.Result.OK))
	choices.append(DialogueChoice.new(LEAVE, "Not now", true, true))
	GameOverlay.talk(_host, line, choices, _on_crew_choice.bind(role), hint)


func _on_crew_choice(choice: StringName, role: CrewRoleDef) -> void:
	if choice != HIRE:
		GameOverlay.end_talk()
		return
	var leave: Array[DialogueChoice] = [DialogueChoice.new(LEAVE, "Leave", true, true)]
	if GameState.hire_crew(role.id) == Crew.Result.OK:
		AudioService.play_sfx(Sfx.COINS_OUT)
		GameOverlay.say("Done. They start today. Pay them on time.", leave, _end_talk)
	else:
		GameOverlay.say("Changed my mind. Come back later.", leave, _end_talk)


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
	var check := Orders.check_accept(GameState.run, order)
	choices.append(DialogueChoice.new(TAKE, "Take the order", check == Orders.Result.OK))
	choices.append(DialogueChoice.new(LEAVE, "Not now", true, true))
	var hint := "Buy the goods at any market, then deliver them at %s's market. Miss the deadline and %s will not trade with you for a phase." % [dealer.display_name, dealer.display_name]
	match check:
		Orders.Result.FULL:
			hint = "You already hold %d orders. Deliver or drop one first." % Orders.MAX_ACTIVE
		Orders.Result.TOO_BIG:
			hint = "That is %d slots of goods. Your bag holds %d." % [Orders.slots_needed(order), Inventory.capacity(GameState.run)]
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
	play_screen_entrance(_header, _scroll)
