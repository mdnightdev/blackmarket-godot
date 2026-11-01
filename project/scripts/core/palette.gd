class_name Palette

## Single source of truth for the entire app palette.
## Editing any constant below automatically updates Theme (theme.tres), all screens, sheets, and HUD components on boot.

const INK := Color("08090c")
const PANEL := Color("0f1217")
const PANEL_LIFT := Color("151921")
const SURFACE_ACTIVE := Color("1d232f")
const LINE := Color("222938")
const LINE_MUTED := Color("323b4e")
const TEXT := Color("e2e6ee")
const TEXT_MUTED := Color("7e899b")
const TEXT_CREAM := Color("f0e6d2")

## Primary Accent: Syndicate Gold
const GOLD := Color("d4af37")
const GOLD_TITLE := Color("ebc768")
const GOLD_BRIGHT := Color("f5d88e")
const GOLD_BORDER := Color("b8932a")

## Legacy alias for codebase compatibility
const PEACH := GOLD
const PEACH_TITLE := GOLD_TITLE
const PEACH_BRIGHT := GOLD_BRIGHT
const PEACH_BORDER := GOLD_BORDER

## Rarity Tones (Strictly for item slot rarity indicators, never general UI)
const STEEL := Color("64748b")
const CYAN := Color("38bdf8")
const PURPLE := Color("a855f7")

## Economy & Status
const PRICE := Color("d4af37")
const RISK_LOW := Color("4ade80")
const RISK_HIGH := Color("ef4444")


static func sync_theme() -> void:
	RenderingServer.set_default_clear_color(INK)
	var theme := ThemeDB.get_project_theme()
	if theme == null:
		return
	theme.set_block_signals(true)

	_set_flat(theme, &"Button", &"normal", PANEL, LINE_MUTED)
	_set_flat(theme, &"Button", &"hover", PANEL_LIFT, LINE_MUTED)
	_set_flat(theme, &"Button", &"pressed", SURFACE_ACTIVE, TEXT_MUTED)
	_set_flat(theme, &"Button", &"disabled", INK, LINE)

	_set_flat(theme, &"PrimaryButton", &"normal", PEACH, PEACH_TITLE)
	_set_flat(theme, &"PrimaryButton", &"pressed", PEACH.darkened(0.2), PEACH_BORDER)

	_set_flat(theme, &"DangerButton", &"normal", RISK_HIGH.darkened(0.32), RISK_HIGH)
	_set_flat(theme, &"DangerButton", &"pressed", RISK_HIGH.darkened(0.46), RISK_HIGH)

	_set_flat(theme, &"SecondaryButton", &"normal", PANEL, PEACH_BORDER)
	_set_flat(theme, &"SecondaryButton", &"pressed", Color(PEACH, 0.22), PEACH_BORDER)

	_set_flat(theme, &"GhostButton", &"pressed", Color(TEXT_CREAM, 0.10), Color.TRANSPARENT)

	_set_flat(theme, &"SmallButton", &"normal", PANEL_LIFT, LINE_MUTED)
	_set_flat(theme, &"SmallButton", &"pressed", SURFACE_ACTIVE, TEXT_CREAM)

	_set_flat(theme, &"TabButton", &"normal", PANEL, Color.TRANSPARENT)
	_set_flat(theme, &"TabButton", &"pressed", SURFACE_ACTIVE, PEACH_BRIGHT)

	_set_flat(theme, &"LineTab", &"normal", Color.TRANSPARENT, LINE)
	_set_flat(theme, &"LineTab", &"pressed", Color.TRANSPARENT, PEACH_BRIGHT)

	_set_flat(theme, &"ListRow", &"normal", Color.TRANSPARENT, LINE)
	_set_flat(theme, &"ListRow", &"pressed", SURFACE_ACTIVE, LINE)

	_set_flat(theme, &"ItemCard", &"normal", PANEL_LIFT, LINE)
	_set_flat(theme, &"ItemCard", &"pressed", SURFACE_ACTIVE, PEACH_BORDER)

	_set_flat(theme, &"VenueButton", &"normal", PANEL_LIFT, LINE_MUTED)
	_set_flat(theme, &"VenueButton", &"pressed", SURFACE_ACTIVE, PEACH_BORDER)

	_set_flat(theme, &"Card", &"panel", PANEL, LINE)
	_set_flat(theme, &"HudCard", &"panel", PANEL, LINE)
	_set_flat(theme, &"HudStrip", &"panel", INK, LINE_MUTED)
	_set_flat(theme, &"Sheet", &"panel", PANEL, LINE_MUTED)
	_set_flat(theme, &"VenuePanel", &"panel", PANEL, LINE)
	_set_flat(theme, &"TradePanel", &"panel", PANEL, LINE_MUTED)
	_set_flat(theme, &"SpeechBubble", &"panel", PANEL_LIFT, LINE_MUTED)
	_set_flat(theme, &"IconFrame", &"panel", PANEL, LINE_MUTED)
	_set_flat(theme, &"PillLabel", &"normal", SURFACE_ACTIVE, Color.TRANSPARENT)

	_set_flat(theme, &"ThinBar", &"background", LINE, Color.TRANSPARENT)
	_set_flat(theme, &"ThinBar", &"fill", GOLD, Color.TRANSPARENT)
	_set_flat(theme, &"HSlider", &"slider", LINE_MUTED, Color.TRANSPARENT)
	_set_flat(theme, &"HSlider", &"grabber_area", GOLD, Color.TRANSPARENT)
	_set_flat(theme, &"HSlider", &"grabber_area_highlight", GOLD_BRIGHT, Color.TRANSPARENT)

	var sep := theme.get_stylebox(&"separator", &"HSeparator") as StyleBoxLine
	if sep != null:
		sep.set_block_signals(true)
		sep.color = LINE
		sep.set_block_signals(false)

	for t in [&"Label", &"Button", &"CheckButton"]:
		theme.set_color(&"font_color", t, TEXT)
		theme.set_color(&"font_hover_color", t, TEXT)
		theme.set_color(&"font_focus_color", t, TEXT)
	theme.set_color(&"font_pressed_color", &"Button", TEXT_CREAM)
	theme.set_color(&"font_hover_pressed_color", &"Button", TEXT_CREAM)
	theme.set_color(&"font_disabled_color", &"Button", TEXT_MUTED.darkened(0.35))

	for t in [&"PrimaryButton"]:
		theme.set_color(&"font_color", t, INK)
		theme.set_color(&"font_hover_color", t, INK)
		theme.set_color(&"font_pressed_color", t, INK)
		theme.set_color(&"font_hover_pressed_color", t, INK)

	for t in [&"CaptionLabel", &"MutedLabel", &"SectionLabel", &"HudCaptionLabel", &"ListHeading", &"PlaceLabel"]:
		theme.set_color(&"font_color", t, TEXT_MUTED)

	for t in [&"HeaderLabel", &"StatValueLabel", &"TitleLabel", &"LogoLabel", &"DistrictTitleLabel", &"HudStripValue", &"HudValueLabel", &"PillLabel", &"PinLabel", &"NameLabel"]:
		theme.set_color(&"font_color", t, TEXT_CREAM)
	theme.set_color(&"font_outline_color", &"PinLabel", Color(INK, 0.95))

	for t in [&"SecondaryButton", &"SmallButton"]:
		theme.set_color(&"font_color", t, TEXT_CREAM)
		theme.set_color(&"font_hover_color", t, TEXT_CREAM)

	for t in [&"TabButton", &"LineTab", &"GhostButton"]:
		theme.set_color(&"font_color", t, TEXT_MUTED)
		theme.set_color(&"font_hover_color", t, TEXT)
		theme.set_color(&"font_pressed_color", t, TEXT_CREAM)
		theme.set_color(&"font_hover_pressed_color", t, TEXT_CREAM)

	theme.set_block_signals(false)


