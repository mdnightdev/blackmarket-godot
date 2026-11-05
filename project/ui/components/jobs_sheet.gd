class_name JobsSheet
extends BottomSheet

const JOB_ROW := preload("res://ui/components/job_row.tscn")
const READY_HINT := "IN BAG"
const LOCK_ICON: Texture2D = preload("res://assets/icons/hud/lock.svg")
const ICON_SELL: Texture2D = preload("res://assets/icons/hud/banknote.svg")
const ICON_TRUCK: Texture2D = preload("res://assets/icons/hud/truck.svg")
const ICON_FLAME: Texture2D = preload("res://assets/icons/hud/flame.svg")
const ICON_DICES: Texture2D = preload("res://assets/icons/hud/dices.svg")
const ICON_MAP: Texture2D = preload("res://assets/icons/hud/map.svg")
const ICON_SWORDS: Texture2D = preload("res://assets/icons/hud/swords.svg")
const ICON_RADAR: Texture2D = preload("res://assets/icons/hud/radar.svg")
const ICON_SHIELD: Texture2D = preload("res://assets/icons/hud/shield.svg")
const ICON_COINS: Texture2D = preload("res://assets/icons/hud/hand-coins.svg")
const ICON_ZAP: Texture2D = preload("res://assets/icons/hud/zap.svg")
const ICON_BRIEFCASE: Texture2D = preload("res://assets/icons/hud/briefcase-business.svg")
const ICON_PACKAGE: Texture2D = preload("res://assets/icons/hud/package.svg")

const HEADING_INDENT := 16
const CONTINUE: StringName = &"continue"

enum Tab { ACTIVE, COMPLETED, FAILED }

@onready var _margin: MarginContainer = %Margin
@onready var _list: VBoxContainer = %List
@onready var _confirm: ConfirmDialog = %ConfirmDialog
@onready var _active_tab: Button = %ActiveTab
@onready var _completed_tab: Button = %CompletedTab
@onready var _failed_tab: Button = %FailedTab
@onready var _do_not_disturb_toggle: Button = %DoNotDisturbToggle

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
	_do_not_disturb_toggle.toggled.connect(func(enabled: bool) -> void:
		Settings.do_not_disturb = enabled
		_update_dnd_button(enabled)
		Settings.save())


func open_jobs() -> void:
	SafeArea.apply_top_margin(_margin, 64)
	_tab = Tab.ACTIVE
	_active_tab.button_pressed = true
	_do_not_disturb_toggle.set_pressed_no_signal(Settings.do_not_disturb)
	_update_dnd_button(Settings.do_not_disturb)
	_rebuild()
	open_sheet()


func _update_dnd_button(enabled: bool) -> void:
	_do_not_disturb_toggle.text = "SILENT: ON" if enabled else "SILENT: OFF"
	_do_not_disturb_toggle.add_theme_color_override("font_color", Palette.TEXT if enabled else Palette.TEXT_MUTED)


func _select_tab(tab: Tab) -> void:
	_tab = tab
	_rebuild()


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
	Utils.clear_container(_list)
	_update_tab_labels(run)
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
	_add_bottom_spacer()


func _update_tab_labels(run: RunState) -> void:
	if run == null:
		return
	var active_tasks := run.daily_tasks.filter(func(t: Dictionary) -> bool: return not bool(t.get("done", false))).size()
	var active_count := active_tasks + run.orders.size() + run.favours.size() + run.errands.size() \
		+ run.customer_orders.size() + run.job_pings.size() + run.errand_offers.size() + run.customer_offers.size()
	_active_tab.text = "ACTIVE (%d)" % active_count if active_count > 0 else "ACTIVE"
	_completed_tab.text = "ARCHIVE"
	_failed_tab.text = "FAILED"


func _add_bottom_spacer() -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 48)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.add_child(spacer)


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
		var slot := &"SlotCommon" if failed else &"SlotRare"
		_add_row(LOCK_ICON if failed else ICON_PACKAGE, str(entry.title), "", caption, hint, Palette.RISK_HIGH if failed else Palette.RISK_LOW, slot)


