class_name JobsSheet
extends BottomSheet

const JOB_ROW := preload("res://ui/components/job_row.tscn")
const READY_HINT := "IN BAG"

@onready var _margin: MarginContainer = %Margin
@onready var _back_button: Button = %BackButton
@onready var _scroll: ScrollContainer = %Scroll
@onready var _list: VBoxContainer = %List
@onready var _empty_label: Label = %EmptyLabel


func _ready() -> void:
	super()
	_back_button.pressed.connect(close)
	GameState.run_changed.connect(_on_run_changed)


func open_jobs() -> void:
	SafeArea.apply_top_margin(_margin, 24)
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

	for order in run.orders:
		var item := Content.item(StringName(order.item))
		var dealer := Content.dealer(StringName(order.dealer))
		if item == null or dealer == null:
			continue
		var district := Content.district(dealer.district_id)
		var place := " in %s" % district.display_name if district != null else ""
		var caption := "For %s%s by %s" % [dealer.display_name, place, Calendar.describe(int(order.due)).to_lower()]
		_add_row(item.icon, "%d %s" % [int(order.quantity), item.display_name], Format.money(Orders.total(order)), caption, READY_HINT if Orders.can_deliver(run, order) else "")

	for favour in run.favours:
		var item := Content.item(StringName(favour.item))
		var family := Content.family(StringName(favour.family))
		var lieutenant := Content.character(family.lieutenant) if family != null else null
		if item == null or lieutenant == null:
			continue
		var caption := "For %s by %s" % [lieutenant.display_name, Calendar.describe(int(favour.due)).to_lower()]
		_add_row(item.icon, "%d %s" % [int(favour.quantity), item.display_name], Format.money(Favours.total(favour)), caption, READY_HINT if Favours.can_deliver(run, favour) else "")

	if Smuggling.is_carrying(run):
		var hint := "DELIVER HERE" if Smuggling.can_deliver(run) else ""
		_add_row(Smuggling.CRATE_ICON, "Voronin's crate", Format.money(int(run.crate.pay)), Smuggling.describe(run.crate), hint)

	_empty_label.visible = _list.get_child_count() == 0
	_scroll.visible = not _empty_label.visible


func _add_row(icon: Texture2D, title: String, pay: String, caption: String, hint: String) -> void:
	var row: JobRow = JOB_ROW.instantiate()
	_list.add_child(row)
	row.show_job(icon, title, pay, caption, hint)
