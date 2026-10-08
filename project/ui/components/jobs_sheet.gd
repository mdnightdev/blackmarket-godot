class_name JobsSheet
extends BottomSheet

const JOB_ROW := preload("res://ui/components/job_row.tscn")
const READY_HINT := "IN BAG"
const TASK_ICON: Texture2D = preload("res://assets/icons/hud/list-checks.svg")
const LOCK_ICON: Texture2D = preload("res://assets/icons/hud/lock.svg")
const HEADING_INDENT := 24
const CONTINUE: StringName = &"continue"

@onready var _margin: MarginContainer = %Margin
@onready var _list: VBoxContainer = %List
@onready var _confirm: ConfirmDialog = %ConfirmDialog

var _pending_heist: HeistDef


func _ready() -> void:
	super()
	GameState.run_changed.connect(_on_run_changed)
	_confirm.confirmed.connect(_on_heist_confirmed)


func open_jobs() -> void:
	SafeArea.apply_top_margin(_margin, 24)
	_rebuild()
	open_sheet()


## Back closes an open confirmation before the page itself.
func close_modal() -> bool:
	if not _confirm.visible:
		return false
	_confirm.close()
	return true


func _on_run_changed() -> void:
	if visible:
		_rebuild.call_deferred()


func _rebuild() -> void:
	var run := GameState.run
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_add_tasks(run)
	_add_active(run)
	_add_heists(run)


func _add_tasks(run: RunState) -> void:
	if run.daily_tasks.is_empty():
		return
	_add_heading("TODAY")
	for task in run.daily_tasks:
		var done := bool(task.done)
		_add_row(TASK_ICON, DailyTasks.describe(task), Format.money(DailyTasks.reward(run)), DailyTasks.progress_text(task), "DONE" if done else "+%d CRED" % StreetCred.TASK_DONE)


func _add_active(run: RunState) -> void:
	_add_heading("ACTIVE")
	var count := _list.get_child_count()
	for order in run.orders:
		var item := Content.item(StringName(order.item))
		var dealer := Content.dealer(StringName(order.dealer))
		if item == null or dealer == null:
			continue
		var district := Content.district(dealer.district_id)
		var place := " in %s" % district.display_name if district != null else ""
		var caption := "Buy them, then deliver to %s%s by %s" % [dealer.display_name, place, Calendar.describe(int(order.due)).to_lower()]
		_add_row(item.icon, "%d %s" % [int(order.quantity), item.display_name], Format.money(Orders.total(order)), caption, _goods_hint(run, item, int(order.quantity)))

	for favour in run.favours:
		var item := Content.item(StringName(favour.item))
		var family := Content.family(StringName(favour.family))
		var lieutenant := Content.character(family.lieutenant) if family != null else null
		if item == null or lieutenant == null:
			continue
		var caption := "Buy them, then hand them to %s by %s" % [lieutenant.display_name, Calendar.describe(int(favour.due)).to_lower()]
		_add_row(item.icon, "%d %s" % [int(favour.quantity), item.display_name], Format.money(Favours.total(favour)), caption, _goods_hint(run, item, int(favour.quantity)))

	if Smuggling.is_carrying(run):
		var hint := "DELIVER HERE" if Smuggling.can_deliver(run) else ""
		_add_row(Smuggling.CRATE_ICON, "Voronin's crate", Format.money(Smuggling.payout(run, run.crate)), Smuggling.describe(run.crate), hint)

	if _list.get_child_count() == count:
		_add_note("No jobs taken. Bars post delivery orders, Pier 9 has crates, and the families hand out favours.")


func _goods_hint(run: RunState, item: ItemDef, quantity: int) -> String:
	var held := Inventory.count(run, item.id)
	return READY_HINT if held >= quantity else "HAVE %d/%d" % [held, quantity]


