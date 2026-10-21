class_name SafeArea

const HUD_HEIGHT := 56
const HUD_GAP := 8


## Height of the notch or camera cutout at the top of the screen, in viewport units.
static func top_inset(viewport: Viewport) -> float:
	var window_height := DisplayServer.window_get_size().y
	if window_height <= 0:
		return 0.0
	var safe_top := DisplayServer.get_display_safe_area().position.y
	return safe_top * viewport.get_visible_rect().size.y / window_height


## Top margin required for screen content so it sits below the top notch and persistent HUD bar.
static func content_top_margin(viewport: Viewport) -> int:
	var inset := int(top_inset(viewport))
	return inset + HUD_HEIGHT + HUD_GAP


## Applies the standardized top margin to a screen or sheet's main content MarginContainer.
static func apply_top_margin(margin: MarginContainer, minimum: int = 0) -> void:
	var top := maxi(minimum, content_top_margin(margin.get_viewport()))
	margin.add_theme_constant_override("margin_top", top)

