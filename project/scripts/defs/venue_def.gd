class_name VenueDef
extends Resource

@export var id: StringName
@export var display_name: String
@export var tagline: String
@export var available := false
## Character who runs the venue and talks to the player inside.
@export var host: StringName
## Interior shown behind the venue screen. Venues without one use the district picture.
@export var background: Texture2D