func _add_heists(run: RunState) -> void:
	_add_heading("HEISTS")
	if not run.career:
		_add_row(LOCK_ICON, "Heists", "", "Pay off the Shark to unlock", "")
		return
	for heist in Content.heists():
		var district := Content.district(heist.district_id)
		var place := district.display_name if district != null else ""
		var result := Heists.check(run, heist)
		var hint := ""
		var hint_color := Palette.TEXT_MUTED
		match result:
			Heists.Result.OK:
				hint = "PULL IT %d%%" % roundi(Heists.success_chance(run, heist) * 100.0)
				hint_color = Palette.TEXT_CREAM
			Heists.Result.RANK_TOO_LOW:
				hint = "NEEDS %s" % StreetCred.rank_name(heist.min_rank).to_upper()
			Heists.Result.MISSING_CREW:
				hint = "NEEDS %s" % _role_names(Heists.missing_roles(run, heist)).to_upper()
			Heists.Result.COOLDOWN:
				var days := Heists.days_until_ready(run, heist)
				hint = "READY IN %d %s" % [days, "DAY" if days == 1 else "DAYS"]
			Heists.Result.WRONG_DISTRICT:
				hint = "GO TO %s" % place.to_upper()
		var row := _add_row(heist.icon, heist.display_name, Format.money(heist.payout), "%s. %s" % [place, heist.description], hint, hint_color)
		if result == Heists.Result.OK:
			row.set_tappable(true)
			row.pressed.connect(_ask_heist.bind(heist))


func _ask_heist(heist: HeistDef) -> void:
	var run := GameState.run
	_pending_heist = heist
	var message := "%d%% chance. Success pays %s and adds %d heat. Failure adds %d heat, brings the police, and can cost you a crew member." % [
		roundi(Heists.success_chance(run, heist) * 100.0), Format.money(heist.payout), heist.heat, Heists.FAILED_HEAT,
	]
	_confirm.open("Pull the %s?" % heist.display_name.to_lower(), message, "Pull it", true)


func _on_heist_confirmed() -> void:
	var heist := _pending_heist
	_pending_heist = null
	if heist == null:
		return
	var outcome := GameState.pull_heist(heist)
	if outcome.is_empty():
		return
	var line := ""
	if bool(outcome.success):
		line = "The %s goes clean. You walk away with %s." % [heist.display_name.to_lower(), Format.money(int(outcome.payout))]
		AudioService.play_sfx(Sfx.CHIPS_WIN)
	else:
		line = "The %s goes wrong. Sirens close in from every side." % heist.display_name.to_lower()
		var lost := Content.crew_role(StringName(str(outcome.lost_role)))
		if lost != null:
			line += " Your %s gets picked up and will not be back." % lost.display_name.to_lower()
		AudioService.play_sfx(Sfx.CAUGHT)
	close()
	var choices: Array[DialogueChoice] = [DialogueChoice.new(CONTINUE, "Continue", true, true)]
	GameOverlay.talk(Content.player(GameState.run.player_id), line, choices, func(_id: StringName) -> void: GameOverlay.end_talk())


func _role_names(role_ids: Array[StringName]) -> String:
	var names: PackedStringArray = []
	for role_id in role_ids:
		var role := Content.crew_role(role_id)
		names.append(role.display_name if role != null else String(role_id))
	return ", ".join(names)


func _add_heading(text: String) -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", HEADING_INDENT)
	margin.add_theme_constant_override("margin_right", HEADING_INDENT)
	var label := Label.new()
	label.theme_type_variation = &"ListHeading"
	label.text = text
	margin.add_child(label)
	_list.add_child(margin)


func _add_note(text: String) -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", HEADING_INDENT)
	margin.add_theme_constant_override("margin_right", HEADING_INDENT)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	var label := Label.new()
	label.theme_type_variation = &"MutedLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	margin.add_child(label)
	_list.add_child(margin)


func _add_row(icon: Texture2D, title: String, pay: String, caption: String, hint: String, hint_color := Color.TRANSPARENT) -> JobRow:
	var row: JobRow = JOB_ROW.instantiate()
	_list.add_child(row)
	row.show_job(icon, title, pay, caption, hint, hint_color)
	return row
