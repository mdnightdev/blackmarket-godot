class_name ItemDef
extends Resource

const ItemsAtlasClass := preload("res://scripts/core/items_atlas.gd")

enum Kind { TRADE_GOOD, EQUIPMENT }

@export var id: StringName
@export var display_name: String
@export var kind: Kind = Kind.TRADE_GOOD
@export var category: StringName
@export_range(1, 10_000_000) var base_price: int = 100
@export_range(0, 100) var risk: int = 10
@export_range(1, 50) var slots: int = 1
## 1 street, 2 middle class, 3 wealthy. Dealers trade their own tier and the one below.
@export_range(1, 3) var tier: int = 1
## Street rank a player needs before anyone sells it to them. Jobs never ask for these goods.
@export_range(0, 10) var min_rank: int = 0
@export_multiline var description: String
@export var icon: Texture2D:
	get:
		if icon != null:
			return icon
		return ItemsAtlasClass.get_icon(id)


func get_icon() -> Texture2D:
	return icon

@export_group("Equipment")
@export_range(0, 500) var capacity_bonus: int = 0
@export_range(0.0, 1.0, 0.01) var fare_discount: float = 0.0


func is_equipment() -> bool:
	return kind == Kind.EQUIPMENT


func is_restricted() -> bool:
	return min_rank > 0


func risk_label() -> String:
	if risk < 20:
		return "Low risk"
	if risk < 35:
		return "Medium risk"
	if risk < 45:
		return "High risk"
	return "Extreme risk"


func category_name() -> String:
	return String(category).capitalize()
