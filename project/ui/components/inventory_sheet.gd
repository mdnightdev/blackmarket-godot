class_name InventorySheet
extends BottomSheet

const BAG_TILE := preload("res://ui/components/bag_tile.tscn")

enum Filter { ALL, GOODS, GEAR }

@onready var _margin: MarginContainer = %Margin
@onready var _capacity_label: Label = %CapacityLabel
@onready var _capacity_bar: ProgressBar = %CapacityBar
@onready var _all_tab: Button = %AllTab
@onready var _goods_tab: Button = %GoodsTab
@onready var _gear_tab: Button = %GearTab
@onready var _grid: GridContainer = %Grid
@onready var _empty_label: Label = %EmptyLabel
@onready var _detail: Control = %Detail
@onready var _detail_icon: TextureRect = %DetailIcon
@onready var _detail_title: Label = %DetailTitle
@onready var _detail_meta: Label = %DetailMeta
@onready var _detail_text: Label = %DetailText
@onready var _sell_button: Button = %SellButton
@onready var _trade_sheet: TradeSheet = %TradeSheet

var _selected_title := ""
## Tile title to the trade good it shows. Gear and the crate are not listed, so they cannot be sold from here.
var _goods_by_title: Dictionary = {}
var _buyer: DealerDef
var _filter := Filter.ALL


func _ready() -> void:
	super()
	GameState.run_changed.connect(_on_run_changed)
	_sell_button.pressed.connect(_on_sell_pressed)
	var tabs := ButtonGroup.new()
	for tab_button: Button in [_all_tab, _goods_tab, _gear_tab]:
		tab_button.button_group = tabs
	_all_tab.pressed.connect(_select_filter.bind(Filter.ALL))
	_goods_tab.pressed.connect(_select_filter.bind(Filter.GOODS))
	_gear_tab.pressed.connect(_select_filter.bind(Filter.GEAR))


func close_modal() -> bool:
	if _trade_sheet.visible:
		_trade_sheet.close()
		return true
	return false


func open_inventory() -> void:
	SafeArea.apply_top_margin(_margin)
	_selected_title = ""
	_filter = Filter.ALL
	_all_tab.button_pressed = true
	_rebuild()
	open_sheet()


func _select_filter(filter: Filter) -> void:
	_filter = filter
	_selected_title = ""
	_rebuild()


func _on_run_changed() -> void:
	if visible:
		_rebuild.call_deferred()


func _rebuild() -> void:
	var run := GameState.run
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_goods_by_title.clear()

	_capacity_label.text = "%d / %d" % [Inventory.used(run), Inventory.capacity(run)]
	_capacity_bar.max_value = maxi(1, Inventory.capacity(run))
	_capacity_bar.value = mini(Inventory.used(run), Inventory.capacity(run))
	if Inventory.over_capacity(run) > 0:
		_capacity_label.add_theme_color_override("font_color", Palette.RISK_HIGH)
	else:
		_capacity_label.remove_theme_color_override("font_color")
	if _filter != Filter.GEAR:
		_add_goods(run)
	if _filter != Filter.GOODS:
		for item in Gear.owned_items(run):
			_add_tile(item.icon, "", item.display_name, Gear.describe(item), item.description)

	_empty_label.visible = _grid.get_child_count() == 0
	_select_tile(_find_tile(_selected_title))


func _add_goods(run: RunState) -> void:
	if Smuggling.is_carrying(run):
		_add_tile(Smuggling.CRATE_ICON, "", "Voronin's crate", "%d slots. Do not open." % Smuggling.slots_used(run), Smuggling.describe(run.crate))
	for item_id: StringName in run.inventory:
		var item := Content.item(item_id)
		var paid := Format.money(int(run.cost_basis.get(item_id, 0)))
		_add_tile(item.icon, "x%d" % run.inventory[item_id], item.display_name, "Paid %s each" % paid, item.description)
		_goods_by_title[item.display_name] = item


func _add_tile(icon: Texture2D, count_text: String, title: String, meta: String, description: String) -> void:
	var tile: BagTile = BAG_TILE.instantiate()
	_grid.add_child(tile)
	tile.show_entry(icon, count_text, title, meta, description)
	tile.tile_selected.connect(_select_tile)


func _find_tile(title: String) -> BagTile:
	for tile: BagTile in _grid.get_children():
		if tile.title == title:
			return tile
	return _grid.get_child(0) if _grid.get_child_count() > 0 else null


func _select_tile(selected: BagTile) -> void:
	for tile: BagTile in _grid.get_children():
		tile.set_selected(tile == selected)
	_detail.visible = selected != null
	if selected == null:
		_selected_title = ""
		return
	_selected_title = selected.title
	_detail_icon.texture = selected.artwork
	_detail_title.text = selected.title
	_detail_meta.text = selected.meta
	_detail_text.text = selected.description
	_show_sell_button(_goods_by_title.get(selected.title))


func _show_sell_button(item: ItemDef) -> void:
	_sell_button.visible = item != null
	if item == null:
		return
	var run := GameState.run
	_buyer = Market.best_local_buyer(run, item)
	_sell_button.disabled = _buyer == null
	if _buyer == null:
		_sell_button.text = "Nobody here is buying"
	else:
		_sell_button.text = "Sell to %s, %s each" % [_buyer.display_name, Format.money(Market.sell_price(run, _buyer, item))]


func _on_sell_pressed() -> void:
	var item: ItemDef = _goods_by_title.get(_selected_title)
	if item != null and _buyer != null:
		_trade_sheet.show_trade(TradeForm.Mode.SELL, item, _buyer)
