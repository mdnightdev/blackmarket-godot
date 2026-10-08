class_name CrewRoleDef
extends Resource

@export var id: StringName
@export var display_name: String
@export var icon: Texture2D
@export_multiline var description: String
@export_range(1, 10) var min_rank: int = 1
@export_range(0, 100_000) var hire_cost: int = 0
@export_range(0, 10_000) var daily_wage: int = 0
@export_range(0, 100) var capacity_bonus: int = 0
## Fraction taken off the police stop chance.
@export_range(0.0, 1.0, 0.05) var stop_reduction: float = 0.0
@export_range(0.0, 1.0, 0.05) var escape_bonus: float = 0.0
@export_range(0.0, 1.0, 0.05) var fight_bonus: float = 0.0
## Multiplier on the chance of being mugged.
@export_range(0.0, 1.0, 0.05) var mugging_factor: float = 1.0
@export var removes_travel_heat := false
## Once per day, turns a raid into a warning.
@export var warns_of_raids := false