func _task_icon(kind: StringName) -> Texture2D:
	match kind:
		DailyTasks.SELL_VALUE:
			return ICON_SELL
		DailyTasks.DELIVER_JOB:
			return ICON_TRUCK
		DailyTasks.END_DAY_COOL:
			return ICON_FLAME
		DailyTasks.CASINO_WIN:
			return ICON_DICES
		DailyTasks.VISIT:
			return ICON_MAP
		DailyTasks.TAKE_CORNER:
			return ICON_SWORDS
		DailyTasks.SCOUT_CORNER:
			return ICON_RADAR
		DailyTasks.POST_GARRISON:
			return ICON_SHIELD
		DailyTasks.PAY_LOAN:
			return ICON_COINS
		DailyTasks.USE_CONSUMABLE:
			return ICON_ZAP
		_:
			return ICON_BRIEFCASE


func _add_tasks(run: RunState) -> void:
	if run.daily_tasks.is_empty():
		return
	_add_heading("DAILY DIRECTIVES")
	for task in run.daily_tasks:
		var done := bool(task.get("done", false))
		var icon := _task_icon(StringName(task.get("kind", "")))
		var hint := "DONE" if done else "+%d CRED" % StreetCred.TASK_DONE
		var hint_color := Palette.PRICE if done else Palette.TEXT_MUTED
		var slot := &"SlotLegendary" if done else &"SlotRare"
		_add_row(icon, DailyTasks.describe(task), Format.money(DailyTasks.reward(run)), DailyTasks.progress_text(task), hint, hint_color, slot)


func _add_offers(run: RunState) -> void:
	if run.errand_offers.is_empty() and run.customer_offers.is_empty() and run.job_pings.is_empty():
		return
	_add_heading("RUSH OFFERS", "TAP TO ACCEPT")
	for ping in run.job_pings:
		var caller := JobPings.sender(ping)
		if caller == null:
			continue
		var place := JobPings.destination(ping)
		var caption := "From %s%s" % [caller.display_name, ", in %s" % place.display_name if place != null else ""]
		var row := _add_offer_row(caller.portrait, JobPings.headline(ping), Format.money(JobPings.total_pay(ping)), caption, JobPings.phases_left(run, ping))
		row.pressed.connect(_open_ping.bind(str(ping.id)))
	for offer in run.errand_offers:
		var sender := Content.character(StringName(str(offer.sender)))
		if sender == null:
			continue
		var caption := "From %s. %d phases to finish once taken" % [sender.display_name, int(offer.lead)]
		var row := _add_offer_row(sender.portrait, Errands.describe(offer), Errands.pay_label(offer), caption, Errands.phases_left(run, offer))
		row.pressed.connect(_open_offer.bind(str(offer.id)))
	for offer in run.customer_offers:
		var caption := "In %s. %s each, street %s" % [Customers.district_name(offer), Format.money(int(offer.unit_price)), Format.money(int(offer.street_price))]
		if bool(offer.rush):
			caption += ". Rush"
		var row := _add_offer_row(CustomerTalk.PORTRAIT, Customers.job_title(offer), Format.money(Customers.total(offer)), caption, Customers.phases_left(run, offer))
		row.pressed.connect(_open_customer_offer.bind(str(offer.id)))


func _add_offer_row(icon: Texture2D, title: String, pay: String, caption: String, phases_left: int) -> JobRow:
	var hint := "LAST PHASE" if phases_left <= 1 else "%d PHASES LEFT" % phases_left
	var row := _add_row(icon, title, pay, caption, hint, Palette.RISK_HIGH if phases_left <= 1 else Palette.TEXT_CREAM, &"SlotEpic")
	row.set_tappable(true)
	return row


func _open_offer(offer_id: String) -> void:
	close()
	OfferTalk.open(offer_id)


func _open_ping(ping_id: String) -> void:
	close()
	JobTalk.open(ping_id)


func _open_customer_offer(offer_id: String) -> void:
	close()
	CustomerTalk.open(offer_id)


