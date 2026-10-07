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

	var stash_open := Inventory.can_use_stash(run)
	_add_section("CARRYING")
	if run.inventory.is_empty():
		_add_note("Your bag is empty.")
	for item_id: StringName in run.inventory:
		var paid := Format.money(int(run.cost_basis.get(item_id, 0)))
		var row := _add_row(Content.item(item_id), "x%d" % run.inventory[item_id], "Paid %s each" % paid, "TAP TO STASH" if stash_open else "")
		if stash_open:
			row.item_selected.connect(_stash_all)

	if Gear.stash_capacity(run) > 0:
		_add_section("STASH  %d / %d" % [Inventory.stash_used(run), Gear.stash_capacity(run)])
		if not stash_open:
			_add_note("Open your stash at the Slums safehouse.")
		elif run.stash.is_empty():
			_add_note("Nothing stored.")
		for item_id: StringName in run.stash:
			var row := _add_row(Content.item(item_id), "x%d" % run.stash[item_id], "Stored", "TAP TO TAKE" if stash_open else "")
			if stash_open:
				row.item_selected.connect(_take_all)

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


func _stash_all(item: ItemDef) -> void:
	GameState.move_to_stash(item, Inventory.max_to_stash(GameState.run, item))


func _take_all(item: ItemDef) -> void:
	GameState.take_from_stash(item, Inventory.max_from_stash(GameState.run, item))
