class_name TurfSheet
extends BottomSheet

const ITEM_ROW := preload("res://ui/components/item_row.tscn")
const CRED_ICON: Texture2D = preload("res://assets/icons/hud/zap.svg")
const LOCK_ICON: Texture2D = preload("res://assets/icons/hud/lock.svg")
const SKILL_ICONS := {
	&"haggler": preload("res://assets/icons/hud/hand-coins.svg"),
	&"pack_mule": preload("res://assets/icons/hud/backpack.svg"),
	&"cool_head": preload("res://assets/icons/hud/snowflake.svg"),
	&"wheelman": preload("res://assets/icons/hud/car.svg"),
	&"muscle": preload("res://assets/icons/hud/biceps-flexed.svg"),
	&"smuggler": preload("res://assets/icons/hud/package.svg"),
}
const TIER_COLORS := {
	Families.Tier.HOSTILE: Palette.RISK_HIGH,
	Families.Tier.NEUTRAL: Palette.TEXT_MUTED,
	Families.Tier.TRUSTED: Palette.RISK_LOW,
	Families.Tier.FAMILY: Palette.RISK_LOW,
}
const CAREER_LOCK := "Pay off the Shark to unlock"
const LOCKED := "LOCKED"
const STOCK: StringName = &"stock"
const UNSTOCK: StringName = &"unstock"
const LEAVE: StringName = &"leave"
const LEVEL_UP: StringName = &"level_up"
const BLOCK: StringName = &"block"
const SECTION_TITLES := {
	BLOCK: "Turf",
	&"safehouse": "Safehouse",
	&"crew": "Crew",
	&"districts": "Districts",
	&"businesses": "Businesses",
	&"skills": "Skills",
	&"families": "Families",
}

@onready var _margin: MarginContainer = %Margin
@onready var _list: VBoxContainer = %List
@onready var _power_label: Label = %PowerLabel
@onready var _title: Label = %Title
@onready var _confirm: ConfirmDialog = %ConfirmDialog

var _pending_action := Callable()
var _managed_business: Dictionary = {}
var _managed_district: StringName
var _section := BLOCK


func _ready() -> void:
	super()
	GameState.run_changed.connect(_on_run_changed)
	_confirm.confirmed.connect(_on_confirmed)


## Opens on the block, or returns to it when a building's section is showing.
func open_turf() -> void:
	if visible:
		_show_section(BLOCK)
		return
	SafeArea.apply_top_margin(_margin, 24)
	_section = BLOCK
	_rebuild()
	open_sheet()


## Back closes an open confirmation first, then a building's section, then the page itself.
func close_modal() -> bool:
	if _confirm.visible:
		_confirm.close()
		return true
	if _section != BLOCK:
		_show_section(BLOCK)
		return true
	return false


func _show_section(section: StringName) -> void:
	_section = section
	_rebuild()
	(_list.get_parent() as ScrollContainer).scroll_vertical = 0


func _on_run_changed() -> void:
	if visible:
		_rebuild.call_deferred()


func _rebuild() -> void:
	var run := GameState.run
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_power_label.text = "Power %d/%d" % [Turf.power(run), Turf.MAX_POWER]
	_title.text = SECTION_TITLES.get(_section, "Turf")
	match _section:
		&"safehouse":
			_list.add_child(SafehouseSection.new())
		&"crew":
			_add_crew(run)
		&"districts":
			_add_districts(run)
		&"businesses":
			_add_businesses(run)
		&"skills":
			_add_skills(run)
		&"families":
			_add_families(run)
		_:
			_add_block(run)


