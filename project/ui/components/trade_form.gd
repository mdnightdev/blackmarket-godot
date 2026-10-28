class_name TradeForm
extends VBoxContainer

## Buying, selling and haggling over one item. The host decides where it lives: the bottom TradeSheet, or open in
## place under the item on the Market.

## cash_delta is positive when the player was paid.
signal completed(message: String, cash_delta: int)
## The dealer's spoken reaction during haggling.
signal dealer_said(line: String)
signal close_requested

enum Mode { BUY, SELL, GEAR }

const WALK_AWAY_CLOSE_SECONDS := 1.4

## Compact forms open inside a list, right under the item's card, so they leave out what the card already shows:
## the picture, name, risk and price. They also drop the quantity slider.
@export var compact := false
@export var closable := false

var _mode: Mode
var _item: ItemDef
var _dealer: DealerDef
var _asking := 0
var _unit_price := 0
var _quantity := 1

@onready var _header: Control = %Header
@onready var _icon: TextureRect = %Icon
@onready var _name_label: Label = %NameLabel
@onready var _caption_label: Label = %CaptionLabel
@onready var _description_label: Label = %DescriptionLabel
@onready var _close_button: Button = %CloseButton
@onready var _price_box: Control = %PriceBox
@onready var _price_caption: Label = %PriceCaption
@onready var _price_value: Label = %PriceValue
@onready var _held_value: Label = %HeldValue
@onready var _paid_box: Control = %PaidBox
@onready var _paid_value: Label = %PaidValue
@onready var _intel_label: Label = %IntelLabel
@onready var _quantity_box: Control = %QuantityBox
@onready var _quantity_label: Label = %QuantityLabel
@onready var _quantity_slider: HSlider = %QuantitySlider
@onready var _minus_button: Button = %MinusButton
@onready var _plus_button: Button = %PlusButton
@onready var _max_button: Button = %MaxButton
@onready var _confirm_button: Button = %ConfirmButton


func _ready() -> void:
	if compact:
		_header.hide()
		_price_box.hide()
		_quantity_slider.hide()
	_close_button.visible = closable
	_close_button.pressed.connect(_on_close_pressed)
	_quantity_slider.value_changed.connect(_on_quantity_changed)
	_minus_button.pressed.connect(_on_minus_pressed)
	_plus_button.pressed.connect(_on_plus_pressed)
	_max_button.pressed.connect(_on_max_pressed)
	_confirm_button.pressed.connect(_confirm)


func show_trade(mode: Mode, item: ItemDef, dealer: DealerDef) -> void:
	_mode = mode
	_item = item
	_dealer = dealer
	match mode:
		Mode.BUY:
			_asking = Market.buy_price(GameState.run, dealer, item)
		Mode.SELL:
			_asking = Market.sell_price(GameState.run, dealer, item)
		Mode.GEAR:
			_asking = item.base_price
	_unit_price = _asking

	_icon.texture = item.icon
	_name_label.text = item.display_name
	_description_label.text = item.description
	_caption_label.text = Gear.describe(item) if item.is_equipment() else "%s, %s" % [item.category_name(), item.risk_label().to_lower()]
	_price_caption.text = "DEALER PAYS" if mode == Mode.SELL else "PRICE"
	_quantity_box.visible = mode != Mode.GEAR

	var held := Inventory.count(GameState.run, item.id)
	var reserved := Inventory.reserved_for_orders(GameState.run, item.id)
	if item.is_equipment():
		_held_value.text = "Owned" if Gear.owns(GameState.run, item.id) else "No"
	elif reserved > 0:
		_held_value.text = "%d (%d reserved)" % [held, reserved]
	else:
		_held_value.text = str(held)
	var paid := int(GameState.run.cost_basis.get(item.id, 0))
	_paid_box.visible = mode == Mode.SELL and paid > 0
	_paid_value.text = Format.money(paid)
	_show_intel()

	_quantity = 1
	_refresh_limits()


func _show_intel() -> void:
	_intel_label.visible = _mode != Mode.GEAR
	if _mode == Mode.GEAR:
		return
	var run := GameState.run
	var sale := PriceIntel.best_sale(run, _item, _dealer)
	if sale.is_empty():
		_intel_label.text = "No prices seen at other dealers yet."
		_intel_label.add_theme_color_override("font_color", Palette.TEXT_MUTED)
		return
	var paying_more := int(sale.sell) > _asking
	var text := "Best seen: %s pays %s, %s." % [_sighting_place(sale), Format.money(int(sale.sell)), PriceIntel.age_text(run, sale)]
	if _mode == Mode.BUY:
		var purchase := PriceIntel.best_purchase(run, _item, _dealer)
		if not purchase.is_empty() and int(purchase.buy) < _asking:
			text += " Cheaper at %s: %s." % [_sighting_place(purchase), Format.money(int(purchase.buy))]
	_intel_label.text = text
	_intel_label.add_theme_color_override("font_color", Palette.RISK_LOW if paying_more else Palette.TEXT_MUTED)


