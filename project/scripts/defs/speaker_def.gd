class_name SpeakerDef
extends Resource

@export var id: StringName
@export var display_name: String
@export var portrait: Texture2D
## Same portrait with the mouth open. Optional; without it the portrait only moves while talking.
@export var talk_portrait: Texture2D


## Short label shown next to the name in dialogue.
func title() -> String:
	return ""
