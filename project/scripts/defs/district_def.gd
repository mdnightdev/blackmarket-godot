class_name DistrictDef
extends Resource

@export var id: StringName
@export var display_name: String
@export var tagline: String
## 1 street, 2 middle class, 3 wealthy.
@export_range(1, 3) var tier: int = 1
@export_multiline var description: String
@export var background: Texture2D
@export var ambient_effect: PackedScene
## Pin location on the city map image, as a fraction of its width and height.
@export var map_position := Vector2(0.5, 0.5)
@export_range(0, 1_000_000) var travel_cost: int = 0
@export_range(0.5, 3.0, 0.05) var heat_multiplier: float = 1.0
@export var venues: Array[StringName] = []
## Street corners the turf is split into. Empty for districts still fought over as a share.
@export var corners: Array[CornerDef] = []
## The district seen from above, shown instead of the street when it has corners.
@export var corner_map: Texture2D
## Districts with a direct road from here. Hot runs travel stop by stop along these.
@export var roads: Array[StringName] = []
## Street cred rank needed before the player can travel here.
@export_range(1, 10) var min_rank: int = 1
