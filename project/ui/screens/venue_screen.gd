class_name VenueScreen
extends Control

## Shared layout for venue screens: a speaking header, a list of rows, and Bag and Leave buttons.
## Subclasses call setup() from _ready and fill the list in _refresh() after calling super().

const ITEM_ROW := preload("res://ui/components/item_row.tscn")
const GREETING_DELAY := 0.35
const LEAVE: StringName = &"leave"

@onready var _background: TextureRect = %Background
@onready var _margin: MarginContainer = %Margin
@onready var _header: Control = %Header
@onready var _portrait: TalkingPortrait = %Portrait
@onready var _venue_label: Label = %VenueLabel
@onready var _host_label: Label = %HostLabel
@onready var _speech: Typewriter = %Speech
@onready var _scroll: ScrollContainer = %Scroll
@onready var _list: VBoxContainer = %List
@onready var _bag_button: Button = %BagButton
@onready var _back_button: Button = %BackButton


func setup(background: Texture2D, venue_name: String, speaker: SpeakerDef, greeting: String) -> void:
	SafeArea.apply_top_margin(_margin, 40)
	_background.texture = background
	_venue_label.text = venue_name.to_upper()
	_host_label.text = speaker.display_name
	_portrait.show_speaker(speaker)
	_speech.finished.connect(_portrait.set_talking.bind(false))

	_bag_button.pressed.connect(GameOverlay.open_bag)
	_back_button.pressed.connect(SceneRouter.go_to.bind(SceneRouter.DISTRICT_SCREEN))
	GameState.run_changed.connect(_refresh)

	GameState.clock_active = true
	_refresh()
	_play_entrance()
	get_tree().create_timer(GREETING_DELAY).timeout.connect(says.bind(greeting))


func _exit_tree() -> void:
	GameState.clock_active = false


func can_present_encounter() -> bool:
	return true


func handle_back() -> bool:
	SceneRouter.go_to(SceneRouter.DISTRICT_SCREEN)
	return true


func says(line: String) -> void:
	if not is_inside_tree():
		return
	_portrait.set_talking(true)
	_speech.type_text("\"%s\"" % line)


func _refresh() -> void:
	var run := GameState.run
	_bag_button.text = "Bag %d/%d" % [Inventory.used(run), Inventory.capacity(run)]
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()


func _add_row() -> ItemRow:
	var row: ItemRow = ITEM_ROW.instantiate()
	_list.add_child(row)
	return row


func _add_label(text: String, variation: StringName) -> void:
	var label := Label.new()
	label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	_list.add_child(label)


func _leave_choice() -> Array[DialogueChoice]:
	var choices: Array[DialogueChoice] = [DialogueChoice.new(LEAVE, "Leave", true, true)]
	return choices


func _end_talk(_choice: StringName) -> void:
	GameOverlay.end_talk()


func _play_entrance() -> void:
	_header.modulate.a = 0.0
	_scroll.modulate.a = 0.0
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_header, "modulate:a", 1.0, 0.4)
	tween.tween_property(_scroll, "modulate:a", 1.0, 0.45).set_delay(0.12)
