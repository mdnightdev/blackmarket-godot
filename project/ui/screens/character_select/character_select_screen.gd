extends Control

const PERSON_CHIP := preload("res://ui/components/person_chip.tscn")

@onready var _margin: MarginContainer = %Margin
@onready var _portrait: TalkingPortrait = %Portrait
@onready var _name_label: Label = %NameLabel
@onready var _tagline_label: Label = %TaglineLabel
@onready var _speech: Typewriter = %Speech
@onready var _pick_list: HBoxContainer = %PickList
@onready var _back_button: Button = %BackButton
@onready var _start_button: Button = %StartButton

var _selected: PlayerDef


func _ready() -> void:
	SafeArea.apply_top_margin(_margin, 40)
	_speech.finished.connect(_portrait.set_talking.bind(false))
	_back_button.pressed.connect(SceneRouter.go_to.bind(SceneRouter.TITLE_SCREEN))
	_start_button.pressed.connect(_start_run)

	var group := ButtonGroup.new()
	for player in Content.players():
		var chip: PersonChip = PERSON_CHIP.instantiate()
		chip.toggle_mode = true
		chip.button_group = group
		_pick_list.add_child(chip)
		chip.display(player.portrait, player.display_name, "", Palette.TEXT_MUTED)
		chip.pressed.connect(_select.bind(player))
		if player.id == RunState.DEFAULT_PLAYER:
			chip.button_pressed = true
			_select(player)


func handle_back() -> bool:
	SceneRouter.go_to(SceneRouter.TITLE_SCREEN)
	return true


func _select(player: PlayerDef) -> void:
	if player == _selected:
		return
	_selected = player
	_portrait.show_speaker(player)
	_name_label.text = player.display_name
	_tagline_label.text = player.tagline
	_portrait.set_talking(true)
	_speech.type_text("\"%s\"" % player.intro_line)


func _start_run() -> void:
	if _selected == null:
		return
	GameState.start_new_run(_selected.id)
	SceneRouter.go_to(SceneRouter.DISTRICT_SCREEN)
