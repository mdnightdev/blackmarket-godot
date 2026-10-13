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
const CAREER_LOCK := "Take Old Market from Vex to unlock"
const ACT_ONE_STATUS := "Locked: take Old Market"
const LOCKED := "LOCKED"
const STOCK: StringName = &"stock"
const UNSTOCK: StringName = &"unstock"
const LEAVE: StringName = &"leave"
const BLOCK: StringName = &"block"
const HEADQUARTERS: StringName = &"headquarters"
const SECTION_TITLES := {
	BLOCK: "Turf",
	HEADQUARTERS: "Holdings",
	&"armory": "Armory",
	&"hospital": "Hospital",
	&"gym": "Gym",
	&"safehouse": "Safehouse",
	&"crew": "Crew",
	&"districts": "Districts",
	&"businesses": "Businesses",
	&"skills": "Skills",
	&"families": "Families",
}
## Pages opened from the holdings go back to the holdings.
const SECTION_PARENTS := {
	&"districts": HEADQUARTERS,
	&"crew": HEADQUARTERS,
	&"skills": HEADQUARTERS,
}

@onready var _margin: MarginContainer = %Margin
@onready var _list: VBoxContainer = %List
@onready var _list_margin: MarginContainer = %ListMargin
@onready var _headquarters: TurfScene = %Headquarters
@onready var _cred_label: Label = %CredLabel
@onready var _title: Label = %Title
@onready var _confirm: ConfirmDialog = %ConfirmDialog

var _pending_action := Callable()
var _managed_business: Dictionary = {}
var _section := BLOCK


func _ready() -> void:
	super()
	GameState.run_changed.connect(_on_run_changed)
	_confirm.confirmed.connect(_on_confirmed)
	_headquarters.building_tapped.connect(_show_section)


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
		_show_section(SECTION_PARENTS.get(_section, BLOCK))
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
	_cred_label.text = "%s  %d cred" % [StreetCred.rank_name(StreetCred.rank(run)), run.street_cred]
	_title.text = SECTION_TITLES.get(_section, "Turf")
	_headquarters.visible = _section == BLOCK
	_list_margin.visible = _section != BLOCK
	match _section:
		HEADQUARTERS:
			var holdings := HoldingsSection.new()
			holdings.section_requested.connect(_show_section)
			_list.add_child(holdings)
		&"armory":
			_list.add_child(ArmorySection.new())
		&"hospital":
			_list.add_child(HospitalSection.new())
		&"gym":
			_list.add_child(GymSection.new())
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
			_update_headquarters(run)


func _update_headquarters(run: RunState) -> void:
	_headquarters.set_status(HEADQUARTERS, "+%s a day" % Format.money(Turf.daily_cut(run)),
		TurfScene.Status.NEEDS_YOU if HoldingsSection.needs_attention(run) else TurfScene.Status.OPEN)
	var safehouse_open := Safehouse.is_open(run)
	_headquarters.set_status(&"safehouse", "Open here" if safehouse_open else "Hold this district to open", TurfScene.Status.OPEN if safehouse_open else TurfScene.Status.LOCKED)
	if Armory.unlocked(run):
		_headquarters.set_status(&"armory", "%d men, %d weapons" % [Army.total(run), Armory.total(run)], TurfScene.Status.OPEN)
		var wounded := Army.wounded(run)
		if wounded > 0:
			_headquarters.set_status(&"hospital", "%d wounded" % wounded, TurfScene.Status.NEEDS_YOU)
		else:
			_headquarters.set_status(&"hospital", "%s beds" % Format.count(Hospital.beds(run)), TurfScene.Status.OPEN)
	else:
		_headquarters.set_status(&"armory", "Locked: buy a corner", TurfScene.Status.LOCKED)
		_headquarters.set_status(&"hospital", "Locked: buy a corner", TurfScene.Status.LOCKED)
	if Gym.is_open(run):
		_headquarters.set_status(&"gym", "%s men" % Format.count(Army.total(run)), TurfScene.Status.OPEN)
	else:
		_headquarters.set_status(&"gym", "Locked: 午夜兔子 runs it", TurfScene.Status.LOCKED)
	if Campaign.is_act_two(run):
		_headquarters.set_status(&"businesses", "%d open" % run.businesses.size(), TurfScene.Status.OPEN)
	else:
		_headquarters.set_status(&"businesses", ACT_ONE_STATUS, TurfScene.Status.LOCKED)
	_headquarters.set_status(&"families", "%d trust you" % Families.trusted_count(run), TurfScene.Status.OPEN)