func _add_active(run: RunState) -> void:
	_add_heading("ACTIVE CONTRACTS", "IN PROGRESS")
	var count := _list.get_child_count()
	for order in run.orders:
		var item := Content.item(StringName(order.item))
		var dealer := Content.dealer(StringName(order.dealer))
		if item == null or dealer == null:
			continue
		var district := Content.district(dealer.district_id)
		var place := " in %s" % district.display_name if district != null else ""
		var caption := "Buy them, then deliver to %s%s by %s" % [dealer.display_name, place, Calendar.describe(int(order.due)).to_lower()]
		var is_ready := Orders.can_deliver(run, order)
		var slot := &"SlotLegendary" if is_ready else &"SlotRare"
		var row := _add_row(item.icon, "%d %s" % [int(order.quantity), item.display_name], Format.money(Orders.total(order)), caption, "", Color.TRANSPARENT, slot)
		if Orders.can_meet(run, order):
			row.set_hint("MEET HERE", Palette.TEXT_CREAM)
			row.set_tappable(true)
			row.pressed.connect(_meet_dealer.bind(order))
			continue
		if _offer_runner(run, row, order, item, dealer.display_name, is_ready, Orders.total(order)) or not is_ready:
			continue
		if district != null and district.id != run.district_id:
			var spot := Content.district(Meetings.spot(order))
			if spot != null:
				row.set_hint("MEET IN %s" % spot.display_name.to_upper(), Palette.TEXT_CREAM)
			row.set_tappable(true)
			row.pressed.connect(_offer_meeting.bind(order, dealer, district))

	for favour in run.favours:
		var item := Content.item(StringName(favour.item))
		var family := Content.family(StringName(favour.family))
		var lieutenant := Content.character(family.lieutenant) if family != null else null
		if item == null or lieutenant == null:
			continue
		var caption := "Buy them, then hand them to %s by %s" % [lieutenant.display_name, Calendar.describe(int(favour.due)).to_lower()]
		var is_ready := Favours.can_deliver(run, favour)
		var slot := &"SlotLegendary" if is_ready else &"SlotRare"
		var row := _add_row(item.icon, "%d %s" % [int(favour.quantity), item.display_name], Format.money(Favours.total(favour)), caption, "", Color.TRANSPARENT, slot)
		_offer_runner(run, row, favour, item, lieutenant.display_name, is_ready, Favours.total(favour))

	if Smuggling.is_carrying(run):
		_add_crate(run)

	_add_errands(run)
	_add_customer_orders(run)

	if _list.get_child_count() == count:
		_add_note("No jobs taken. Customers order by phone, bars post delivery orders, Pier 9 has crates, and the families hand out favours.")


func _offer_runner(run: RunState, row: JobRow, job: Dictionary, item: ItemDef, client: String, can_deliver: bool, pay: int) -> bool:
	var quantity := int(job.quantity)
	var held := Inventory.count(run, item.id)
	if not can_deliver:
		row.set_hint("HAVE %d/%d" % [held, quantity])
		return false
	var runner := Crew.runner(run)
	if runner == null:
		row.set_hint(READY_HINT)
		return false
	if not Crew.runner_ready(run):
		row.set_hint("RUNNER BACK NEXT PHASE")
		return false
	row.set_hint("SEND %s" % runner.display_name.to_upper(), Palette.TEXT_CREAM)
	row.set_tappable(true)
	row.pressed.connect(_ask.bind(
		"Send your %s?" % runner.display_name.to_lower(),
		"Your %s takes the %d %s to %s and brings back %s. No trip and no heat. One run a phase." % [runner.display_name.to_lower(), quantity, item.display_name, client, Format.money(pay)],
		"Send",
		_send_runner.bind(job)))
	return true


func _offer_meeting(order: Dictionary, dealer: DealerDef, district: DistrictDef) -> void:
	close()
	MeetTalk.open(dealer, str(order.id), district, Orders.total(order), Orders.meeting_total(order), _meet_dealer.bind(order))


func _meet_dealer(order: Dictionary) -> void:
	if GameOverlay.blocked_by_jail():
		return
	var run := GameState.run
	var dealer := Content.dealer(StringName(str(order.dealer)))
	var scammed := Meetings.is_scam(run, order)
	var paid := GameState.meet_order(order)
	if paid <= 0 or dealer == null:
		return
	close()
	AudioService.play_sfx(Sfx.FAVOUR_DONE)
	var line := "Here, %s. Pleasure doing business on the road." % Format.money(paid)
	if scammed:
		line = "%s. That is all you get. Say a word and my boys come round the corner." % Format.money(paid)
	GameOverlay.talk(dealer, line, TripTalk.continue_only(), TripTalk.end)