func _sighting_place(sighting: Dictionary) -> String:
	var dealer := Content.dealer(StringName(sighting.dealer))
	var district := Content.district(StringName(sighting.district))
	var dealer_name := dealer.display_name if dealer != null else "A dealer"
	return "%s in %s" % [dealer_name, district.display_name] if district != null else dealer_name


func _max_quantity() -> int:
	match _mode:
		Mode.BUY:
			return Trade.max_buyable(GameState.run, _item, _unit_price)
		Mode.SELL:
			return Trade.max_sellable(GameState.run, _item)
	return 1


func _refresh_limits() -> void:
	var limit := _max_quantity()
	_quantity_slider.min_value = 1
	_quantity_slider.max_value = maxi(1, limit)
	_quantity_slider.editable = limit > 1
	_set_quantity(clampi(_quantity, 1, maxi(1, limit)))


func _set_quantity(value: int) -> void:
	var limit := _max_quantity()
	if limit <= 0 and _mode == Mode.SELL:
		_quantity = 0
		_quantity_slider.set_value_no_signal(1)
		_quantity_label.text = "0"
		_minus_button.disabled = true
		_plus_button.disabled = true
		_max_button.disabled = true
		_refresh_price_and_action()
		return
	var max_val := maxi(1, limit)
	_quantity = clampi(value, 1, max_val)
	_quantity_slider.set_value_no_signal(_quantity)
	_quantity_label.text = str(_quantity)
	_minus_button.disabled = _quantity <= 1
	_plus_button.disabled = _quantity >= limit
	_max_button.disabled = _quantity >= limit
	_refresh_price_and_action()


func _refresh_price_and_action() -> void:
	_price_value.text = Format.money(_unit_price)
	var total := _unit_price * _quantity
	match _mode:
		Mode.BUY:
			var check := Trade.check_buy(GameState.run, _item, _quantity, _unit_price)
			_confirm_button.disabled = check != Trade.Result.OK
			_confirm_button.text = _blocked_text(check, "Buy %d for %s" % [_quantity, Format.money(total)])
		Mode.SELL:
			var sellable := Trade.max_sellable(GameState.run, _item)
			if sellable <= 0:
				_confirm_button.disabled = true
				_confirm_button.text = "Reserved for order"
			else:
				var check := Trade.check_sell(GameState.run, _item, _quantity)
				if _quantity > sellable:
					check = Trade.Result.NOT_ENOUGH_UNITS
				_confirm_button.disabled = check != Trade.Result.OK
				_confirm_button.text = _blocked_text(check, "Sell %d for %s" % [_quantity, Format.money(total)])
		Mode.GEAR:
			var check := Trade.check_gear(GameState.run, _item)
			_confirm_button.disabled = check != Trade.Result.OK
			_confirm_button.text = _blocked_text(check, "Buy for %s" % Format.money(_unit_price))


func _blocked_text(result: Trade.Result, ready_text: String) -> String:
	match result:
		Trade.Result.NOT_ENOUGH_CASH:
			return "Not enough cash"
		Trade.Result.NO_SPACE:
			return "Bag is full"
		Trade.Result.OVER_CAPACITY:
			return "Bag over capacity"
		Trade.Result.ALREADY_OWNED:
			return "Owned"
		Trade.Result.RANK_TOO_LOW:
			return "Rank too low"
		Trade.Result.NOT_ENOUGH_UNITS, Trade.Result.INVALID_QUANTITY:
			return "Nothing to sell"
	return ready_text


func _confirm() -> void:
	var total := _unit_price * _quantity
	var result: Trade.Result
	var message := ""
	var cash_delta := -total
	match _mode:
		Mode.BUY:
			result = GameState.buy(_item, _quantity, _unit_price)
			message = "Bought %d %s for %s" % [_quantity, _item.display_name, Format.money(total)]
		Mode.SELL:
			result = GameState.sell(_item, _quantity, _unit_price)
			message = "Sold %d %s for %s" % [_quantity, _item.display_name, Format.money(total)]
			cash_delta = total
		Mode.GEAR:
			result = GameState.buy_gear(_item)
			message = "%s bought" % _item.display_name
			cash_delta = -_unit_price
	if result == Trade.Result.OK:
		completed.emit(message, cash_delta)
	else:
		_refresh_limits()


func _on_close_pressed() -> void:
	close_requested.emit()


func _on_quantity_changed(value: float) -> void:
	_set_quantity(int(value))


func _on_minus_pressed() -> void:
	_set_quantity(_quantity - 1)


func _on_plus_pressed() -> void:
	_set_quantity(_quantity + 1)


func _on_max_pressed() -> void:
	_set_quantity(_max_quantity())