static func _set_flat(theme: Theme, type_name: StringName, style_name: StringName, bg: Color, border: Color) -> void:
	var sb := theme.get_stylebox(style_name, type_name) as StyleBoxFlat
	if sb == null:
		return
	sb.set_block_signals(true)
	sb.bg_color = bg
	if border != Color.TRANSPARENT:
		sb.border_color = border
	sb.set_block_signals(false)


static func on_node_added(node: Node) -> void:
	if node is PanelContainer:
		var ctrl := node as PanelContainer
		if ctrl.has_theme_stylebox_override(&"panel"):
			var sb := ctrl.get_theme_stylebox(&"panel") as StyleBoxFlat
			if sb != null:
				sb.set_block_signals(true)
				if ctrl.name == &"Sheet":
					sb.bg_color = INK if is_equal_approx(ctrl.anchor_top, 0.0) else PANEL
					if sb.border_width_top > 0:
						sb.border_color = LINE_MUTED
				elif ctrl is NavBar or ctrl.name == &"NavBar":
					sb.bg_color = INK
					sb.border_color = LINE_MUTED
				elif ctrl.name == &"Detail":
					sb.bg_color = PANEL
					sb.border_color = LINE
				elif ctrl is JobRow or ctrl.name == &"JobRow":
					sb.border_color = LINE
				sb.set_block_signals(false)
	elif node is ProgressBar:
		var bar := node as ProgressBar
		if bar.has_theme_stylebox_override(&"background"):
			var bg_sb := bar.get_theme_stylebox(&"background") as StyleBoxFlat
			if bg_sb != null:
				bg_sb.set_block_signals(true)
				bg_sb.bg_color = LINE
				bg_sb.set_block_signals(false)
		if bar.has_theme_stylebox_override(&"fill") and bar.name != &"HeatBar":
			var fill_sb := bar.get_theme_stylebox(&"fill") as StyleBoxFlat
			if fill_sb != null:
				fill_sb.set_block_signals(true)
				fill_sb.bg_color = PEACH
				fill_sb.set_block_signals(false)
	elif node is ColorRect:
		var rect := node as ColorRect
		if rect.name == &"Backdrop":
			rect.color = INK
		elif rect.name == &"Dim":
			rect.color = Color(INK, 0.72)
		elif rect.name.ends_with("Divider"):
			rect.color = LINE_MUTED
	elif node is TextureRect:
		var tex := node as TextureRect
		if tex.name == &"Icon" and tex.get_parent() != null and tex.get_parent().name == &"Cash":
			tex.modulate = GOLD
		elif tex.name == &"CleanIcon":
			tex.modulate = GOLD
	elif node is Label:
		var lbl := node as Label
		if lbl.name == &"CleanValue" or lbl.name == &"PriceLabel":
			lbl.add_theme_color_override(&"font_color", PRICE)


static func style_tree(node: Node) -> void:
	on_node_added(node)
	for child in node.get_children():
		style_tree(child)
