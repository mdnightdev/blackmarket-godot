class_name DialogueChoice
extends RefCounted

var id: StringName
var label: String
var enabled: bool
## Picked when the player presses back.
var cancel: bool


func _init(choice_id: StringName, choice_label: String, is_enabled := true, is_cancel := false) -> void:
	id = choice_id
	label = choice_label
	enabled = is_enabled
	cancel = is_cancel
