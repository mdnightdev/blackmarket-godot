class_name HeistDef
extends Resource

@export var id: StringName
@export var display_name: String
@export var icon: Texture2D
@export_multiline var description: String
@export var district_id: StringName
@export_range(1, 10) var min_rank: int = 1
@export var required_roles: Array[StringName] = []
@export_range(0.0, 1.0, 0.05) var base_chance: float = 0.5
@export_range(0, 1_000_000) var payout: int = 0
@export_range(0, 100) var heat: int = 0
@export_range(0, 500) var cred: int = 0
## Family that loses standing with the player when this heist is pulled. Empty means none.
@export var target_family: StringName
@export_range(0, 100) var standing_loss: int = 0
