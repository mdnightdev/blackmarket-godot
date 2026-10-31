class_name QuoteSheet
extends BottomSheet

## Where a customer order could be filled from and what each option clears after fares. Tapping an option
## hands it to CustomerTalk.pick_source.

const JOB_ROW := preload("res://ui/components/job_row.tscn")
const ROW_HEIGHT := 116
const MAX_LIST_HEIGHT := 700
const NOTE_INDENT := 24

@onready var _title_label: Label = %TitleLabel
@onready var _caption_label: Label = %CaptionLabel
@onready var _scroll: ScrollContainer = %Scroll
@onready var _list: VBoxContainer = %List

var _order_id := ""


func _ready() -> void:
	super()
	GameState.run_changed.connect(_on_run_changed)


func open_quotes(order_id: String) -> void:
	_order_id = order_id
	if _rebuild():
		_scroll.scroll_vertical = 0
		open_sheet()


func _on_run_changed() -> void:
	if visible and not _rebuild():
		close()


## False when the order is gone.
func _rebuild() -> bool:
	var run := GameState.run
	var order := Customers.find(run, _order_id)
	Utils.clear_container(_list)
	if order.is_empty():
		return false
	_title_label.text = Customers.job_title(order)
	_caption_label.text = "Pays %s in %s by %s." % [Format.money(Customers.total(order)), Customers.district_name(order), Calendar.describe(int(order.due_stamp)).to_lower()]
	var quotes := CustomerQuotes.quotes(run, order)
	for quote in quotes:
		_add_quote(run, quote)
	if quotes.is_empty():
		_add_note("Nobody in the city sells these right now.")
	_scroll.custom_minimum_size.y = mini(maxi(1, quotes.size()) * ROW_HEIGHT, MAX_LIST_HEIGHT)
	return true


func _add_quote(run: RunState, quote: Dictionary) -> void:
	var is_bag := str(quote.source) == CustomerQuotes.BAG
	var dealer := Content.dealer(StringName(str(quote.source)))
	var icon: Texture2D = ItemsAtlas.get_icon(&"nav_bag") if is_bag or dealer == null else dealer.portrait
	var row: JobRow = JOB_ROW.instantiate()
	_list.add_child(row)
	row.show_job(icon, CustomerQuotes.source_name(quote), CustomerQuotes.profit_text(quote), _caption(run, quote), "")
	row.set_pay_color(_profit_color(quote))
	var warning := CustomerQuotes.warning(quote)
	if not warning.is_empty():
		row.set_hint(warning.to_upper(), Palette.RISK_HIGH)
	elif not is_bag and StringName(str(quote.district)) == run.district_id:
		row.set_hint("HERE", Palette.TEXT_CREAM)
	row.set_tappable(true)
	row.pressed.connect(_pick.bind(quote))


func _caption(run: RunState, quote: Dictionary) -> String:
	var parts: Array[String] = []
	if str(quote.source) != CustomerQuotes.BAG:
		var district := Content.district(StringName(str(quote.district)))
		parts.append(district.display_name if district != null else str(quote.district))
	parts.append(CustomerQuotes.price_text(run, quote))
	var fares := int(quote.fares)
	parts.append("Fares %s" % Format.money(fares) if fares > 0 else "No fares")
	if int(quote.basis_profit) != int(quote.profit):
		parts.append("%s on what you paid" % Format.signed_money(int(quote.basis_profit)))
	return ". ".join(parts)


func _profit_color(quote: Dictionary) -> Color:
	if not bool(quote.known) or int(quote.profit) == 0:
		return Palette.TEXT_MUTED
	return Palette.RISK_LOW if int(quote.profit) > 0 else Palette.RISK_HIGH


func _pick(quote: Dictionary) -> void:
	var order_id := _order_id
	close()
	CustomerTalk.pick_source(order_id, quote)


func _add_note(text: String) -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", NOTE_INDENT)
	margin.add_theme_constant_override("margin_right", NOTE_INDENT)
	var label := Label.new()
	label.theme_type_variation = &"MutedLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	margin.add_child(label)
	_list.add_child(margin)
