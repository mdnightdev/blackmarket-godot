class_name FamiliesSheet
extends BottomSheet

const ITEM_ROW := preload("res://ui/components/item_row.tscn")
const TIER_COLORS := {
	Families.Tier.HOSTILE: Palette.RISK_HIGH,
	Families.Tier.NEUTRAL: Palette.TEXT_MUTED,
	Families.Tier.TRUSTED: Palette.RISK_LOW,
	Families.Tier.FAMILY: Palette.RISK_LOW,
}

@onready var _list: VBoxContainer = %List
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
	super()
	_close_button.pressed.connect(close)
	GameState.run_changed.connect(_on_run_changed)


func open_families() -> void:
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
	for family in Content.families():
		var tier := Families.tier(run, family.id)
		var caption := family.pinyin
		var favour := Favours.active_for(run, family.id)
		if not favour.is_empty():
			var item := Content.item(StringName(favour.item))
			caption = "Owe %d %s by %s" % [int(favour.quantity), item.display_name, Calendar.describe(int(favour.due))]
		var row: ItemRow = ITEM_ROW.instantiate()
		_list.add_child(row)
		var title := "%s %s" % [family.chinese_name, family.english_name]
		row.show_entry(family.emblem, title, "%+d" % Families.standing(run, family.id), caption, Families.tier_name(tier).to_upper(), TIER_COLORS[tier])
