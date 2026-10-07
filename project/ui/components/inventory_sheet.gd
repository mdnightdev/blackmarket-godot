class_name InventorySheet
extends BottomSheet

enum Tab { CARRYING, STASH, GEAR }

const BAG_TILE := preload("res://ui/components/bag_tile.tscn")

@onready var _margin: MarginContainer = %Margin
@onready var _back_button: Button = %BackButton
@onready var _capacity_label: Label = %CapacityLabel
@onready var _carrying_tab: Button = %CarryingTab
@onready var _stash_tab: Button = %StashTab
@onready var _gear_tab: Button = %GearTab
@onready var _grid: GridContainer = %Grid
@onready var _empty_label: Label = %EmptyLabel
@onready var _detail: Control = %Detail
@onready var _detail_icon: TextureRect = %DetailIcon
@onready var _detail_title: Label = %DetailTitle
@onready var _detail_meta: Label = %DetailMeta
@onready var _detail_text: Label = %DetailText

var _tab := Tab.CARRYING
var _selected_title := ""


func _ready() -> void:
	super()
	_back_button.pressed.connect(close)
	var tabs := ButtonGroup.new()
	for tab_button: Button in [_carrying_tab, _stash_tab, _gear_tab]:
		tab_button.button_group = tabs
	_carrying_tab.pressed.connect(_select_tab.bind(Tab.CARRYING))
	_stash_tab.pressed.connect(_select_tab.bind(Tab.STASH))
	_gear_tab.pressed.connect(_select_tab.bind(Tab.GEAR))
	GameState.run_changed.connect(_on_run_changed)


func open_inventory() -> void:
	SafeArea.apply_top_margin(_margin, 24)
	_tab = Tab.CARRYING
	_carrying_tab.button_pressed = true
	_selected_title = ""
	_rebuild()
	open_sheet()


func _on_run_changed() -> void:
	if visible:
		_rebuild.call_deferred()


func _select_tab(tab: Tab) -> void:
	_tab = tab
	_selected_title = ""
	_rebuild()


func _rebuild() -> void:
	var run := GameState.run
	_stash_tab.visible = Safehouse.stash_capacity(run) > 0
	_gear_tab.visible = not Gear.owned_items(run).is_empty()
	if (_tab == Tab.STASH and not _stash_tab.visible) or (_tab == Tab.GEAR and not _gear_tab.visible):
		_tab = Tab.CARRYING
		_carrying_tab.button_pressed = true

	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()

	match _tab:
		Tab.CARRYING:
			_capacity_label.text = "%d / %d" % [Inventory.used(run), Inventory.capacity(run)]
			_empty_label.text = "Your bag is empty."
			if Smuggling.is_carrying(run):
				_add_tile(Smuggling.CRATE_ICON, "", "Voronin's crate", "%d slots. Do not open." % Smuggling.slots_used(run), Smuggling.describe(run.crate))
			for item_id: StringName in run.inventory:
				var item := Content.item(item_id)
				var paid := Format.money(int(run.cost_basis.get(item_id, 0)))
				_add_tile(item.icon, "x%d" % run.inventory[item_id], item.display_name, "Paid %s each" % paid, item.description)
		Tab.STASH:
			_capacity_label.text = "%d / %d" % [Inventory.stash_used(run), Safehouse.stash_capacity(run)]
			_empty_label.text = "Your stash is empty. Move goods in and out at the Slums safehouse."
			for item_id: StringName in run.stash:
				var item := Content.item(item_id)
				_add_tile(item.icon, "x%d" % run.stash[item_id], item.display_name, "Stored, safe from raids", item.description)
		Tab.GEAR:
			_capacity_label.text = ""
			_empty_label.text = ""
			for item in Gear.owned_items(run):
				_add_tile(item.icon, "", item.display_name, Gear.describe(item), item.description)

	_empty_label.visible = _grid.get_child_count() == 0
	_select_tile(_find_tile(_selected_title))


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
