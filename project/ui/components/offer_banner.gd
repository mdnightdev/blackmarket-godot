class_name OfferBanner
extends Control

## Phone-style notice for a new offer. Slides down under the top bar and slides back up on its own.

signal opened(offer_id: String)

const SHOW_SECONDS := 5.0
const SLIDE_SECONDS := 0.3
## Matches the screens' top margin and top bar, so the banner lands just under the bar.
const SCREEN_TOP_MARGIN := 40.0
const TOP_BAR_HEIGHT := 60.0
const TOP_GAP := 10.0
const BUZZ_MS := 40

@onready var _card: PanelContainer = %Card
@onready var _portrait: TextureRect = %Portrait
@onready var _sender_label: Label = %SenderLabel
@onready var _line_label: Label = %LineLabel
@onready var _place_label: Label = %PlaceLabel
@onready var _detail_label: Label = %DetailLabel
@onready var _tap_area: Button = %TapArea
@onready var _hide_timer: Timer = %HideTimer

## The offer on screen. Empty while nothing is shown.
var offer_id := ""
var _tween: Tween


func _ready() -> void:
	hide()
	_tap_area.pressed.connect(_on_tapped)
	_hide_timer.timeout.connect(retract)


func is_showing() -> bool:
	return not offer_id.is_empty()


## detail sits on the right, for example the pay. place is a small caption under the line. Both hide when empty.
func show_offer(id: String, portrait: Texture2D, sender: String, line: String, detail := "", place := "") -> void:
	offer_id = id
	_portrait.texture = portrait
	_sender_label.text = sender
	_line_label.text = line
	_detail_label.text = detail
	_detail_label.visible = not detail.is_empty()
	_place_label.text = place
	_place_label.visible = not place.is_empty()
	_card.position.y = -size.y
	show()
	await get_tree().process_frame
	if not is_showing():
		return
	_card.position.y = -_card.size.y
	_slide_to(_rest_y())
	_hide_timer.start(SHOW_SECONDS)
	AudioService.play_sfx(Sfx.EVENT)
	if Settings.vibration:
		Input.vibrate_handheld(BUZZ_MS)


func retract() -> void:
	if not is_showing():
		return
	offer_id = ""
	_hide_timer.stop()
	_slide_to(-_card.size.y).tween_callback(hide)


func _on_tapped() -> void:
	var tapped := offer_id
	retract()
	if not tapped.is_empty():
		opened.emit(tapped)


func _rest_y() -> float:
	return below_top_bar(get_viewport())


## Where a card rests just under the screens' top bar.
static func below_top_bar(viewport: Viewport) -> float:
	return maxf(SCREEN_TOP_MARGIN, SafeArea.top_inset(viewport) + 16.0) + TOP_BAR_HEIGHT + TOP_GAP


func _slide_to(target_y: float) -> Tween:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_card, "position:y", target_y, SLIDE_SECONDS)
	return _tween
