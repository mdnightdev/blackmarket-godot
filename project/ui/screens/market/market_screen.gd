extends BaseScreen

enum Tab { BUY, SELL }

const ITEM_ROW := preload("res://ui/components/item_row.tscn")
const ITEM_CARD := preload("res://ui/components/item_card.tscn")
const CARDS_PER_ROW := 2
const CARD_SPACING := 10
const SELECTED_CARD: StringName = &"ItemCardSelected"
const STEADY_CHANGE := 0.005
## Item risk where the card caption turns from green to amber, and from amber to red. Matches ItemDef.risk_label.
const RISK_MEDIUM := 20
const RISK_HIGH := 35
const TOAST_HOLD_SECONDS := 1.8
const GREETING_DELAY := 0.35
const PLAYER_TURF_LINE := "Your people run this block now. You get the best price in town."
const FAMILY_LINES := {
	Families.Tier.HOSTILE: "You made enemies of my family. I have nothing to sell you.",
	Families.Tier.TRUSTED: "The family speaks well of you. I can do better on price.",
	Families.Tier.FAMILY: "For family, the family price.",
}
const HANDSHAKE_MIN_TOTAL := 1000

@onready var _background: TextureRect = %Background
@onready var _margin: MarginContainer = %Margin
@onready var _header: Control = %Header
@onready var _portrait: TalkingPortrait = %Portrait
@onready var _dealer_label: Label = %DealerLabel
@onready var _family_label: Label = %FamilyLabel
@onready var _speech: Typewriter = %Speech
@onready var _news_line: NewsLine = %NewsLine
@onready var _mood_label: Label = %MoodLabel
@onready var _district_pill: Label = %DistrictPill
@onready var _bag_bar: ProgressBar = %BagBar
@onready var _order_list: VBoxContainer = %OrderList
@onready var _buy_tab: Button = %BuyTab
@onready var _sell_tab: Button = %SellTab
@onready var _notice_label: Label = %NoticeLabel
@onready var _scroll: ScrollContainer = %Scroll
@onready var _list: VBoxContainer = %List
@onready var _back_button: Button = %BackButton
@onready var _bag_button: Button = %BagButton
@onready var _trade_panel: Control = %TradePanel
@onready var _trade_form: TradeForm = %TradeForm
@onready var _toast: Label = %Toast
@onready var _deal_flash: DealFlash = %DealFlash

var _dealer: DealerDef
var _tab := Tab.BUY
var _selected: ItemDef
var _toast_tween: Tween


