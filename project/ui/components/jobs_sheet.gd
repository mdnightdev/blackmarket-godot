class_name JobsSheet
extends BottomSheet

const JOB_ROW := preload("res://ui/components/job_row.tscn")
const READY_HINT := "IN BAG"
const TASK_ICON: Texture2D = preload("res://assets/icons/hud/list-checks.svg")
const LOCK_ICON: Texture2D = preload("res://assets/icons/hud/lock.svg")
const INVOICE_ICON: Texture2D = preload("res://assets/icons/hud/clipboard-list.svg")
const HEADING_INDENT := 24
const CONTINUE: StringName = &"continue"

enum Tab { ACTIVE, COMPLETED, FAILED }

@onready var _margin: MarginContainer = %Margin
@onready var _list: VBoxContainer = %List
@onready var _confirm: ConfirmDialog = %ConfirmDialog
@onready var _active_tab: Button = %ActiveTab
@onready var _completed_tab: Button = %CompletedTab
@onready var _failed_tab: Button = %FailedTab

var _pending_action := Callable()
var _tab := Tab.ACTIVE


func _ready() -> void:
	super()
	GameState.run_changed.connect(_on_run_changed)
	_confirm.confirmed.connect(_on_confirmed)
	var tabs := ButtonGroup.new()
	for tab_button: Button in [_active_tab, _completed_tab, _failed_tab]:
		tab_button.button_group = tabs
	_active_tab.pressed.connect(_select_tab.bind(Tab.ACTIVE))
	_completed_tab.pressed.connect(_select_tab.bind(Tab.COMPLETED))
	_failed_tab.pressed.connect(_select_tab.bind(Tab.FAILED))


func open_jobs() -> void:
	SafeArea.apply_top_margin(_margin, 24)
	_tab = Tab.ACTIVE
	_active_tab.button_pressed = true
	_rebuild()
	open_sheet()


func _select_tab(tab: Tab) -> void:
	_tab = tab
	_rebuild()


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
	match _tab:
		Tab.COMPLETED:
			_add_history(run, false)
		Tab.FAILED:
			_add_history(run, true)
		_:
			_add_tasks(run)
			_add_offers(run)
			_add_active(run)
			_add_owed(run)
			_add_heists(run)


func _add_history(run: RunState, failed: bool) -> void:
	var entries := Journal.entries(run, failed)
	if entries.is_empty():
		_add_note("No failed jobs. Keep it that way." if failed else "Nothing finished yet. Delivered orders, errands and crates show up here.")
		return
	for entry in entries:
		var place := str(entry.place)
		var caption := Calendar.describe(int(entry.stamp))
		if not place.is_empty():
			caption = "%s. %s" % [place, caption]
		var hint := "FAILED" if failed else "DONE"
		_add_row(LOCK_ICON if failed else TASK_ICON, str(entry.title), "", caption, hint, Palette.RISK_HIGH if failed else Palette.RISK_LOW)


func _add_tasks(run: RunState) -> void:
	if run.daily_tasks.is_empty():
		return
	_add_heading("TODAY")
	for task in run.daily_tasks:
		var done := bool(task.done)
		_add_row(TASK_ICON, DailyTasks.describe(task), Format.money(DailyTasks.reward(run)), DailyTasks.progress_text(task), "DONE" if done else "+%d CRED" % StreetCred.TASK_DONE)


## Unanswered phone offers. Tapping one opens the same prompt as the banner.
func _add_offers(run: RunState) -> void:
	if run.errand_offers.is_empty() and run.customer_offers.is_empty():
		return
	_add_heading("OFFERS")
	for offer in run.errand_offers:
		var sender := Content.character(StringName(str(offer.sender)))
		if sender == null:
			continue
		var caption := "From %s. %d phases to finish once taken" % [sender.display_name, int(offer.lead)]
		var row := _add_offer_row(sender.portrait, Errands.describe(offer), Format.money(int(offer.pay)), caption, Errands.phases_left(run, offer))
		row.pressed.connect(_open_offer.bind(str(offer.id)))
	for offer in run.customer_offers:
		var caption := "In %s. %s each, street %s" % [Customers.district_name(offer), Format.money(int(offer.unit_price)), Format.money(int(offer.street_price))]
		if bool(offer.rush):
			caption += ". Rush"
		var row := _add_offer_row(CustomerTalk.PORTRAIT, Customers.job_title(offer), Format.money(Customers.total(offer)), caption, Customers.phases_left(run, offer))
		row.pressed.connect(_open_customer_offer.bind(str(offer.id)))