func _add_block(run: RunState) -> void:
	_add_cred(run)
	var scene := TurfScene.new()
	_list.add_child(scene)
	scene.building_tapped.connect(_show_section)
	scene.set_status(&"safehouse", "Open here" if Safehouse.is_open(run) else "Hold this district to open", Safehouse.is_open(run))
	scene.set_status(&"crew", "%d/%d hired" % [run.crew.size(), Crew.cap(run)] if run.career else "Locked: pay the Shark")
	scene.set_status(&"districts", "%d/%d held" % [Turf.held_count(run), Turf.CONTESTED.size()], _any_level_up(run))
	scene.set_status(&"businesses", "%d open" % run.businesses.size() if run.career else "Locked: pay the Shark")
	var points := Skills.points_free(run)
	scene.set_status(&"skills", "%d %s to spend" % [points, "point" if points == 1 else "points"], points > 0)
	var trusted := Content.families().filter(func(family: FamilyDef) -> bool: return Families.tier(run, family.id) >= Families.Tier.TRUSTED).size()
	scene.set_status(&"families", "%d trust you" % trusted, trusted > 0)


func _any_level_up(run: RunState) -> bool:
	return Turf.CONTESTED.any(func(district_id: StringName) -> bool: return Turf.check_level_up(run, district_id) == Turf.LevelResult.OK)


func _add_cred(run: RunState) -> void:
	_add_heading("STREET CRED")
	var rank := StreetCred.rank(run)
	var next_cred := StreetCred.next_rank_cred(rank)
	var caption := "Top rank" if next_cred < 0 else "%s at %d cred" % [StreetCred.rank_name(rank + 1), next_cred]
	_add_row(CRED_ICON, StreetCred.rank_name(rank), "%d cred" % run.street_cred, caption)


func _add_districts(run: RunState) -> void:
	_add_heading("TERRITORY")
	var map := TurfMap.new()
	map.district_tapped.connect(_talk_about_district)
	_list.add_child(map)
	_add_note("Green is yours, pink is Vex's, grey is still in play. Tap a district for its details.")


func _talk_about_district(district: DistrictDef) -> void:
	var run := GameState.run
	_managed_district = district.id
	if not Turf.is_contested(district.id):
		GameOverlay.talk(Content.player(run.player_id), "%s is open city. Nobody runs these streets." % district.display_name, [_close_choice()], _end_talk)
		return
	var share := Turf.share(run, district.id)
	var line := "I run %d%% of %s. Vex has the rest." % [share, district.display_name]
	var result := Turf.check_level_up(run, district.id)
	var cost := Turf.next_level_cost(run, district.id)
	var hint := ""
	match result:
		Turf.LevelResult.OK:
			hint = "Level %d costs %s. Your corners pay more each morning and the police stop you less." % [Turf.bought_level(run, district.id) + 1, Format.money(cost)]
		Turf.LevelResult.NOT_HELD:
			hint = "Get to %d%% to hold it. Sell there or send muscle from the district screen." % Turf.HOLD_SHARE
		Turf.LevelResult.MAX_LEVEL:
			hint = "Level %d. It cannot go any higher." % Turf.MAX_LEVEL
		Turf.LevelResult.RANK_TOO_LOW:
			hint = "The next level needs the %s rank." % StreetCred.rank_name(Turf.next_level_rank(run, district.id))
		Turf.LevelResult.NEEDS_TRUST:
			hint = "The next level needs the trust of the family whose home this is."
		Turf.LevelResult.NOT_ENOUGH_CASH:
			hint = "The next level costs %s." % Format.money(cost)
	var choices: Array[DialogueChoice] = []
	if result in [Turf.LevelResult.OK, Turf.LevelResult.NOT_ENOUGH_CASH]:
		choices.append(DialogueChoice.new(LEVEL_UP, "Level up for %s" % Format.money(cost), result == Turf.LevelResult.OK))
	choices.append(_close_choice())
	GameOverlay.talk(Content.player(run.player_id), line, choices, _on_district_choice, hint)


func _on_district_choice(choice: StringName) -> void:
	GameOverlay.end_talk()
	if choice == LEVEL_UP:
		GameState.level_up_turf(_managed_district)


func _close_choice() -> DialogueChoice:
	return DialogueChoice.new(LEAVE, "Close", true, true)


func _end_talk(_choice: StringName) -> void:
	GameOverlay.end_talk()


