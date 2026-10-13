class_name UnitCard
extends GameButton

## A card led by its art: a fighting tier or a weapon, how many the player has and one short status line.

const ART := {
	Army.Tier.LUNATICS: preload("res://assets/units/lunatics.jpg"),
	Army.Tier.GUARDS: preload("res://assets/units/guards.jpg"),
	Army.Tier.BLACK_HAND: preload("res://assets/units/black_hand.jpg"),
}
const LOCKED_TINT := Color(0.32, 0.32, 0.36)
const ROLL_SECONDS := 0.9

@onready var _art: TextureRect = %Art
@onready var _name_label: Label = %NameLabel
@onready var _count_label: Label = %CountLabel
@onready var _status_label: Label = %StatusLabel

var _roll: Tween


func show_tier(tier: Army.Tier, count_text: String, status: String, locked := false) -> void:
	show_art(ART[tier], str(Army.TIER_NAMES[tier]), count_text, status, locked)


func show_art(art: Texture2D, title: String, count_text: String, status: String, locked := false) -> void:
	_art.texture = art
	_art.modulate = LOCKED_TINT if locked else Color.WHITE
	_name_label.text = title.to_upper()
	_count_label.text = count_text
	_status_label.text = status


## Counts up from what the player had to what they have now, so a purchase is seen arriving.
func roll_count(from: int, to: int) -> void:
	if _roll:
		_roll.kill()
	_count_label.text = Format.count(from)
	_roll = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_roll.tween_method(func(value: float) -> void: _count_label.text = Format.count(roundi(value)), float(from), float(to), ROLL_SECONDS)
	_count_label.modulate = Palette.RISK_LOW
	_roll.parallel().tween_property(_count_label, "modulate", Color.WHITE, ROLL_SECONDS)
