class_name ItemCard
extends ItemRow

## An ItemRow laid out as a grid card, with a trend arrow beside the price and the caption tinted by risk.

const TREND_UP: Texture2D = preload("res://assets/icons/hud/trending-up.svg")
const TREND_DOWN: Texture2D = preload("res://assets/icons/hud/trending-down.svg")

@onready var _trend_icon: TextureRect = %TrendIcon


## rising is 1 for a price going up, -1 going down and 0 for steady, which shows no arrow.
func show_trend(rising: int, color: Color) -> void:
	_trend_icon.visible = rising != 0
	_trend_icon.texture = TREND_UP if rising > 0 else TREND_DOWN
	_trend_icon.modulate = color


func tint_caption(color: Color) -> void:
	_caption_label.add_theme_color_override("font_color", color)