func _add_crew(run: RunState) -> void:
	_add_heading("CREW  %d/%d" % [run.crew.size(), Crew.cap(run)])
	if not run.career:
		_add_row(LOCK_ICON, "Crew", "", CAREER_LOCK, LOCKED)
		return
	var roles := Crew.roles(run)
	if roles.is_empty():
		_add_note("Auntie Tran knows people. Hire crew at her bar in Old Market.")
		return
	for role in roles:
		_add_row(role.icon, role.display_name, "%s a day" % Format.money(role.daily_wage), Crew.effects(role), "TAP TO LET GO", Palette.TEXT_MUTED,
			_ask.bind("Let %s go?" % role.display_name.to_lower(), "They walk away today. Hiring again costs %s." % Format.money(role.hire_cost), "Let go",
				func() -> void: GameState.fire_crew(role.id), true))


func _add_businesses(run: RunState) -> void:
	_add_heading("BUSINESSES")
	if not run.career:
		_add_row(LOCK_ICON, "Businesses", "", CAREER_LOCK, LOCKED)
		return
	for entry in run.businesses:
		var business := Content.business(StringName(entry.business))
		var district := Content.district(StringName(entry.district))
		if business == null or district == null:
			continue
		var state := "Open" if Businesses.is_open(run, entry) else "Closed"
		var caption := "%s, %d / %d stocked" % [district.display_name, Businesses.stock_used(entry), business.stock_capacity]
		_add_row(business.icon, business.display_name, state, caption, "TAP TO MANAGE", Palette.TEXT_CREAM, _manage_business.bind(entry))
	var offered: Array[StringName] = []
	for district_id: StringName in Turf.CONTESTED:
		if Businesses.slots_free(run, district_id) <= 0:
			continue
		var district := Content.district(district_id)
		for business in Content.businesses():
			var result := Businesses.check_buy(run, business, district_id)
			if result == Businesses.Result.TURF_TOO_LOW:
				continue
			if not offered.has(business.id):
				offered.append(business.id)
			var can_buy := result == Businesses.Result.OK
			var action := Callable()
			if can_buy:
				action = _ask.bind("Open a %s?" % business.display_name.to_lower(),
					"%s in %s for %s. Upkeep is %s a day. Stock it with goods and it sells them for you." % [business.display_name, district.display_name, Format.money(business.price), Format.money(business.daily_upkeep)],
					"Open it",
					func() -> void: GameState.buy_business(business, district_id))
			_add_row(business.icon, "%s in %s" % [business.display_name, district.display_name], Format.money(business.price), business.description,
				"TAP TO OPEN" if can_buy else "NOT ENOUGH CASH", Palette.TEXT_CREAM if can_buy else Palette.TEXT_MUTED, action)
	for business in Content.businesses():
		var level_reached := Turf.CONTESTED.any(func(district_id: StringName) -> bool: return Turf.level(run, district_id) >= business.min_turf_level)
		if not offered.has(business.id) and not level_reached:
			_add_row(business.icon, business.display_name, Format.money(business.price), "Raise a district you hold to level %d to open one there" % business.min_turf_level,
				"%s: TURF LEVEL %d" % [LOCKED, business.min_turf_level])


func _add_skills(run: RunState) -> void:
	_add_heading("SKILLS  %d %s" % [Skills.points_free(run), "point" if Skills.points_free(run) == 1 else "points"])
	for id in Skills.ids():
		var rank := Skills.rank_of(run, id)
		var maxed := rank >= Skills.max_rank()
		var caption := Skills.describe(id, rank if maxed else rank + 1)
		var result := Skills.check_upgrade(run, id)
		var detail := ""
		var detail_color := Palette.TEXT_MUTED
		match result:
			Skills.Result.OK:
				detail = "TAP TO LEARN"
				detail_color = Palette.TEXT_CREAM
			Skills.Result.NO_POINTS:
				detail = "NO POINTS"
			Skills.Result.RANK_TOO_LOW:
				detail = "NEEDS %s" % StreetCred.rank_name(Skills.required_cred_rank(rank + 1)).to_upper()
			Skills.Result.MAX_RANK:
				detail = "MAXED"
		var action := Callable()
		if result == Skills.Result.OK:
			action = _ask.bind("Learn %s?" % Skills.display_name(id), "%s. Only the Fixer can make you forget it." % caption, "Learn",
				func() -> void: GameState.learn_skill(id))
		_add_row(SKILL_ICONS.get(id, CRED_ICON), Skills.display_name(id), "%d/%d" % [rank, Skills.max_rank()], caption, detail, detail_color, action)


