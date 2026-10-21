class_name TurfSheet
extends BottomSheet

const ITEM_ROW := preload("res://ui/components/item_row.tscn")
const CRED_ICON: Texture2D = preload("res://assets/icons/hud/zap.svg")
const LOCK_ICON: Texture2D = preload("res://assets/icons/hud/lock.svg")
const BANK_ICON: Texture2D = preload("res://assets/icons/hud/landmark.svg")
const CASH_ICON: Texture2D = preload("res://assets/icons/hud/banknote.svg")
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
const LAUNDER_MAX: StringName = &"launder_max"
const LAUNDER_HALF: StringName = &"launder_half"
const UPGRADE: StringName = &"upgrade"
const LEAVE: StringName = &"leave"
const BLOCK: StringName = &"block"
const HEADQUARTERS: StringName = &"headquarters"
const DISTRICT_BUSINESSES: Array[Dictionary] = [
	{ "district": &"old_market", "business": &"corner_shop" },
	{ "district": &"slums", "business": &"bakery" },
	{ "district": &"docks", "business": &"pawn_shop" },
	{ "district": &"warehouse_row", "business": &"car_wash" },
	{ "district": &"riverside", "business": &"gym" },
	{ "district": &"west_end", "business": &"restaurant" },
	{ "district": &"north_port", "business": &"restaurant" },
	{ "district": &"downtown", "business": &"shark" },
	{ "district": &"downtown", "business": &"lounge" },
	{ "district": &"the_heights", "business": &"boutique" },
	{ "district": &"golden_mile", "business": &"nightclub" },
]
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
	&"laundering": "Offshore & Banking",
}
## Pages opened from the holdings go back to the holdings.
const SECTION_PARENTS := {
	&"districts": HEADQUARTERS,
	&"crew": HEADQUARTERS,
	&"skills": HEADQUARTERS,
	&"businesses": HEADQUARTERS,
	&"families": HEADQUARTERS,
	&"laundering": HEADQUARTERS,
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
	SafeArea.apply_top_margin(_margin)
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
	Utils.clear_container(_list)
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
		&"laundering":
			_add_laundering(run)
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
		var family := Turf.home_family(district.id)
		if family != null:
			var f_hint := "Earn Trusted standing with the %s to open high-end fronts in %s." % [family.english_name, district.display_name]
			if Turf.holds(run, district.id):
				f_hint = "The %s trusts you. You can open up to %d front%s here." % [
					family.english_name, Turf.business_slots(run, district.id), "" if Turf.business_slots(run, district.id) == 1 else "s"]
			GameOverlay.talk(Content.player(run.player_id), "%s belongs to the %s. Street crews do not fight for corners here." % [district.display_name, family.english_name], [_close_choice()], _end_talk, f_hint)
			return
		GameOverlay.talk(Content.player(run.player_id), "%s is open city. Nobody runs these streets." % district.display_name, [_close_choice()], _end_talk)
		return
	var owners := Gangs.owners(district.id)
	var rival_names := "%s and %s" % [owners[0].display_name, owners[1].display_name] if owners.size() > 1 else owners[0].display_name
	var verb := "split" if owners.size() > 1 else "has"
	var line := "I hold %d of the %d corners in %s. %s %s the rest." % [
		Corners.held_count(run, district.id), Corners.of(district.id).size(), district.display_name, rival_names, verb]
	var hint := "Take %d%% of the corners to hold it. Scout a corner first, then hit it." % Turf.HOLD_SHARE
	if Turf.holds(run, district.id):
		hint = "Yours. The police stop you less and there is room for %d business%s." % [
			Turf.business_slots(run, district.id), "" if Turf.business_slots(run, district.id) == 1 else "es"]
	elif not War.can_invade_district(run, district.id):
		hint = "Invasion locked: %s." % War.invasion_lock_reason(run, district.id)
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
	if roles.is_empty() and not Campaign.is_act_two(run):
		_add_note("Auntie Tran knows people. Hire crew at her bar in Old Market.")
		return
	if Campaign.is_act_two(run):
		var proven := VexTalk.passed_rabbit_test(run)
		_add_row(SKILL_ICONS[&"muscle"], "Lieutenant, Vex", "Free",
			"Stationed in Old Market managing district protection and lookouts." if proven else "Rabbit wants you to take one corner in The Slums before Vex opens her desk.")
	for role in roles:
		if Crew.is_jailed(run, role.id):
			var bail := Crew.bail_cost(run, role.id)
			_add_row(role.icon, "%s (In Jail)" % role.display_name, "Bail: %s" % Format.money(bail),
				"Booked in custody. Inactive until bail is posted.", "TAP TO BAIL OUT", Palette.RISK_HIGH,
				_ask.bind("Post bail for %s?" % role.display_name.to_lower(), "Pay %s to release them from custody immediately." % Format.money(bail), "Pay bail",
					func() -> void:
						if GameState.bail_crew(role.id):
							AudioService.play_sfx(Sfx.COINS_OUT)
							_rebuild(), true))
			continue
		if Crew.is_informant(run, role.id):
			_add_row(role.icon, "%s (Suspected Informant)" % role.display_name, "%s a day" % Format.money(role.daily_wage),
				"Leaking movement intel to Detective Ramos (+80% police stop chance).", "FIRE TO PLUG LEAK", Palette.RISK_HIGH,
				_ask.bind("Fire suspected informant?", "Let %s go to plug the police leak. Hiring again costs %s." % [role.display_name.to_lower(), Format.money(role.hire_cost)], "Fire",
					func() -> void:
						GameState.fire_crew(role.id)
						_rebuild(), true))
			continue
		if Crew.is_free_role(run, role.id):
			_add_row(role.icon, "%s, %s" % [role.display_name, "the Shark" if run.shark_bought else "午夜兔子"], "Free", Crew.effects(role))
			continue
		_add_row(role.icon, role.display_name, "%s a day" % Format.money(role.daily_wage), Crew.effects(role), "TAP TO LET GO", Palette.TEXT_MUTED,
			_ask.bind("Let %s go?" % role.display_name.to_lower(), "They walk away today. Hiring again costs %s." % Format.money(role.hire_cost), "Let go",
				func() -> void: GameState.fire_crew(role.id), true))


func _add_businesses(run: RunState) -> void:
	_add_heading("DISTRICT BUSINESSES")
	if not Campaign.is_act_two(run):
		_add_row(LOCK_ICON, "Businesses", "", CAREER_LOCK, LOCKED)
		return

	for def in DISTRICT_BUSINESSES:
		var dist_id: StringName = def.district
		var biz_id: StringName = def.business
		var district := Content.district(dist_id)
		if district == null:
			continue

		if biz_id == &"shark":
			if run.shark_bought:
				_add_row(CRED_ICON, "The Shark in Downtown", "Owned", "Private lending desk active. Dealers come to you for cash loans.", "MANAGE", Palette.TEXT_CREAM, func() -> void:
					close()
					run.district_id = &"downtown"
					StreetTalk.talk_to(Content.character(Loan.LENDER))
				)
			else:
				var can_buy_shark := Lending.can_buy_out(run) and run.cash >= Lending.BUYOUT_PRICE
				var detail := "BUYOUT"
				if run.debt > 0:
					detail = "PAY DEBT FIRST"
				elif run.shark_sale_day > run.day:
					detail = "OFFER IN %d DAYS" % maxi(1, run.shark_sale_day - run.day)
				elif run.cash < Lending.BUYOUT_PRICE:
					detail = "NOT ENOUGH CASH"
				var color := Palette.TEXT_CREAM if can_buy_shark else Palette.TEXT_MUTED
				var action := Callable()
				if can_buy_shark:
					action = _ask.bind("Buy out the Shark?", "Retire the Shark for %s and take over his private lending book in Downtown." % Format.money(Lending.BUYOUT_PRICE), "Buy Out", func() -> void:
						run.district_id = &"downtown"
						if Lending.buy_out(run):
							_rebuild()
					)
				_add_row(CRED_ICON, "The Shark in Downtown", Format.money(Lending.BUYOUT_PRICE), "Buy out his desk in Downtown to take over street lending.", detail, color, action)
			continue

		var business := Content.business(biz_id)
		if business == null:
			continue

		var owned_entry: Dictionary = {}
		for entry in run.businesses:
			if str(entry.get("business", "")) == String(biz_id) and str(entry.get("district", "")) == String(dist_id):
				owned_entry = entry
				break

		if not owned_entry.is_empty():
			var state := "Open" if Businesses.is_open(run, owned_entry) else "Closed"
			var lvl := Businesses.level_of(owned_entry)
			var rev := Businesses.daily_revenue(business, 0.5, lvl)
			var upkeep := business.effective_upkeep(lvl)
			var caption := "%s | Lvl %d/5 | Net: +%s/d clean (Upkeep: %s)" % [
				district.display_name,
				lvl,
				Format.money_short(rev - upkeep),
				Format.money_short(upkeep)
			]
			_add_row(business.icon, "%s in %s" % [business.display_name, district.display_name], state, caption, "MANAGE", Palette.TEXT_CREAM, _manage_business.bind(owned_entry))
		else:
			var result := Businesses.check_buy(run, business, dist_id)
			if result == Businesses.Result.NOT_HELD:
				var home_fam := Turf.home_family(dist_id)
				var lock_msg := "Hold %s to open" % district.display_name
				if not Turf.is_contested(dist_id) and home_fam != null:
					lock_msg = "Requires Trusted with %s" % home_fam.english_name
				_add_row(business.icon, "%s in %s" % [business.display_name, district.display_name], Format.money(business.price), lock_msg, LOCKED, Palette.TEXT_MUTED)
			elif result == Businesses.Result.RANK_TOO_LOW:
				_add_row(business.icon, "%s in %s" % [business.display_name, district.display_name], Format.money(business.price), "Requires %s" % StreetCred.rank_name(business.min_rank), LOCKED, Palette.TEXT_MUTED)
			else:
				var can_buy := result == Businesses.Result.OK
				var action := Callable()
				if can_buy:
					action = _ask.bind("Open a %s?" % business.display_name.to_lower(),
						"%s in %s for %s. Upkeep is %s a day. Generates passive clean income." % [business.display_name, district.display_name, Format.money(business.price), Format.money(business.effective_upkeep(1))],
						"Open it",
						func() -> void: GameState.buy_business(business, dist_id))
				_add_row(business.icon, "%s in %s" % [business.display_name, district.display_name], Format.money(business.price), business.description,
					"TAP TO OPEN" if can_buy else "NOT ENOUGH CASH", Palette.TEXT_CREAM if can_buy else Palette.TEXT_MUTED, action)


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
	if business == null or district == null or run == null:
		return
	_managed_business = entry
	var lvl := Businesses.level_of(entry)
	var rev := Businesses.daily_revenue(business, 0.5, lvl)
	var upkeep := business.effective_upkeep(lvl)
	var is_open := Businesses.is_open(run, entry)
	var can_up := Businesses.can_upgrade(run, entry)
	var next_cost := business.upgrade_cost(lvl)

	var line := "%s in %s (Level %d/%d). Daily clean revenue: +%s, upkeep: %s. Net profit: +%s/day." % [
		business.display_name, district.display_name, lvl, BusinessDef.MAX_LEVEL,
		Format.money(rev), Format.money(upkeep), Format.money(rev - upkeep)
	]

	var choices: Array[DialogueChoice] = []
	if not is_open:
		line += " Business is currently CLOSED due to unpaid upkeep."
		choices.append(DialogueChoice.new(LEAVE, "Leave", true, true))
	else:
		if lvl < BusinessDef.MAX_LEVEL:
			var next_rev := Businesses.daily_revenue(business, 0.5, lvl + 1)
			choices.append(DialogueChoice.new(
				UPGRADE,
				"Upgrade to Level %d for %s (boosts to +%s/d clean)" % [lvl + 1, Format.money(next_cost), Format.money(next_rev)],
				can_up
			))
		else:
			line += " Business is fully MAXED OUT at Level 5."
		choices.append(DialogueChoice.new(LEAVE, "Leave", true, true))

	GameOverlay.talk(Content.player(run.player_id), line, choices, _on_business_choice)


func _on_business_choice(choice: StringName) -> void:
	var run := GameState.run
	if choice == LEAVE or run == null or _managed_business.is_empty():
		GameOverlay.end_talk()
		return
	if choice == UPGRADE:
		var ok := Businesses.upgrade(run, _managed_business)
		if not ok:
			GameOverlay.end_talk()
			return
		var business := Content.business(StringName(_managed_business.business))
		var new_lvl := Businesses.level_of(_managed_business)
		var line := "You upgraded %s to Level %d! Daily clean revenue increased." % [
			business.display_name if business != null else "Business", new_lvl
		]
		var next: Array[DialogueChoice] = [DialogueChoice.new(LEAVE, "Continue", true, true)]
		GameOverlay.say(line, next, func(_id: StringName) -> void:
			GameOverlay.end_talk()
			_rebuild()
		, false)


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


func _add_laundering(run: RunState) -> void:
	_add_heading("BANK BALANCE")
	var withdraw_act := Callable()
	var detail := ""
	var detail_color := Palette.TEXT_MUTED
	if run.clean > 0:
		detail = "WITHDRAW"
		detail_color = Palette.PEACH_BRIGHT
		withdraw_act = _withdraw_dialog.bind(run)
	_add_row(BANK_ICON, "Clean Bank Balance", Format.money(run.clean), "Clean funds in the bank. Raids and seizures cannot touch them.", detail, detail_color, withdraw_act)

	_add_heading("IN TRANSIT")
	if run.laundering.is_empty():
		_add_note("No funds currently clearing through channels.")
	else:
		for batch in run.laundering:
			var days: int = int(batch.get("days_left", 1))
			var dirty: int = int(batch.get("dirty_amount", 0))
			var fee: float = float(batch.get("fee", 0.0))
			var clean_est := dirty - floori(dirty * fee)
			var inst_id := StringName(batch.get("instrument", batch.get("business", "")))
			var item := Content.item(inst_id)
			var inst_name := item.display_name if item != null else String(inst_id).capitalize()
			var icon: Texture2D = item.icon if item != null and item.icon != null else CASH_ICON
			var days_str := "1 day left" if days == 1 else "%d days left" % days
			var caption := "%s sent (fee: %d%%) -> +%s clean" % [Format.money(dirty), roundi(fee * 100.0), Format.money(clean_est)]
			_add_row(icon, inst_name, days_str, caption)

	_add_heading("FINANCIAL INSTRUMENTS")
	_add_note("Clean dirty street cash through financial paper. Buy documents on the market or stash them in the safehouse.")
	for inst in Money.all_instruments():
		var id: StringName = inst.id
		var name: String = inst.name
		var cap: int = inst.cap
		var fee: float = inst.fee
		var days: int = inst.days
		var free_cap := Money.instrument_capacity_free(run, id)
		var item := Content.item(id)
		var icon: Texture2D = item.icon if item != null and item.icon != null else CASH_ICON
		if Money.has_instrument(run, id):
			var caption := "Cap: %s (free: %s) | Fee: %d%% | Clears in %d %s" % [
				Format.money(cap),
				Format.money(free_cap),
				roundi(fee * 100.0),
				days,
				"day" if days == 1 else "days"
			]
			var can_clean := free_cap > 0 and run.cash > 0
			var row_detail := "CLEAN CASH" if can_clean else ("NO CASH" if run.cash <= 0 else "CHANNEL FULL")
			var row_color := Palette.TEXT_CREAM if can_clean else Palette.TEXT_MUTED
			var action := _clean_cash_dialog.bind(id) if can_clean else Callable()
			_add_row(icon, name, "%d%% fee" % roundi(fee * 100.0), caption, row_detail, row_color, action)
		else:
			var caption := "Requires %s in bag or safehouse. Buy on the market." % name
			_add_row(icon, name, LOCKED, caption, "LOCKED", Palette.TEXT_MUTED)


func _withdraw_dialog(run: RunState) -> void:
	var choices: Array[DialogueChoice] = []
	var line := "Clean bank balance: %s. How much do you want to withdraw into cash?" % Format.money(run.clean)
	if run.clean >= Money.WITHDRAWAL_HEAT_THRESHOLD:
		line += "\nWarning: withdrawals of $5,000+ attract police heat frenzy."
	if run.clean >= 10000:
		choices.append(DialogueChoice.new(&"w_10k", "Withdraw $10,000", true))
	if run.clean >= 50000:
		choices.append(DialogueChoice.new(&"w_50k", "Withdraw $50,000", true))
	choices.append(DialogueChoice.new(&"w_all", "Withdraw All (%s)" % Format.money(run.clean), true))
	choices.append(DialogueChoice.new(LEAVE, "Leave", true, true))

	GameOverlay.talk(Content.player(run.player_id), line, choices, func(choice: StringName) -> void:
		GameOverlay.end_talk()
		if choice == LEAVE:
			return
		var amt := 0
		match choice:
			&"w_10k": amt = 10000
			&"w_50k": amt = 50000
			&"w_all": amt = run.clean
		if amt > 0:
			GameState.withdraw_clean(amt)
			_rebuild()
	)


func _clean_cash_dialog(instrument_id: StringName) -> void:
	var run := GameState.run
	if run == null:
		return
	var inst := Money.instrument_def(instrument_id)
	if inst.is_empty():
		return
	var free_cap := Money.instrument_capacity_free(run, instrument_id)
	var max_amt := mini(run.cash, free_cap)
	if max_amt <= 0:
		return
	var fee: float = float(inst.get("fee", 0.15))
	var days: int = int(inst.get("days", 3))
	var name: String = str(inst.get("name", "Channel"))

	var line := "Route dirty cash into %s. Fee: %d%%, clearing in %d %s.\nAvailable dirty cash: %s (Channel free cap: %s)" % [
		name,
		roundi(fee * 100.0),
		days,
		"day" if days == 1 else "days",
		Format.money(run.cash),
		Format.money(free_cap)
	]

	var choices: Array[DialogueChoice] = []
	if max_amt >= 20000:
		choices.append(DialogueChoice.new(&"c_20k", "Clean $20,000 (Fee: %s)" % Format.money(floori(20000 * fee)), true))
	if max_amt >= 100000:
		choices.append(DialogueChoice.new(&"c_100k", "Clean $100,000 (Fee: %s)" % Format.money(floori(100000 * fee)), true))
	if max_amt >= 500000:
		choices.append(DialogueChoice.new(&"c_500k", "Clean $500,000 (Fee: %s)" % Format.money(floori(500000 * fee)), true))
	choices.append(DialogueChoice.new(&"c_max", "Clean Max: %s (Fee: %s)" % [Format.money(max_amt), Format.money(floori(max_amt * fee))], true))
	choices.append(DialogueChoice.new(LEAVE, "Leave", true, true))

	GameOverlay.talk(Content.player(run.player_id), line, choices, func(choice: StringName) -> void:
		GameOverlay.end_talk()
		if choice == LEAVE:
			return
		var amt := 0
		match choice:
			&"c_20k": amt = 20000
			&"c_100k": amt = 100000
			&"c_500k": amt = 500000
			&"c_max": amt = max_amt
		amt = mini(amt, max_amt)
		if amt > 0:
			GameState.start_instrument_laundering(instrument_id, amt)
			_rebuild()
	)
