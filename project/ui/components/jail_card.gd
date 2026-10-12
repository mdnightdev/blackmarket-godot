class_name JailCard
extends Control

## Sits under the top bar while the player is in a cell. The rest of the game stays open to look around, but trading,
## travel and jobs wait. The player sits the time out or has 午夜兔子 post bail.

signal bail_requested

const NUDGE_SECONDS := 0.12
const NUDGE_PIXELS := 10.0
## Matches the card's left and right offsets in the scene.
const SIDE_MARGIN := 16.0

@onready var _card: PanelContainer = %Card
@onready var _time_label: Label = %TimeLabel
@onready var _bail_button: Button = %BailButton

var _nudge_tween: Tween


func _ready() -> void:
	hide()
	_bail_button.pressed.connect(bail_requested.emit)


func _process(_delta: float) -> void:
	var run := GameState.run
	var jailed := GameState.clock_active and run != null and Police.is_jailed(run)
	if visible != jailed:
		visible = jailed
	if not jailed:
		return
	_card.position.y = OfferBanner.below_top_bar(get_viewport())
	# The wrapped note measures tall before the card has its width, and a card outside a container never shrinks back.
	_card.size.y = 0.0
	_time_label.text = Format.clock(Police.jail_seconds_left(run))
	var rabbit := Content.speaker(RabbitCells.FRIEND)
	var caller := rabbit.display_name if rabbit != null else "a friend"
	_bail_button.text = "Call %s to post bail, %s" % [caller, Format.money(run.jail_bail)]
	_bail_button.disabled = run.cash < run.jail_bail


## Shakes the card when the player tries something a cell does not allow.
func nudge() -> void:
	if not visible:
		return
	AudioService.play_sfx(Sfx.HAGGLE_FAIL)
	if _nudge_tween:
		_nudge_tween.kill()
	_card.position.x = SIDE_MARGIN
	_nudge_tween = create_tween()
	for direction in [1.0, -1.0, 1.0, 0.0]:
		_nudge_tween.tween_property(_card, "position:x", SIDE_MARGIN + direction * NUDGE_PIXELS, NUDGE_SECONDS / 2.0)