func _add_families(run: RunState) -> void:
	_add_heading("FAMILIES")
	for family in Content.families():
		var tier := Families.tier(run, family.id)
		var caption := family.pinyin
		var favour := Favours.active_for(run, family.id)
		if not favour.is_empty():
			var item := Content.item(StringName(favour.item))
			caption = "Owe %d %s by %s" % [int(favour.quantity), item.display_name, Calendar.describe(int(favour.due))]
		_add_row(family.emblem, "%s %s" % [family.chinese_name, family.english_name], "%+d" % Families.standing(run, family.id), caption, Families.tier_name(tier).to_upper(), TIER_COLORS[tier])


func _manage_business(entry: Dictionary) -> void:
	var run := GameState.run
	var business := Content.business(StringName(entry.business))
	var district := Content.district(StringName(entry.district))
	if business == null or district == null:
		return
	_managed_business = entry
	var here := run.district_id == district.id
	var line := "%s in %s. %d of %d stocked." % [business.display_name, district.display_name, Businesses.stock_used(entry), business.stock_capacity]
	if not here:
		line += " Go to %s to restock it." % district.display_name
	var choices: Array[DialogueChoice] = [
		DialogueChoice.new(STOCK, "Stock it from your bag", here and not run.inventory.is_empty() and Businesses.stock_used(entry) < business.stock_capacity),
		DialogueChoice.new(UNSTOCK, "Take the stock back", here and Businesses.stock_used(entry) > 0),
		DialogueChoice.new(LEAVE, "Leave", true, true),
	]
	GameOverlay.talk(Content.player(run.player_id), line, choices, _on_business_choice)


func _on_business_choice(choice: StringName) -> void:
	var moved := 0
	match choice:
		STOCK:
			moved = GameState.stock_business(_managed_business)
		UNSTOCK:
			moved = GameState.unstock_business(_managed_business)
	if choice == LEAVE or moved <= 0:
		GameOverlay.end_talk()
		return
	var line := "You move %d units onto the shelves." % moved if choice == STOCK else "You pack %d units back into your bag." % moved
	var next: Array[DialogueChoice] = [DialogueChoice.new(LEAVE, "Continue", true, true)]
	GameOverlay.say(line, next, func(_id: StringName) -> void: GameOverlay.end_talk(), false)


func _ask(title: String, message: String, confirm_text: String, action: Callable, destructive := false) -> void:
	_pending_action = action
	_confirm.open(title, message, confirm_text, destructive)


func _on_confirmed() -> void:
	if _pending_action.is_valid():
		_pending_action.call()
	_pending_action = Callable()


func _add_heading(text: String) -> void:
	var label := Label.new()
	label.theme_type_variation = &"ListHeading"
	label.text = text
	_list.add_child(label)


func _add_note(text: String) -> void:
	var label := Label.new()
	label.theme_type_variation = &"MutedLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	_list.add_child(label)


func _add_row(icon: Texture2D, title: String, value: String, caption: String, detail := "", detail_color := Palette.TEXT_MUTED, action := Callable()) -> void:
	var row: ItemRow = ITEM_ROW.instantiate()
	_list.add_child(row)
	row.show_entry(icon, title, value, caption, detail, detail_color)
	if action.is_valid():
		row.item_selected.connect(func(_item: ItemDef) -> void: action.call())
	else:
		row.disabled = true
