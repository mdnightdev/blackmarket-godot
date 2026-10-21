class_name DialogueChoice
extends RefCounted

const LEAVE: StringName = &"leave"
const ACCEPT: StringName = &"accept"
const DECLINE: StringName = &"decline"
const TRADE: StringName = &"trade"
const ASK: StringName = &"ask"
const CONTINUE: StringName = &"continue"

var id: StringName
var label: String
var enabled: bool
## Picked when the player presses back. Shown as a small link in the corner of the dialogue box.
var cancel: bool
## Picked by tapping anywhere once the line is shown. Only for choices that spend or risk nothing.
var advance: bool


func _init(choice_id: StringName, choice_label: String, is_enabled := true, is_cancel := false, is_advance := false) -> void:
	id = choice_id
	label = choice_label
	enabled = is_enabled
	cancel = is_cancel
	advance = is_advance