func _add_offer_row(icon: Texture2D, title: String, pay: String, caption: String, phases_left: int) -> JobRow:
	var hint := "LAST PHASE" if phases_left <= 1 else "%d PHASES LEFT" % phases_left
	var row := _add_row(icon, title, pay, caption, hint, Palette.RISK_HIGH if phases_left <= 1 else Palette.TEXT_CREAM)
	row.set_tappable(true)
	return row


func _open_offer(offer_id: String) -> void:
	close()
	OfferTalk.open(offer_id)


func _open_customer_offer(offer_id: String) -> void:
	close()
	CustomerTalk.open(offer_id)


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
		var row := _add_row(item.icon, "%d %s" % [int(order.quantity), item.display_name], Format.money(Orders.total(order)), caption, "")
		_offer_runner(run, row, order, item, dealer.display_name, Orders.can_deliver(run, order), Orders.total(order))

	for favour in run.favours:
		var item := Content.item(StringName(favour.item))
		var family := Content.family(StringName(favour.family))
		var lieutenant := Content.character(family.lieutenant) if family != null else null
		if item == null or lieutenant == null:
			continue
		var caption := "Buy them, then hand them to %s by %s" % [lieutenant.display_name, Calendar.describe(int(favour.due)).to_lower()]
		var row := _add_row(item.icon, "%d %s" % [int(favour.quantity), item.display_name], Format.money(Favours.total(favour)), caption, "")
		_offer_runner(run, row, favour, item, lieutenant.display_name, Favours.can_deliver(run, favour), Favours.total(favour))

	if Smuggling.is_carrying(run):
		_add_crate(run)

	_add_errands(run)
	_add_customer_orders(run)

	if _list.get_child_count() == count:
		_add_note("No jobs taken. Customers order by phone, bars post delivery orders, Pier 9 has crates, and the families hand out favours.")


## Rows the runner can take become tappable. Otherwise the hint shows how much of the job is in the bag.
func _offer_runner(run: RunState, row: JobRow, job: Dictionary, item: ItemDef, client: String, ready: bool, pay: int) -> void:
	var quantity := int(job.quantity)
	var held := Inventory.count(run, item.id)
	if not ready:
		row.set_hint("HAVE %d/%d" % [held, quantity])
		return
	var runner := Crew.runner(run)
	if runner == null:
		row.set_hint(READY_HINT)
		return
	if not Crew.runner_ready(run):
		row.set_hint("RUNNER BACK NEXT PHASE")
		return
	row.set_hint("SEND %s" % runner.display_name.to_upper(), Palette.TEXT_CREAM)
	row.set_tappable(true)
	row.pressed.connect(_ask.bind(
		"Send your %s?" % runner.display_name.to_lower(),
		"Your %s takes the %d %s to %s and brings back %s. No trip and no heat. One run a phase." % [runner.display_name.to_lower(), quantity, item.display_name, client, Format.money(pay)],
		"Send",
		_send_runner.bind(job)))


func _add_owed(run: RunState) -> void:
	if run.invoices.is_empty():
		return
	_add_heading("OWED")
	for invoice in run.invoices:
		var due := "Due the morning of day %d. Some buyers never pay" % int(invoice.due_day)
		_add_row(INVOICE_ICON, "Owed by %s" % invoice.client, Format.money(int(invoice.amount)), due, "DAY %d" % int(invoice.due_day))


