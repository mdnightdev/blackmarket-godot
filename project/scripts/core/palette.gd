class_name Palette

## Single source of truth for the entire app palette.
## Editing any constant below automatically updates Theme (theme.tres), all screens, sheets, and HUD components on boot.

const INK := Color("0b0c0d")
const PANEL := Color("141618")
const PANEL_LIFT := Color("1b1e21")
const SURFACE_ACTIVE := Color("25292d")
const LINE := Color("2b2f33")
const LINE_MUTED := Color("3a4045")
const TEXT := Color("e2e0dc")
const TEXT_MUTED := Color("85878a")
const TEXT_CREAM := Color("f0efeb")

## Item / equipment rarity accents only. Keep these out of global UI chrome.
## Primary accent replacement: cold steel / gunmetal.
## These values replace the former warm-metal accent throughout the UI.
const STEEL := Color("aeb5be")
const STEEL_BRIGHT := Color("d0d5da")
const GUNMETAL := Color("69737d")
const STEEL_BORDER := Color("414950")

## Item / equipment rarity accents only. Keep these out of global UI chrome.
const GREEN := Color("58c58a")
const BLUE := Color("64aeeB")
const PURPLE := Color("bd83e8")
const FIRE := Color("f0784d")

## Deprecated compatibility names. Kept so existing Palette.GOLD/PEACH
## references in other scripts do not break; every alias now resolves to steel.
const GOLD := STEEL
const GOLD_TITLE := STEEL_BRIGHT
const GOLD_BRIGHT := STEEL_BRIGHT
const GOLD_BORDER := STEEL_BORDER
const PEACH := STEEL
const PEACH_TITLE := STEEL_BRIGHT
const PEACH_BRIGHT := STEEL_BRIGHT
const PEACH_BORDER := STEEL_BORDER

## Legacy rarity alias retained for existing code.
const CYAN := BLUE

## Economy & Status
const PRICE := STEEL
const RISK_LOW := Color("4ade80")
const RISK_HIGH := Color("ef4444")


