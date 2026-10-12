class_name BattleSide
extends Resource
## One side of a fight as the battle scene shows it. The fight is decided before the scene plays:
## head_count and survivors carry the result, and the scene only acts it out.

@export var display_name: String
@export var color := Color.WHITE
@export var head_count := 0
@export var survivors := 0
@export var squad_names: Array[String] = []
@export var fighters: Array[Texture2D] = []
@export var ranged := false
## Repaints the fighters' red clothing so two sides sharing the same art can be told apart. Alpha 0 keeps the art.
@export var team_color := Color(1.0, 1.0, 1.0, 0.0)
@export var skill_name := ""
@export var skill_owner := ""
@export var skill_portrait: Texture2D


func losses() -> int:
	return maxi(0, head_count - survivors)


func has_skill() -> bool:
	return not skill_name.is_empty() and skill_portrait != null