## Tapping the crate buys recon for this phase when the player has no eyes on the road yet.
func _add_crate(run: RunState) -> void:
	var row := _add_row(Smuggling.CRATE_ICON, "Voronin's crate", Format.money(Smuggling.payout(run, run.crate)), Smuggling.describe_route(run, run.crate), "")
	if Smuggling.can_deliver(run):
		row.set_hint("DELIVER HERE", Palette.TEXT_CREAM)
	elif bool(run.crate.get("off_route", false)):
		row.set_hint("OFF ROUTE", Palette.RISK_HIGH)
	elif not Routes.has_recon(run) and run.cash >= Routes.RECON_COST:
		row.set_hint("RECON %s" % Format.money(Routes.RECON_COST), Palette.TEXT_CREAM)
		row.set_tappable(true)
		row.pressed.connect(_ask.bind(
			"Recon the road?",
			"Spotters walk the stops ahead for %s. You see the exact danger at each one and the risk of an ambush is halved until the phase ends." % Format.money(Routes.RECON_COST),
			"Pay",
			_buy_recon))
	elif Smuggling.can_meet_halfway(run):
		row.set_hint("BUYER CAN MEET HERE", Palette.TEXT_CREAM)


func _add_errands(run: RunState) -> void:
	var sender := Content.character(Errands.SENDER)
	for errand in run.errands:
		var caption := "For %s by %s" % [sender.display_name, Calendar.describe(int(errand.due_stamp)).to_lower()]
		var place := Content.district(Errands.target_district(errand))
		var hint := "GO TO %s" % place.display_name.to_upper() if place != null else ""
		_add_row(sender.portrait, Errands.describe(errand), Format.money(int(errand.pay)), caption, hint)


## Short of goods the row opens where to buy them. With the goods it heads to the customer or hands over here.
func _add_customer_orders(run: RunState) -> void:
	for order in run.customer_orders:
		var place := Customers.district_name(order)
		var stocked := Customers.is_stocked(run, order)
		var caption := "Hand over in %s by %s" % [place, Calendar.describe(int(order.due_stamp)).to_lower()]
		if not stocked:
			caption += ". Tap to see where to buy"
		var row := _add_row(CustomerTalk.PORTRAIT, Customers.job_title(order), Format.money(Customers.total(order)), caption, "")
		row.set_tappable(true)
		if not stocked:
			row.set_hint("HAVE %d/%d" % [Inventory.count(run, StringName(str(order.item))), int(order.quantity)])
			row.pressed.connect(_open_quotes.bind(str(order.id)))
		elif Customers.can_hand_over(run, order):
			row.set_hint("HAND OVER HERE", Palette.TEXT_CREAM)
			row.pressed.connect(_head_to_customer.bind(order))
		else:
			row.set_hint("GO TO %s" % place.to_upper(), Palette.TEXT_CREAM)
			row.pressed.connect(_head_to_customer.bind(order))


func _open_quotes(order_id: String) -> void:
	GameOverlay.open_quotes(order_id)


func _head_to_customer(order: Dictionary) -> void:
	close()
	CustomerTalk.head_to_customer(order)


func _buy_recon() -> void:
	if GameState.buy_recon():
		AudioService.play_sfx(Sfx.COINS_OUT)


func _send_runner(job: Dictionary) -> void:
	var pay := GameState.send_runner(job)
	if pay > 0:
		AudioService.play_sfx(Sfx.FAVOUR_DONE)


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
				hint = "PULL IT, %s" % Odds.reading(Heists.success_chance(run, heist)).to_upper()
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


func _ask(title: String, message: String, confirm_label: String, action: Callable, dangerous := false) -> void:
	_pending_action = action
	_confirm.open(title, message, confirm_label, dangerous)


func _on_confirmed() -> void:
	var action := _pending_action
	_pending_action = Callable()
	if action.is_valid():
		action.call()


func _ask_heist(heist: HeistDef) -> void:
	var run := GameState.run
	var message := "You have %s. Success pays %s and adds %d heat. Failure adds %d heat, brings the police, and can cost you a crew member." % [
		Odds.reading(Heists.success_chance(run, heist)), Format.money(heist.payout), heist.heat, Heists.FAILED_HEAT,
	]
	_ask("Pull the %s?" % heist.display_name.to_lower(), message, "Pull it", _pull_heist.bind(heist), true)


func _pull_heist(heist: HeistDef) -> void:
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
