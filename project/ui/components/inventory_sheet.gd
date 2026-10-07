class_name InventorySheet
extends BottomSheet

const BAG_TILE := preload("res://ui/components/bag_tile.tscn")

@onready var _margin: MarginContainer = %Margin
@onready var _capacity_label: Label = %CapacityLabel
@onready var _grid: GridContainer = %Grid
@onready var _empty_label: Label = %EmptyLabel
@onready var _detail: Control = %Detail
@onready var _detail_icon: TextureRect = %DetailIcon
@onready var _detail_title: Label = %DetailTitle
@onready var _detail_meta: Label = %DetailMeta
@onready var _detail_text: Label = %DetailText

var _selected_title := ""


func _ready() -> void:
	super()
	GameState.run_changed.connect(_on_run_changed)


func open_inventory() -> void:
	SafeArea.apply_top_margin(_margin, 24)
	_selected_title = ""
	_rebuild()
	open_sheet()


func _on_run_changed() -> void:
	if visible:
		_rebuild.call_deferred()


func _rebuild() -> void:
	var run := GameState.run
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()

	_capacity_label.text = "%d / %d" % [Inventory.used(run), Inventory.capacity(run)]
	if Smuggling.is_carrying(run):
		_add_tile(Smuggling.CRATE_ICON, "", "Voronin's crate", "%d slots. Do not open." % Smuggling.slots_used(run), Smuggling.describe(run.crate))
	for item_id: StringName in run.inventory:
		var item := Content.item(item_id)
		var paid := Format.money(int(run.cost_basis.get(item_id, 0)))
		_add_tile(item.icon, "x%d" % run.inventory[item_id], item.display_name, "Paid %s each" % paid, item.description)
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
