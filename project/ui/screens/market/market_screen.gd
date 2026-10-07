extends Control

enum Tab { BUY, SELL, GEAR }

const ITEM_ROW := preload("res://ui/components/item_row.tscn")
const STEADY_CHANGE := 0.005
const TOAST_HOLD_SECONDS := 1.8
const GREETING_DELAY := 0.35
const CLOSING_LINES: Array[String] = [
	"Pleasure doing business.",
	"Done. Don't spend it all at once.",
	"Smart move. Come back soon.",
	"We never met.",
]
const RIVAL_LINE := "Vex's crew is buying around here. I can't pay full price today."
const HANDSHAKE_MIN_TOTAL := 1000

@onready var _background: TextureRect = %Background
@onready var _margin: MarginContainer = %Margin
@onready var _header: Control = %Header
@onready var _portrait: TalkingPortrait = %Portrait
@onready var _dealer_label: Label = %DealerLabel
@onready var _speech: Typewriter = %Speech
@onready var _news_line: NewsLine = %NewsLine
@onready var _mood_label: Label = %MoodLabel
@onready var _order_list: VBoxContainer = %OrderList
@onready var _buy_tab: Button = %BuyTab
@onready var _sell_tab: Button = %SellTab
@onready var _gear_tab: Button = %GearTab
@onready var _notice_label: Label = %NoticeLabel
@onready var _scroll: ScrollContainer = %Scroll
@onready var _list: VBoxContainer = %List
@onready var _back_button: Button = %BackButton
@onready var _bag_button: Button = %BagButton
@onready var _trade_sheet: TradeSheet = %TradeSheet
@onready var _inventory_sheet: InventorySheet = %InventorySheet
@onready var _toast: Label = %Toast
@onready var _deal_flash: DealFlash = %DealFlash

var _dealer: DealerDef
var _tab := Tab.BUY
var _toast_tween: Tween


func _ready() -> void:
	var district: DistrictDef = GameState.current_district() if GameState.run != null else null
	_dealer = _choose_dealer(district.id) if district != null else null
	if _dealer == null:
		SceneRouter.go_to.call_deferred(SceneRouter.TITLE_SCREEN if district == null else SceneRouter.DISTRICT_SCREEN)
		return

	SafeArea.apply_top_margin(_margin, 40)
	_background.texture = district.background
	_dealer_label.text = _dealer.display_name
	_portrait.show_speaker(_dealer)
	_speech.finished.connect(_portrait.set_talking.bind(false))

	var tabs := ButtonGroup.new()
	for tab_button: Button in [_buy_tab, _sell_tab, _gear_tab]:
		tab_button.button_group = tabs
	_buy_tab.button_pressed = true
	_buy_tab.pressed.connect(_select_tab.bind(Tab.BUY))
	_sell_tab.pressed.connect(_select_tab.bind(Tab.SELL))
	_gear_tab.pressed.connect(_select_tab.bind(Tab.GEAR))
	_back_button.pressed.connect(SceneRouter.go_to.bind(SceneRouter.DISTRICT_SCREEN))
	_bag_button.pressed.connect(_inventory_sheet.open_inventory)
	_trade_sheet.completed.connect(_on_trade_completed)
	_trade_sheet.dealer_said.connect(_dealer_says)
	GameState.run_changed.connect(_refresh)

	GameState.clock_active = true
	_refresh()
	_play_entrance()
	get_tree().create_timer(GREETING_DELAY).timeout.connect(_greet)


func _exit_tree() -> void:
	GameState.clock_active = false


func can_present_encounter() -> bool:
	return not _trade_sheet.visible and not _deal_flash.visible


func handle_back() -> bool:
	if _trade_sheet.visible:
		_trade_sheet.close()
	elif _inventory_sheet.visible:
		_inventory_sheet.close()
	else:
		SceneRouter.go_to(SceneRouter.DISTRICT_SCREEN)
	return true


func _choose_dealer(district_id: StringName) -> DealerDef:
	var chosen := Content.dealer(GameState.trading_with)
	GameState.trading_with = &""
	if chosen != null and Roster.dealer_location(GameState.run, chosen, Calendar.stamp(GameState.run)) == district_id:
		return chosen
	return Content.dealer_in(district_id)


func _greet() -> void:
	if not is_inside_tree() or not _dealer_is_here():
		return
	var run := GameState.run
	var rival_here := Roster.rival_in(run, run.district_id, Calendar.stamp(run))
	_dealer_says(RIVAL_LINE if rival_here else _dealer.greeting)


func _dealer_says(line: String) -> void:
	_portrait.set_talking(true)
	_speech.type_text("\"%s\"" % line)


func _on_trade_completed(message: String, cash_delta: int, haggled: bool) -> void:
	_deal_flash.play(cash_delta, haggled or absi(cash_delta) >= HANDSHAKE_MIN_TOTAL)
	_show_toast(message)
	_dealer_says(CLOSING_LINES.pick_random())


func _dealer_is_here() -> bool:
	var run := GameState.run
	return Roster.dealer_location(run, _dealer, Calendar.stamp(run)) == run.district_id


func _select_tab(tab: Tab) -> void:
	_tab = tab
	[_buy_tab, _sell_tab, _gear_tab][tab].button_pressed = true
	_scroll.scroll_vertical = 0
	_refresh()


