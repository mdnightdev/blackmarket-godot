class_name BusinessDef
extends Resource

@export var id: StringName
@export var display_name: String
@export var icon: Texture2D:
	get:
		if icon != null:
			return icon
		return ItemsAtlas.get_icon(&"nav_market")
@export_multiline var description: String
@export_range(0, 10_000_000) var price: int = 0
## Street cred rank needed before this business can open in a district the player holds.
@export_range(1, 10) var min_rank: int = 4
@export_range(0, 50) var daily_heat_drop: int = 0
@export_range(0.0, 1.0, 0.05) var luxury_bonus: float = 0.0
@export_range(0, 500) var stock_capacity: int = 20
@export_range(0, 100) var sales_per_phase: int = 3
@export_range(0, 10_000_000) var launder_capacity: int = 0
@export_range(0.0, 1.0, 0.01) var launder_fee: float = 0.20


func effective_launder_capacity() -> int:
	return launder_capacity if launder_capacity > 0 else price

const MAX_LEVEL := 5


func level_multiplier(level: int) -> float:
	return 1.0 + float(clampi(level, 1, MAX_LEVEL) - 1) * 0.5


func upgraded_value(level: int) -> int:
	return roundi(price * level_multiplier(level))


func upgrade_cost(current_level: int) -> int:
	if current_level >= MAX_LEVEL:
		return 0
	return roundi(price * 0.5)


func effective_upkeep(level: int) -> int:
	return maxi(50, roundi(upgraded_value(level) * 0.01))

