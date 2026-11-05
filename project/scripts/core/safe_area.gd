class_name SafeArea

const HUD_HEIGHT := 56
const HUD_GAP := 8
const NAV_HEIGHT := 90
const ANDROID_MIN_TOP_INSET := 36.0


## Height of the status bar / camera cutout at the top of the screen, in viewport units.
static func top_inset(viewport: Viewport) -> float:
	var window_height := DisplayServer.window_get_size().y
	if window_height <= 0 or viewport == null:
		return ANDROID_MIN_TOP_INSET if OS.get_name() == "Android" else 0.0
	var safe := DisplayServer.get_display_safe_area()
	var top_pixels := float(safe.position.y)
	var inset := 0.0
	if top_pixels > 0.0:
		inset = top_pixels * viewport.get_visible_rect().size.y / float(window_height)
	if OS.get_name() == "Android":
		inset = maxf(inset, ANDROID_MIN_TOP_INSET)
	return inset


## Applies top safe-area padding inside the persistent top HUD bar PanelContainer so its solid INK
## background fills behind the camera cutout while pushing the HUD row down into the safe zone.
static func apply_top_bar_margin(target: PanelContainer, base_margin: int = 8) -> void:
	if target == null:
		return
	var inset := int(top_inset(target.get_viewport()))
	target.custom_minimum_size.y = HUD_HEIGHT + inset
	var style := target.get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		var dup := style.duplicate() as StyleBoxFlat
		dup.bg_color = Palette.INK
		dup.content_margin_top = base_margin + inset
		target.add_theme_stylebox_override("panel", dup)


## Top margin required for screen content so it sits below the top notch and persistent HUD bar.
static func content_top_margin(viewport: Viewport) -> int:
	var inset := int(top_inset(viewport))
	return inset + HUD_HEIGHT + HUD_GAP


## Applies the standardized top margin to a screen or sheet's main content MarginContainer.
static func apply_top_margin(margin: MarginContainer, minimum: int = 0) -> void:
	var top := maxi(minimum, content_top_margin(margin.get_viewport()))
	margin.add_theme_constant_override("margin_top", top)


## Height of the gesture navigation bar or home indicator at the bottom of the screen, in viewport units.
static func bottom_inset(viewport: Viewport) -> float:
	var window_height := DisplayServer.window_get_size().y
	if window_height <= 0:
		return 0.0
	var safe := DisplayServer.get_display_safe_area()
	var bottom_pixels := float(window_height - (safe.position.y + safe.size.y))
	if bottom_pixels <= 0.0:
		return 0.0
	return bottom_pixels * viewport.get_visible_rect().size.y / float(window_height)


## Applies the standardized bottom margin (e.g. for bottom bars or full-height containers).
static func apply_bottom_margin(target: Control, base_margin: int = 0) -> void:
	var bottom := base_margin + int(bottom_inset(target.get_viewport()))
	if target is MarginContainer:
		target.add_theme_constant_override("margin_bottom", bottom)
	elif target is PanelContainer:
		var style := target.get_theme_stylebox("panel")
		if style is StyleBoxFlat:
			var dup := style.duplicate() as StyleBoxFlat
			dup.content_margin_bottom = bottom
			target.add_theme_stylebox_override("panel", dup)