func _add_owed(run: RunState) -> void:
	if run.invoices.is_empty() and run.dealer_loans.is_empty():
		return
	_add_heading("OWED & CREDIT", "OUTSTANDING DEBT")
	for invoice in run.invoices:
		var due := "Due the morning of day %d. Some buyers never pay" % int(invoice.due_day)
		_add_row(ItemsAtlas.get_icon(&"nav_jobs"), "Owed by %s" % invoice.client, Format.money(int(invoice.amount)), due, "DAY %d" % int(invoice.due_day), Palette.TEXT_CREAM, &"SlotLegendary")
	for loan in run.dealer_loans:
		var dealer := Content.dealer(StringName(str(loan.dealer)))
		var dealer_name := dealer.display_name if dealer != null else str(loan.dealer)
		var due_day := int(loan.due_day)
		var caption := "Due day %d (lent %s). Shark collects on default." % [due_day, Format.money(int(loan.amount))]
		var hint := "DUE TODAY" if run.day >= due_day else "DAY %d" % due_day
		var hint_color := Palette.RISK_HIGH if run.day >= due_day else Palette.TEXT_CREAM
		_add_row(ItemsAtlas.get_icon(&"nav_jobs"), "Loan to %s" % dealer_name, Format.money(int(loan.repayment)), caption, hint, hint_color, &"SlotLegendary")


func _add_crate(run: RunState) -> void:
	var row := _add_row(Smuggling.CRATE_ICON, "Voronin's crate", Format.money(Smuggling.payout(run, run.crate)), Smuggling.describe_route(run, run.crate), "", Color.TRANSPARENT, &"SlotEpic")
	if Smuggling.can_deliver(run):
		row.set_hint("DELIVER HERE", Palette.TEXT_CREAM)
	elif Campaign.is_act_two(run) and Crew.driver_ready(run):
		var driver := Crew.driver(run)
		var dest := Smuggling.destination(run.crate)
		var place := dest.display_name if dest != null else "destination"
		var cut_pay := roundi(Smuggling.payout(run, run.crate) * 0.8)
		row.set_hint("SEND %s" % driver.display_name.to_upper(), Palette.TEXT_CREAM)
		row.set_tappable(true)
		row.pressed.connect(_ask.bind(
			"Send your %s?" % driver.display_name.to_lower(),
			"Your %s drives the crate to %s and brings back %s. No trip and no heat." % [driver.display_name.to_lower(), place, Format.money(cut_pay)],
			"Send",
			_send_driver
		))
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
		var row := _add_row(sender.portrait, Errands.describe(errand), Errands.pay_label(errand), caption, hint, Color.TRANSPARENT, &"SlotRare")
		if Campaign.is_act_two(run):
			var kind := str(errand.get("kind", ""))
			if kind == Errands.COLLECTION and Crew.muscle_ready(run):
				var muscle := Crew.muscle(run)
				row.set_hint("SEND %s" % muscle.display_name.to_upper(), Palette.TEXT_CREAM)
				row.set_tappable(true)
				row.pressed.connect(_ask.bind(
					"Send %s to collect?" % muscle.display_name.to_lower(),
					"Your %s visits %s in %s to collect the %s. No travel or heat required." % [muscle.display_name.to_lower(), str(errand.debtor), place.display_name if place != null else "", Format.money(int(errand.owed))],
					"Send",
					_send_muscle.bind(errand)
				))
			elif kind == Errands.DELIVERY and bool(errand.get("picked_up", false)) and Crew.runner_ready(run):
				var runner := Crew.runner(run)
				row.set_hint("SEND %s" % runner.display_name.to_upper(), Palette.TEXT_CREAM)
				row.set_tappable(true)
				row.pressed.connect(_ask.bind(
					"Send your %s?" % runner.display_name.to_lower(),
					"Your %s drops the %s in %s. No trip and no heat." % [runner.display_name.to_lower(), Errands.noun(errand), place.display_name if place != null else ""],
					"Send",
					_send_runner.bind(errand)
				))