func _refresh() -> void:
	var run := GameState.run
	var mood := Haggle.mood(run, _dealer)
	_mood_label.text = Haggle.mood_label(mood).to_upper()
	_news_line.show_for(run.district_id)
	_bag_button.text = "Bag %d/%d" % [Inventory.used(run), Inventory.capacity(run)]

	for list in [_list, _order_list]:
		for child: Node in list.get_children():
			list.remove_child(child)
			child.queue_free()
	_order_list.hide()

	if not _dealer_is_here():
		_trade_sheet.close()
		_show_notice("%s has packed up and moved on." % _dealer.display_name)
		return
	if not Market.is_open(run, _dealer):
		_show_notice("%s will not deal with you until next phase." % _dealer.display_name)
		return

	GameState.remember_prices(_dealer)
	_fill_order_list()
	match _tab:
		Tab.BUY:
			_fill_buy_list()
		Tab.SELL:
			_fill_sell_list()
		Tab.GEAR:
			_fill_gear_list()


func _show_notice(text: String) -> void:
	_notice_label.text = text
	_notice_label.visible = not text.is_empty()


func _fill_order_list() -> void:
	var run := GameState.run
	for order in Orders.for_dealer(run, _dealer):
		var item := Content.item(StringName(order.item))
		if item == null:
			continue
		var quantity := int(order.quantity)
		var deliverable := Orders.can_deliver(run, order)
		var held := mini(Inventory.count(run, item.id), quantity)
		var row: ItemRow = ITEM_ROW.instantiate()
		_order_list.add_child(row)
		var caption := "Bar order, %d wanted by %s" % [quantity, Calendar.describe(int(order.due)).to_lower()]
		var detail := "DELIVER" if deliverable else "HAVE %d/%d" % [held, quantity]
		row.display(item, Format.money(Orders.total(order)), caption, detail, Palette.RISK_LOW if deliverable else Palette.TEXT_MUTED)
		row.item_selected.connect(func(_item: ItemDef) -> void: _deliver(order))
	_order_list.visible = _order_list.get_child_count() > 0


func _deliver(order: Dictionary) -> void:
	var item := Content.item(StringName(order.item))
	var total := Orders.total(order)
	if not GameState.deliver_order(order):
		_dealer_says("You're short. I said %d %s, not a handful." % [int(order.quantity), item.display_name])
		return
	_deal_flash.play(total, true)
	_show_toast("Delivered %d %s for %s" % [int(order.quantity), item.display_name, Format.money(total)])
	_dealer_says("Right on time. That's how you stay in business.")


func _fill_buy_list() -> void:
	var run := GameState.run
	for item in Content.items(ItemDef.Kind.TRADE_GOOD):
		if not _dealer.sells(item):
			continue
		var held := Inventory.count(run, item.id)
		var caption := "%s, %s" % [item.category_name(), item.risk_label().to_lower()]
		if held > 0:
			caption = "You have %d, %s" % [held, item.risk_label().to_lower()]
		var change := Market.price_change(run, _dealer, item)
		_add_row(item, Format.money(Market.buy_price(run, _dealer, item)), caption, _change_text(change), _change_color(change))
	_show_notice("")


func _fill_sell_list() -> void:
	var run := GameState.run
	for item in Content.items(ItemDef.Kind.TRADE_GOOD):
		var held := Inventory.count(run, item.id)
		if held == 0:
			continue
		var offer := Market.sell_price(run, _dealer, item)
		var paid := int(run.cost_basis.get(item.id, 0))
		var margin := float(offer - paid) / paid if paid > 0 else 0.0
		var detail := "%+d%% PROFIT" % roundi(margin * 100.0) if margin >= 0.0 else "%d%% LOSS" % roundi(margin * 100.0)
		_add_row(item, Format.money(offer), "You have %d" % held, detail, Palette.RISK_LOW if margin >= 0.0 else Palette.RISK_HIGH)
	_show_notice("" if _list.get_child_count() > 0 else "Nothing in your bag to sell.")


func _fill_gear_list() -> void:
	var run := GameState.run
	for item in Content.items(ItemDef.Kind.EQUIPMENT):
		var owned := Gear.owns(run, item.id)
		_add_row(item, "Owned" if owned else Format.money(item.base_price), Gear.describe(item))
	_show_notice("")


func _add_row(item: ItemDef, price_text: String, caption: String, detail: String = "", detail_color: Color = Palette.TEXT_MUTED) -> void:
	var row: ItemRow = ITEM_ROW.instantiate()
	_list.add_child(row)
	row.display(item, price_text, caption, detail, detail_color)
	row.item_selected.connect(_on_item_selected)


func _change_text(change: float) -> String:
	if absf(change) < STEADY_CHANGE:
		return "STEADY"
	return "%s %d%%" % ["UP" if change > 0.0 else "DOWN", absi(roundi(change * 100.0))]


func _change_color(change: float) -> Color:
	if absf(change) < STEADY_CHANGE:
		return Palette.TEXT_MUTED
	return Palette.PEACH_BRIGHT if change > 0.0 else Palette.PRICE


func _on_item_selected(item: ItemDef) -> void:
	var mode := TradeSheet.Mode.GEAR
	match _tab:
		Tab.BUY:
			mode = TradeSheet.Mode.BUY
		Tab.SELL:
			mode = TradeSheet.Mode.SELL
	_trade_sheet.show_trade(mode, item, _dealer)


func _show_toast(message: String) -> void:
	_toast.text = message
	_toast.reset_size()
	_toast.position.x = (size.x - _toast.size.x) / 2.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.2)
	_toast_tween.tween_interval(TOAST_HOLD_SECONDS)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)


func _play_entrance() -> void:
	_header.modulate.a = 0.0
	_scroll.modulate.a = 0.0
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_header, "modulate:a", 1.0, 0.4)
	tween.tween_property(_scroll, "modulate:a", 1.0, 0.45).set_delay(0.12)