func _ready() -> void:
	var district: DistrictDef = GameState.current_district() if GameState.run != null else null
	_dealer = _choose_dealer(district.id) if district != null else null
	if _dealer == null:
		SceneRouter.go_to.call_deferred(SceneRouter.TITLE_SCREEN if district == null else SceneRouter.DISTRICT_SCREEN)
		return

	SafeArea.apply_top_margin(_margin, 64)
	_background.texture = district.background
	_dealer_label.text = _dealer.display_name
	_district_pill.text = district.display_name
	_portrait.show_speaker(_dealer)
	_speech.finished.connect(_portrait.set_talking.bind(false))

	var tabs := ButtonGroup.new()
	for tab_button: Button in [_buy_tab, _sell_tab]:
		tab_button.button_group = tabs
	_buy_tab.button_pressed = true
	_buy_tab.pressed.connect(_on_buy_tab_pressed)
	_sell_tab.pressed.connect(_on_sell_tab_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_bag_button.pressed.connect(GameOverlay.open_bag)
	_trade_form.completed.connect(_on_trade_completed)
	_trade_form.dealer_said.connect(_dealer_says)
	_trade_form.close_requested.connect(_close_trade)
	_trade_panel.resized.connect(_keep_trade_in_view)
	GameState.run_changed.connect(_refresh)

	GameState.clock_active = true
	_refresh()
	_play_entrance()
	get_tree().create_timer(GREETING_DELAY).timeout.connect(_greet)


func _exit_tree() -> void:
	GameState.clock_active = false
	if _trade_panel.get_parent() == null:
		_trade_panel.queue_free()


func can_present_encounter() -> bool:
	return _selected == null and not _deal_flash.visible


func handle_back() -> bool:
	if _selected != null:
		_close_trade()
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
	if Lending.is_dealer_locked_down(GameState.run, _dealer.id):
		_dealer_says("Stall is shuttered. The Shark's men broke the place up. Come back later.")
		return
	var family := Families.family_of(_dealer)
	if family != null and FAMILY_LINES.has(Families.tier(GameState.run, family.id)):
		_dealer_says(FAMILY_LINES[Families.tier(GameState.run, family.id)])
		return
	match Turf.holder(GameState.run, GameState.run.district_id):
		Turf.Holder.GANG:
			_dealer_says(Gangs.owner(GameState.run.district_id).dealer_line)
		Turf.Holder.PLAYER:
			_dealer_says(PLAYER_TURF_LINE)
		_:
			_dealer_says(_dealer.greeting)


func _dealer_says(line: String) -> void:
	_portrait.set_talking(true)
	_speech.type_text("\"%s\"" % line)


func _on_trade_completed(message: String, cash_delta: int) -> void:
	_close_trade()
	_deal_flash.play(cash_delta, absi(cash_delta) >= HANDSHAKE_MIN_TOTAL)
	_show_toast(message)
	_dealer_says(TierVoice.pick(TierVoice.CLOSING, _dealer.tier))


func _dealer_is_here() -> bool:
	var run := GameState.run
	return Roster.dealer_location(run, _dealer, Calendar.stamp(run)) == run.district_id


func _select_tab(tab: Tab) -> void:
	_tab = tab
	_selected = null
	[_buy_tab, _sell_tab][tab].button_pressed = true
	_scroll.scroll_vertical = 0
	_refresh()


func _on_buy_tab_pressed() -> void:
	_select_tab(Tab.BUY)


func _on_sell_tab_pressed() -> void:
	_select_tab(Tab.SELL)


func _on_back_pressed() -> void:
	SceneRouter.go_to(SceneRouter.DISTRICT_SCREEN)


func _refresh() -> void:
	var run := GameState.run
	_mood_label.visible = false
	_news_line.show_for(run.district_id)
	_bag_button.text = Inventory.bag_text(run)
	_bag_bar.max_value = Inventory.capacity(run)
	_bag_bar.value = Inventory.used(run)
	var family := Families.family_of(_dealer)
	_family_label.visible = family != null
	if family != null:
		_family_label.text = "%s · %s" % [family.full_name(), Families.tier_name(Families.tier(run, family.id))]

	for list in [_list, _order_list]:
		for child: Node in list.get_children():
			list.remove_child(child)
			if child != _trade_panel:
				child.queue_free()
	_order_list.hide()

	if not _dealer_is_here():
		_selected = null
		_show_notice("%s has packed up and moved on." % _dealer.display_name)
		return
	if Families.refuses(run, _dealer):
		_selected = null
		_show_notice("%s works for the %s. The family will not deal with you." % [_dealer.display_name, family.english_name])
		return
	if Lending.is_dealer_locked_down(run, _dealer.id):
		_selected = null
		var days_left := maxi(1, int(run.dealer_lockdowns.get(_dealer.id, 0)) - run.day)
		_show_notice("%s's stall is locked down by the Shark. Reopens in %d day(s)." % [_dealer.display_name, days_left])
		return
	if not Market.is_open(run, _dealer):
		_selected = null
		_show_notice("%s will not deal with you until next phase." % _dealer.display_name)
		return

	GameState.remember_prices(_dealer)
	_fill_order_list()
	var cards := _buy_cards() if _tab == Tab.BUY else _sell_cards()
	_lay_out(cards)


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
		row.item_selected.connect(_on_order_selected.bind(order))
	_order_list.visible = _order_list.get_child_count() > 0


func _on_order_selected(_item: ItemDef, order: Dictionary) -> void:
	_deliver(order)


func _deliver(order: Dictionary) -> void:
	var item := Content.item(StringName(order.item))
	var total := Orders.total(order)
	if not GameState.deliver_order(order):
		_dealer_says(TierVoice.pick(TierVoice.SHORT, _dealer.tier) % [int(order.quantity), item.display_name])
		return
	_deal_flash.play(total, true)
	_show_toast("Delivered %d %s for %s" % [int(order.quantity), item.display_name, Format.money(total)])
	_dealer_says(TierVoice.pick(TierVoice.DELIVERED, _dealer.tier))


func _buy_cards() -> Array[Dictionary]:
	var run := GameState.run
	var cards: Array[Dictionary] = []
	for item in Content.items(ItemDef.Kind.TRADE_GOOD):
		if not _dealer.sells(item):
			continue
		if not Trade.rank_allows(run, item):
			cards.append(_card(item, "", "Needs %s" % StreetCred.rank_name(item.min_rank), "LOCKED"))
			continue
		var held := Inventory.count(run, item.id)
		var caption := item.risk_label() if held == 0 else "You have %d, %s" % [held, item.risk_label().to_lower()]
		var change := Market.price_change(run, _dealer, item)
		var card := _card(item, Format.money(Market.buy_price(run, _dealer, item)), caption, _change_text(change), _change_color(change))
		card.trend = 0 if absf(change) < STEADY_CHANGE else (1 if change > 0.0 else -1)
		card.caption_color = _risk_color(item)
		cards.append(card)
	_show_notice("")
	return cards


func _sell_cards() -> Array[Dictionary]:
	var run := GameState.run
	var cards: Array[Dictionary] = []
	for item in Content.items(ItemDef.Kind.TRADE_GOOD):
		var held := Inventory.count(run, item.id)
		if held == 0:
			continue
		if not _dealer.deals_in(item):
			cards.append(_card(item, "", "You have %d" % held, "WON'T BUY"))
			continue
		var reserved := Inventory.reserved_for_orders(run, item.id)
		var sellable := Inventory.sellable_count(run, item.id)
		var offer := Market.sell_price(run, _dealer, item)
		var paid := int(run.cost_basis.get(item.id, 0))
		var margin := float(offer - paid) / paid if paid > 0 else 0.0
		var detail := "%+d%%" % roundi(margin * 100.0)

		var caption := "You have %d" % held
		if reserved > 0:
			caption = "%d held (%d reserved)" % [held, reserved]

		if sellable == 0:
			cards.append(_card(item, Format.money(offer), caption, "RESERVED", Palette.TEXT_MUTED))
		else:
			cards.append(_card(item, Format.money(offer), caption, detail, Palette.RISK_LOW if margin >= 0.0 else Palette.RISK_HIGH))
	_show_notice("" if not cards.is_empty() else "Nothing in your bag to sell.")
	return cards


func _card(item: ItemDef, price_text: String, caption: String, detail := "", detail_color := Palette.TEXT_MUTED) -> Dictionary:
	return { "item": item, "price": price_text, "caption": caption, "detail": detail, "color": detail_color, "trend": 0, "caption_color": Palette.TEXT_MUTED }


## Two cards to a row. The open trade sits under the row of the card it belongs to.
func _lay_out(cards: Array[Dictionary]) -> void:
	var trade_shown := false
	for start in range(0, cards.size(), CARDS_PER_ROW):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", CARD_SPACING)
		_list.add_child(row)
		var holds_selected := false
		for entry in cards.slice(start, start + CARDS_PER_ROW):
			var card: ItemCard = ITEM_CARD.instantiate()
			row.add_child(card)
			card.display(entry.item, entry.price, entry.caption, entry.detail, entry.color)
			card.show_trend(entry.trend, entry.color)
			card.tint_caption(entry.caption_color)
			card.item_selected.connect(_on_item_selected)
			if entry.item == _selected:
				card.theme_type_variation = SELECTED_CARD
				holds_selected = true
		if row.get_child_count() < CARDS_PER_ROW:
			var filler := Control.new()
			filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(filler)
		if holds_selected:
			_list.add_child(_trade_panel)
			trade_shown = true
	_trade_panel.visible = trade_shown
	if not trade_shown:
		_selected = null


func _change_text(change: float) -> String:
	if absf(change) < STEADY_CHANGE:
		return "STEADY"
	return "%d%%" % absi(roundi(change * 100.0))


func _risk_color(item: ItemDef) -> Color:
	if item.risk < RISK_MEDIUM:
		return Palette.RISK_LOW
	if item.risk < RISK_HIGH:
		return Palette.TEXT_MUTED
	return Palette.RISK_HIGH


func _change_color(change: float) -> Color:
	if absf(change) < STEADY_CHANGE:
		return Palette.TEXT_MUTED
	return Palette.TEXT_CREAM if change > 0.0 else Palette.PRICE


func _on_item_selected(item: ItemDef) -> void:
	if not _dealer.deals_in(item):
		_dealer_says(Tiers.refusal(_dealer, item))
		return
	if _tab == Tab.BUY and not Trade.rank_allows(GameState.run, item):
		_dealer_says("%s? I sell those to a %s, not to you. Not yet." % [item.display_name, StreetCred.rank_name(item.min_rank)])
		return
	if item == _selected:
		_close_trade()
		return
	_selected = item
	var mode := TradeForm.Mode.BUY if _tab == Tab.BUY else TradeForm.Mode.SELL
	_trade_form.show_trade(mode, item, _dealer)
	_refresh()
	_keep_trade_in_view()


## The form opens under its card and grows when haggling opens, so the card and the form's buttons are scrolled
## back on screen.
func _keep_trade_in_view() -> void:
	await get_tree().process_frame
	if _selected == null or not _trade_panel.is_inside_tree():
		return
	_scroll.ensure_control_visible(_trade_panel)
	_scroll.ensure_control_visible(_list.get_child(_trade_panel.get_index() - 1))


func _close_trade() -> void:
	if _selected == null:
		return
	_selected = null
	_refresh()


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
	play_screen_entrance(_header, _scroll)
