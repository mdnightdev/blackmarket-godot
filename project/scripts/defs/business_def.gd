class_name BusinessDef
extends Resource

@export var id: StringName
@export var display_name: String
@export var icon: Texture2D
@export_multiline var description: String
@export_range(0, 1_000_000) var price: int = 0
## Street cred rank needed before this business can open in a district the player holds.
@export_range(1, 10) var min_rank: int = 4
@export_range(1, 500) var stock_capacity: int = 20
@export_range(1, 100) var sales_per_phase: int = 1
@export_range(0, 10_000) var daily_upkeep: int = 0
@export_range(0, 50) var daily_heat_drop: int = 0
## Extra price on luxury goods sold here.
@export_range(0.0, 1.0, 0.05) var luxury_bonus: float = 0.0
