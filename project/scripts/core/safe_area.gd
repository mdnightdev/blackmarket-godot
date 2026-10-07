class_name SafeArea


## Height of the notch or camera cutout at the top of the screen, in viewport units.
static func top_inset(viewport: Viewport) -> float:
	var window_height := DisplayServer.window_get_size().y
	if window_height <= 0:
		return 0.0
	var safe_top := DisplayServer.get_display_safe_area().position.y
	return safe_top * viewport.get_visible_rect().size.y / window_height


static func apply_top_margin(margin: MarginContainer, minimum: int) -> void:
	var inset := int(top_inset(margin.get_viewport()))
	margin.add_theme_constant_override("margin_top", maxi(minimum, inset + 16))