static func sync_theme() -> void:
	RenderingServer.set_default_clear_color(INK)
	var theme := ThemeDB.get_project_theme()
	if theme == null:
		return
	theme.set_block_signals(true)

	_set_flat(theme, &"Button", &"normal", PANEL, Color.TRANSPARENT)
	_set_flat(theme, &"Button", &"hover", PANEL_LIFT, Color.TRANSPARENT)
	_set_flat(theme, &"Button", &"pressed", SURFACE_ACTIVE, Color.TRANSPARENT)
	_set_flat(theme, &"Button", &"disabled", INK, Color.TRANSPARENT)

	_set_flat(theme, &"PrimaryButton", &"normal", STEEL, Color.TRANSPARENT)
	_set_flat(theme, &"PrimaryButton", &"pressed", GUNMETAL, STEEL_BRIGHT)

	_set_flat(theme, &"DangerButton", &"normal", RISK_HIGH.darkened(0.32), Color.TRANSPARENT)
	_set_flat(theme, &"DangerButton", &"pressed", RISK_HIGH.darkened(0.46), Color.TRANSPARENT)

	_set_flat(theme, &"SecondaryButton", &"normal", PANEL, Color.TRANSPARENT)
	_set_flat(theme, &"SecondaryButton", &"pressed", SURFACE_ACTIVE, Color.TRANSPARENT)

	_set_flat(theme, &"GhostButton", &"pressed", SURFACE_ACTIVE, Color.TRANSPARENT)

	_set_flat(theme, &"SmallButton", &"normal", PANEL_LIFT, Color.TRANSPARENT)
	_set_flat(theme, &"SmallButton", &"pressed", SURFACE_ACTIVE, Color.TRANSPARENT)

	_set_flat(theme, &"TabButton", &"normal", PANEL, Color.TRANSPARENT)
	_set_flat(theme, &"TabButton", &"pressed", SURFACE_ACTIVE, Color.TRANSPARENT)

	_set_flat(theme, &"LineTab", &"normal", Color.TRANSPARENT, Color.TRANSPARENT)
	_set_flat(theme, &"LineTab", &"pressed", Color.TRANSPARENT, TEXT)

	_set_flat(theme, &"ListRow", &"normal", Color.TRANSPARENT, Color.TRANSPARENT)
	_set_flat(theme, &"ListRow", &"pressed", SURFACE_ACTIVE, Color.TRANSPARENT)

	_set_flat(theme, &"ItemCard", &"normal", PANEL_LIFT, Color.TRANSPARENT)
	_set_flat(theme, &"ItemCard", &"hover", PANEL_LIFT, Color.TRANSPARENT)
	_set_flat(theme, &"ItemCard", &"pressed", SURFACE_ACTIVE, Color.TRANSPARENT)
	_set_flat(theme, &"ItemCardSelected", &"normal", SURFACE_ACTIVE, STEEL_BRIGHT)
	_set_flat(theme, &"ItemCardSelected", &"hover", SURFACE_ACTIVE, STEEL_BRIGHT)
	_set_flat(theme, &"ItemCardSelected", &"pressed", SURFACE_ACTIVE, STEEL_BRIGHT)

	_set_flat(theme, &"VenueButton", &"normal", PANEL_LIFT, Color.TRANSPARENT)
	_set_flat(theme, &"VenueButton", &"pressed", SURFACE_ACTIVE, Color.TRANSPARENT)

	_set_flat(theme, &"Card", &"panel", PANEL, Color.TRANSPARENT)
	_set_flat(theme, &"HudCard", &"panel", PANEL, Color.TRANSPARENT)
	_set_flat(theme, &"HudStrip", &"panel", INK, Color.TRANSPARENT)
	_set_flat(theme, &"Sheet", &"panel", PANEL, Color.TRANSPARENT)
	_set_flat(theme, &"VenuePanel", &"panel", PANEL, Color.TRANSPARENT)
	_set_flat(theme, &"TradePanel", &"panel", PANEL, Color.TRANSPARENT)
	_set_flat(theme, &"SpeechBubble", &"panel", PANEL_LIFT, Color.TRANSPARENT)
	theme.set_stylebox(&"panel", &"IconFrame", StyleBoxEmpty.new())
	_set_flat(theme, &"PillLabel", &"normal", SURFACE_ACTIVE, Color.TRANSPARENT)

	_set_flat(theme, &"ThinBar", &"background", LINE, Color.TRANSPARENT)
	_set_flat(theme, &"ThinBar", &"fill", STEEL, Color.TRANSPARENT)
	_set_flat(theme, &"HSlider", &"slider", LINE_MUTED, Color.TRANSPARENT)
	_set_flat(theme, &"HSlider", &"grabber_area", STEEL, Color.TRANSPARENT)
	_set_flat(theme, &"HSlider", &"grabber_area_highlight", STEEL_BRIGHT, Color.TRANSPARENT)

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
	sb.shadow_size = 0
	if border == Color.TRANSPARENT:
		sb.set_border_width_all(0)
		sb.border_color = Color.TRANSPARENT
	else:
		sb.set_border_width_all(1)
		sb.border_color = border
	sb.set_block_signals(false)


static func on_node_added(node: Node) -> void:
	if node is PanelContainer:
		var ctrl := node as PanelContainer
		if ctrl.has_theme_stylebox_override(&"panel"):
			var sb := ctrl.get_theme_stylebox(&"panel") as StyleBoxFlat
			if sb != null:
				sb.set_block_signals(true)
				sb.shadow_size = 0
				if ctrl.name == &"Sheet":
					sb.bg_color = INK if is_equal_approx(ctrl.anchor_top, 0.0) else PANEL
					sb.set_border_width_all(0)
				elif ctrl is NavBar or ctrl.name == &"NavBar":
					sb.bg_color = INK
					sb.set_border_width_all(0)
				elif ctrl.name == &"Detail":
					sb.bg_color = PANEL
					sb.set_border_width_all(0)
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
				fill_sb.bg_color = STEEL
				fill_sb.set_block_signals(false)
	elif node is ColorRect:
		var rect := node as ColorRect
		if rect.name == &"Backdrop" or rect.name == &"Dim":
			rect.color = INK
		elif rect.name.ends_with("Divider"):
			rect.color = LINE_MUTED
	elif node is TextureRect:
		var tex := node as TextureRect
		if tex.name == &"Icon" and tex.get_parent() != null and tex.get_parent().name == &"Cash":
			tex.modulate = STEEL
		elif tex.name == &"CleanIcon":
			tex.modulate = STEEL
	elif node is Label:
		var lbl := node as Label
		if lbl.name == &"CleanValue" or lbl.name == &"PriceLabel":
			lbl.add_theme_color_override(&"font_color", PRICE)


static func style_tree(node: Node) -> void:
	on_node_added(node)
	for child in node.get_children():
		style_tree(child)
