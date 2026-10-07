class_name DistrictDef
extends Resource

@export var id: StringName
@export var display_name: String
@export var tagline: String
@export_multiline var description: String
@export var background: Texture2D
@export var ambient_effect: PackedScene
## Pin location on the city map image, as a fraction of its width and height.
@export var map_position := Vector2(0.5, 0.5)
@export_range(0, 1_000_000) var travel_cost: int = 0
@export_range(0.5, 3.0, 0.05) var heat_multiplier: float = 1.0
@export var venues: Array[StringName] = []
