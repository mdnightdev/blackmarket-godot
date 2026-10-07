class_name DialoguePanel
extends Control

const CHOICE_HEIGHT := 64
const OPEN_SECONDS := 0.28
const CLOSE_SECONDS := 0.18
const SLIDE_PIXELS := 60.0
const CHOICES_FADE_SECONDS := 0.18

@onready var _dim: ColorRect = %Dim
@onready var _backdrop: TextureRect = %Backdrop
@onready var _margin: Control = %Margin
@onready var _portrait: TalkingPortrait = %Portrait
@onready var _box: Control = %Box
@onready var _name_label: Label = %NameLabel
@onready var _role_label: Label = %RoleLabel
@onready var _line: Typewriter = %Line
@onready var _hint_label: Label = %HintLabel
@onready var _choice_list: VBoxContainer = %ChoiceList

var _choices: Array[DialogueChoice] = []
var _on_choice: Callable
var _tween: Tween


func _ready() -> void:
	hide()
	_line.finished.connect(_show_choices)
	_dim.gui_input.connect(_on_tap)
	_box.gui_input.connect(_on_tap)


## Places a full-screen effect above the dim and backdrop but behind the portrait and card.
func add_backdrop_layer(layer: Control) -> void:
	add_child(layer)
	move_child(layer, _margin.get_index())


## on_choice receives the picked choice id. It can call say() to continue or close() to finish.
func open(speaker: SpeakerDef, line: String, choices: Array[DialogueChoice], on_choice: Callable, hint := "", backdrop: Texture2D = null) -> void:
	_portrait.show_speaker(speaker)
	_name_label.text = speaker.display_name if speaker != null else ""
	var role := speaker.title() if speaker != null else ""
	_role_label.text = role.to_upper()
	_role_label.visible = not role.is_empty()
	_backdrop.texture = backdrop
	_backdrop.visible = backdrop != null

	if not visible:
		show()
		modulate.a = 0.0
		_margin.position.y = SLIDE_PIXELS
		_animate(1.0, 0.0, OPEN_SECONDS, Tween.EASE_OUT)
	say(line, choices, on_choice, true, hint)


func say(line: String, choices: Array[DialogueChoice], on_choice: Callable, talking := true, hint := "") -> void:
	_choices = choices
	_on_choice = on_choice
	_clear_choices()
	_hint_label.text = hint
	_hint_label.visible = not hint.is_empty()
	_portrait.set_talking(talking)
	_line.type_text(line)


func close() -> void:
	if not visible:
		return
	_line.stop()
	_portrait.set_talking(false)
	_choices = []
	_animate(0.0, SLIDE_PIXELS, CLOSE_SECONDS, Tween.EASE_IN).chain().tween_callback(func() -> void:
		hide()
		_clear_choices())


## Back skips the typing first, then takes the cancel choice if there is one. Never falls through.
func handle_back() -> bool:
	if _line.is_typing():
		_line.skip()
		return true
	for choice in _choices:
		if choice.cancel and choice.enabled:
			_pick(choice.id)
			break
	return true


func _on_tap(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and _line.is_typing():
		_line.skip()


func _show_choices() -> void:
	_portrait.set_talking(false)
	_clear_choices()
	for index in _choices.size():
		var choice := _choices[index]
		var button := GameButton.new()
		button.text = choice.label
		button.custom_minimum_size.y = CHOICE_HEIGHT
		button.theme_type_variation = &"PrimaryButton" if index == 0 else &"SecondaryButton"
		button.disabled = not choice.enabled
		button.pressed.connect(_pick.bind(choice.id))
		_choice_list.add_child(button)
	_choice_list.modulate.a = 0.0
	create_tween().tween_property(_choice_list, "modulate:a", 1.0, CHOICES_FADE_SECONDS)


func _pick(choice_id: StringName) -> void:
	if _on_choice.is_valid():
		_on_choice.call(choice_id)


func _clear_choices() -> void:
	for child in _choice_list.get_children():
		_choice_list.remove_child(child)
		child.queue_free()


func _animate(alpha: float, offset_y: float, duration: float, easing: Tween.EaseType) -> Tween:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(easing)
	_tween.tween_property(self, "modulate:a", alpha, duration)
	_tween.tween_property(_margin, "position:y", offset_y, duration)
	return _tween