func _add_districts(run: RunState) -> void:
	_add_heading("TERRITORY")
	var map := TurfMap.new()
	map.district_tapped.connect(_talk_about_district)
	_list.add_child(map)
	_add_note("Green is yours, gang colours are theirs, grey is still in play. Tap a district for its details.")


func _talk_about_district(district: DistrictDef) -> void:
	var run := GameState.run
	if not Turf.is_contested(district.id):
		GameOverlay.talk(Content.player(run.player_id), "%s is open city. Nobody runs these streets." % district.display_name, [_close_choice()], _end_talk)
		return
	var line := "I hold %d of the %d corners in %s. %s has the rest." % [
		Corners.held_count(run, district.id), Corners.of(district.id).size(), district.display_name, Gangs.owner(district.id).display_name]
	var hint := "Take %d%% of the corners to hold it. Scout a corner first, then hit it." % Turf.HOLD_SHARE
	if Turf.holds(run, district.id):
		hint = "Yours. The police stop you less and there is room for %d business%s." % [
			Turf.business_slots(run, district.id), "" if Turf.business_slots(run, district.id) == 1 else "es"]
	GameOverlay.talk(Content.player(run.player_id), line, [_close_choice()], _end_talk, hint)


func _close_choice() -> DialogueChoice:
	return DialogueChoice.new(LEAVE, "Close", true, true)


func _end_talk(_choice: StringName) -> void:
	GameOverlay.end_talk()


func _add_crew(run: RunState) -> void:
	_add_heading("CREW  %d/%d" % [Crew.hired_count(run), Crew.cap(run)])
	if not Campaign.is_act_two(run) and run.crew.is_empty():
		_add_row(LOCK_ICON, "Crew", "", CAREER_LOCK, LOCKED)
		return
	var roles := Crew.roles(run)
	if roles.is_empty():
		_add_note("Auntie Tran knows people. Hire crew at her bar in Old Market.")
		return
	for role in roles:
		if Crew.is_free_role(run, role.id):
			_add_row(role.icon, "%s, %s" % [role.display_name, "the Shark" if run.shark_bought else "午夜兔子"], "Free", Crew.effects(role))
			continue
		_add_row(role.icon, role.display_name, "%s a day" % Format.money(role.daily_wage), Crew.effects(role), "TAP TO LET GO", Palette.TEXT_MUTED,
			_ask.bind("Let %s go?" % role.display_name.to_lower(), "They walk away today. Hiring again costs %s." % Format.money(role.hire_cost), "Let go",
				func() -> void: GameState.fire_crew(role.id), true))


func _add_businesses(run: RunState) -> void:
	_add_heading("BUSINESSES")
	if not Campaign.is_act_two(run):
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
	for district_id: StringName in Turf.contested():
		if Businesses.slots_free(run, district_id) <= 0:
			continue
		var district := Content.district(district_id)
		for business in Content.businesses():
			var result := Businesses.check_buy(run, business, district_id)
			if result in [Businesses.Result.NOT_HELD, Businesses.Result.RANK_TOO_LOW]:
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
		if not offered.has(business.id) and StreetCred.rank(run) < business.min_rank:
			_add_row(business.icon, business.display_name, Format.money(business.price), "Opens in a district you hold once you reach %s" % StreetCred.rank_name(business.min_rank),
				"%s: %s" % [LOCKED, StreetCred.rank_name(business.min_rank).to_upper()])


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
