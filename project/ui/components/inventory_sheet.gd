class_name InventorySheet
extends BottomSheet

const ITEM_ROW := preload("res://ui/components/item_row.tscn")

@onready var _capacity_label: Label = %CapacityLabel
@onready var _list: VBoxContainer = %List
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
	super()
	_close_button.pressed.connect(close)
	GameState.run_changed.connect(_on_run_changed)


func open_inventory() -> void:
	_rebuild()
	open_sheet()


func _on_run_changed() -> void:
	if visible:
		_rebuild.call_deferred()


func _rebuild() -> void:
	var run := GameState.run
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_capacity_label.text = "%d / %d slots" % [Inventory.used(run), Inventory.capacity(run)]

	_add_section("CARRYING")
	if run.inventory.is_empty() and not Smuggling.is_carrying(run):
		_add_note("Your bag is empty.")
	if Smuggling.is_carrying(run):
		var row: ItemRow = ITEM_ROW.instantiate()
		_list.add_child(row)
		row.show_entry(Smuggling.CRATE_ICON, "Voronin's crate", "%d slots" % Smuggling.slots_used(run), Smuggling.describe(run.crate), "DO NOT OPEN", Palette.PEACH_BRIGHT)
	for item_id: StringName in run.inventory:
		var paid := Format.money(int(run.cost_basis.get(item_id, 0)))
		_add_row(Content.item(item_id), "x%d" % run.inventory[item_id], "Paid %s each" % paid)

	if Safehouse.stash_capacity(run) > 0:
		_add_section("STASH  %d / %d" % [Inventory.stash_used(run), Safehouse.stash_capacity(run)])
		_add_note("Move goods in and out at the Slums safehouse.")
		for item_id: StringName in run.stash:
			_add_row(Content.item(item_id), "x%d" % run.stash[item_id], "Stored")

	var owned_gear := Gear.owned_items(run)
	if not owned_gear.is_empty():
		_add_section("GEAR")
		for item in owned_gear:
			_add_row(item, "", Gear.describe(item))


func _add_section(text: String) -> void:
	var label := Label.new()
	label.theme_type_variation = &"SectionLabel"
	label.text = text
	_list.add_child(label)


func _add_note(text: String) -> void:
	var label := Label.new()
	label.theme_type_variation = &"MutedLabel"
	label.text = text
	_list.add_child(label)


func _add_row(item: ItemDef, price_text: String, caption: String, action_hint: String = "") -> ItemRow:
	var row: ItemRow = ITEM_ROW.instantiate()
	_list.add_child(row)
	row.display(item, price_text, caption, action_hint, Palette.PEACH_BRIGHT)
	return row