func _add_customer_orders(run: RunState) -> void:
	for order in run.customer_orders:
		var place := Customers.district_name(order)
		var stocked := Customers.is_stocked(run, order)
		var caption := "Hand over in %s by %s" % [place, Calendar.describe(int(order.due_stamp)).to_lower()]
		if not stocked:
			caption += ". Tap to see where to buy"
		var slot := &"SlotLegendary" if stocked else &"SlotRare"
		var row := _add_row(CustomerTalk.PORTRAIT, Customers.job_title(order), Format.money(Customers.total(order)), caption, "", Color.TRANSPARENT, slot)
		row.set_tappable(true)
		if not stocked:
			row.set_hint("HAVE %d/%d" % [Inventory.count(run, StringName(str(order.item))), int(order.quantity)])
			row.pressed.connect(_open_quotes.bind(str(order.id)))
		elif Customers.can_hand_over(run, order):
			row.set_hint("HAND OVER HERE", Palette.TEXT_CREAM)
			row.pressed.connect(_head_to_customer.bind(order))
		elif Campaign.is_act_two(run) and Crew.runner_ready(run):
			var runner := Crew.runner(run)
			row.set_hint("SEND %s" % runner.display_name.to_upper(), Palette.TEXT_CREAM)
			row.pressed.connect(_ask.bind(
				"Send your %s?" % runner.display_name.to_lower(),
				"Your %s takes the %d %s to %s and brings back %s. No trip and no heat." % [runner.display_name.to_lower(), int(order.quantity), Content.item(StringName(str(order.item))).display_name, place, Format.money(Customers.total(order))],
				"Send",
				_send_runner.bind(order)
			))
		else:
			var spot := Content.district(Meetings.spot(order))
			row.set_hint("MEET IN %s" % spot.display_name.to_upper() if spot != null else "GO TO %s" % place.to_upper(), Palette.TEXT_CREAM)
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


func _send_muscle(errand: Dictionary) -> void:
	var pay := GameState.send_muscle(errand)
	if pay > 0:
		AudioService.play_sfx(Sfx.COINS_IN)


func _send_driver() -> void:
	var pay := GameState.send_driver()
	if pay > 0:
		AudioService.play_sfx(Sfx.COINS_IN)


func _add_heists(run: RunState) -> void:
	_add_heading("SYNDICATE HEISTS", "HIGH-STAKES")
	if not Campaign.is_act_two(run):
		_add_row(LOCK_ICON, "Syndicate Operations", "", "Take Old Market from Vex to unlock", "LOCKED", Palette.TEXT_MUTED, &"SlotCommon")
		return
	for heist in Content.heists():
		var district := Content.district(heist.district_id)
		var place := district.display_name if district != null else ""
		var result := Heists.check(run, heist)
		var hint := ""
		var hint_color := Palette.TEXT_MUTED
		var slot := &"SlotCommon"
		match result:
			Heists.Result.OK:
				hint = "PULL IT • %s" % Odds.reading(Heists.success_chance(run, heist)).to_upper()
				hint_color = Palette.PRICE
				slot = &"SlotLegendary"
			Heists.Result.RANK_TOO_LOW:
				hint = "NEEDS %s" % StreetCred.rank_name(heist.min_rank).to_upper()
			Heists.Result.MISSING_CREW:
				hint = "NEEDS %s" % _role_names(Heists.missing_roles(run, heist)).to_upper()
			Heists.Result.COOLDOWN:
				var days := Heists.days_until_ready(run, heist)
				hint = "READY IN %d %s" % [days, "DAY" if days == 1 else "DAYS"]
			Heists.Result.WRONG_DISTRICT:
				hint = "GO TO %s" % place.to_upper()
		var row := _add_row(heist.icon, heist.display_name, Format.money(Heists.payout(run, heist)), "%s. %s" % [place, heist.description], hint, hint_color, slot)
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
	if GameOverlay.blocked_by_jail():
		return
	var run := GameState.run
	var message := "You have %s. Success pays %s and adds %d heat. Failure adds %d heat, brings the police, and can cost you a crew member." % [
		Odds.reading(Heists.success_chance(run, heist)), Format.money(Heists.payout(run, heist)), heist.heat, Heists.FAILED_HEAT,
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


func _add_heading(text: String, subtitle: String = "") -> void:
	if _list.get_child_count() > 0:
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 16)
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_list.add_child(gap)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", HEADING_INDENT)
	margin.add_theme_constant_override("margin_right", HEADING_INDENT)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	header_row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var label := Label.new()
	label.theme_type_variation = &"BannerLabel"
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Palette.TEXT)
	header_row.add_child(label)

	if not subtitle.is_empty():
		var sub := Label.new()
		sub.theme_type_variation = &"PlaceLabel"
		sub.text = "• " + subtitle.to_upper()
		sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header_row.add_child(sub)

	margin.add_child(header_row)
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


func _add_row(icon: Texture2D, title: String, pay: String, caption: String, hint: String, hint_color := Color.TRANSPARENT, slot_variation: StringName = &"SlotRare", icon_tint := Color.WHITE) -> JobRow:
	var row: JobRow = JOB_ROW.instantiate()
	_list.add_child(row)
	row.show_job(icon, title, pay, caption, hint, hint_color, slot_variation, icon_tint)
	return row
