class_name Encounters

const POLICE := "police"
const RAID := "raid"
const ENFORCERS := "enforcers"
const EVENT := "event"

const CONTINUE: StringName = &"continue"
const BRIBE: StringName = &"bribe"
const RUN: StringName = &"run"
const COMPLY: StringName = &"comply"
const PAY: StringName = &"pay"
const FIGHT: StringName = &"fight"
const TAKE: StringName = &"take"
const LEAVE: StringName = &"leave"

const BEAT_OFFICER: StringName = &"officer"
const RAID_LEAD: StringName = &"detective"
const COLLECTOR: StringName = &"enforcer"


class Choice:
	var id: StringName
	var label: String
	var enabled: bool

	func _init(choice_id: StringName, choice_label: String, is_enabled := true) -> void:
		id = choice_id
		label = choice_label
		enabled = is_enabled


static func has_pending(run: RunState) -> bool:
	return not run.pending_encounter.is_empty()


## Runs everything that happens when a phase passes, and queues at most one encounter.
static func after_time_passes(run: RunState, new_day_started: bool, travelled: bool, rng: RandomNumberGenerator, events: Array[EventDef]) -> void:
	if travelled:
		Heat.add(run, Heat.for_travel(run))
	var raid_due := Heat.is_maxed(run)
	Heat.cool_down(run, new_day_started)
	StreetEvents.prune(run)
	Turf.vex_pushes(run)

	if new_day_started:
		Loan.accrue_interest(run)
		if Campaign.update_outcome(run):
			return
		if Loan.is_payment_due_today(run):
			if Loan.amount_due(run) > 0:
				run.pending_encounter = send_enforcers(run)
			Loan.start_next_period(run)

	if has_pending(run):
		return
	Turf.check_victory(run)
	if has_pending(run):
		return
	if raid_due:
		run.pending_encounter = raid(run)
	elif rng.randf() < Police.stop_chance(run):
		run.pending_encounter = police_stop(run)
	elif Roster.rival_in(run, run.district_id, Calendar.stamp(run)) and Turf.clash_due(run, rng.randf()):
		run.pending_encounter = Turf.clash(run)
	elif rng.randf() < StreetEvents.EVENT_CHANCE:
		run.pending_encounter = StreetEvents.roll_event(run, events, rng)
		if int(run.pending_encounter.get("effect", -1)) == EventDef.Effect.PRICE_SHIFT:
			StreetEvents.apply_shift(run, run.pending_encounter)


## Called after anything that raises heat outside of time passing.
static func check_raid(run: RunState) -> void:
	if Heat.is_maxed(run) and not has_pending(run):
		run.pending_encounter = raid(run)


## The patrol working the district makes the stop, otherwise the beat officer.
static func police_stop(run: RunState) -> Dictionary:
	var patrol := Roster.strongest_patrol(run, run.district_id, Calendar.stamp(run))
	return {
		"type": POLICE,
		"speaker": String(patrol.id if patrol != null else BEAT_OFFICER),
		"title": "Police stop",
		"body": "Hold it right there. Open the bag, nice and slow.",
		"bribe": Police.bribe_cost(run),
	}


static func raid(run: RunState) -> Dictionary:
	Police.raid(run)
	return {
		"type": RAID,
		"speaker": String(RAID_LEAD),
		"title": "Raid",
		"body": "Your name kept coming up, so we came looking. Everything you were carrying is evidence now.",
	}


static func send_enforcers(run: RunState) -> Dictionary:
	var cash_taken := Loan.enforcer_cash_take(run)
	var penalty := Loan.enforcer_penalty(run)
	var losses: Array[String] = []
	if cash_taken > 0:
		losses.append(Format.money(cash_taken))
	run.cash -= cash_taken

	if cash_taken < Loan.amount_due(run):
		var stack := _most_valuable_stack(run)
		if stack != null:
			var quantity := Inventory.count(run, stack.id)
			Inventory.discard(run, stack.id, quantity)
			losses.append("%d %s" % [quantity, stack.display_name])
	run.debt += penalty

	var taken := "nothing worth taking" if losses.is_empty() else " and ".join(losses)
	return {
		"type": ENFORCERS,
		"speaker": String(COLLECTOR),
		"title": "Enforcers",
		"body": "You missed The Shark's payment. I took %s, and %s goes on your debt." % [taken, Format.money(penalty)],
	}


static func choices(run: RunState, encounter: Dictionary) -> Array[Choice]:
	var list: Array[Choice] = []
	match encounter.get("type"):
		POLICE:
			var bribe := int(encounter.bribe)
			list.append(Choice.new(BRIBE, "Bribe %s" % Format.money(bribe), run.cash >= bribe))
			list.append(Choice.new(RUN, "Run for it (%d%%)" % roundi(Police.escape_chance(run) * 100.0)))
			list.append(Choice.new(COMPLY, "Comply"))
		Turf.CLASH:
			var tribute := int(encounter.tribute)
			list.append(Choice.new(Turf.TRIBUTE, "Pay %s tribute" % Format.money(tribute), run.cash >= tribute))
			list.append(Choice.new(Turf.FIGHT, "Fight (%d%%)" % roundi(Turf.FIGHT_CHANCE * 100.0)))
			list.append(Choice.new(Turf.BACK_OFF, "Back off"))
		EVENT:
			match int(encounter.effect):
				EventDef.Effect.MUGGING:
					list.append(Choice.new(PAY, "Hand over %s" % Format.money(int(encounter.amount))))
					list.append(Choice.new(FIGHT, "Fight back"))
				EventDef.Effect.LUCKY_FIND:
					list.append(Choice.new(TAKE, "Take it"))
					list.append(Choice.new(LEAVE, "Leave it"))
				_:
					list.append(Choice.new(CONTINUE, "Continue"))
		_:
			list.append(Choice.new(CONTINUE, "Continue"))
	return list


## Applies the player's answer and clears the encounter. Returns the outcome text, empty when there is nothing more to say.
## The roll decides gambles and must be in the range [0, 1).
static func resolve(run: RunState, choice: StringName, roll: float) -> String:
	var encounter := run.pending_encounter
	var allowed := choices(run, encounter).filter(func(entry: Choice) -> bool: return entry.id == choice and entry.enabled)
	if allowed.is_empty():
		return ""
	run.pending_encounter = {}
	if encounter.get("type") == Turf.CLASH:
		return Turf.resolve_clash(run, encounter, choice, roll)
	match choice:
		BRIBE:
			Police.pay_bribe(run, int(encounter.bribe))
			return "You slip them %s. They wave you on." % Format.money(int(encounter.bribe))
		RUN:
			if Police.run_for_it(run, roll):
				return "You lose them in the alleys, but they will remember your face."
			return "They catch you and empty your bag."
		COMPLY:
			var taken := Police.comply(run)
			if taken.is_empty():
				return "They find nothing worth taking."
			if taken.has("crate"):
				return "They pry open Voronin's crate and keep it. He will hear about this."
			return "They take %d %s and let you go." % [taken.quantity, taken.item.display_name]
		PAY:
			var paid := mini(int(encounter.amount), maxi(0, run.cash))
			run.cash -= paid
			return "You hand over %s." % Format.money(paid)
		FIGHT:
			if roll < StreetEvents.FIGHT_CHANCE:
				return "You fight them off and keep your cash."
			var lost := mini(int(encounter.amount) * StreetEvents.FIGHT_LOSS_MULTIPLIER, maxi(0, run.cash))
			run.cash -= lost
			return "They beat you down and take %s." % Format.money(lost)
		TAKE:
			var item := Content.item(StringName(str(encounter.item)))
			if item == null:
				return ""
			var quantity := mini(int(encounter.quantity), floori(float(Inventory.free_space(run)) / item.slots))
			if quantity <= 0:
				return "Your bag is full. You leave it behind."
			Inventory.add_units(run, item.id, quantity)
			return "You stuff %d %s into your bag." % [quantity, item.display_name]
		LEAVE:
			return "You walk away. Not worth the risk."
	return ""


static func _most_valuable_stack(run: RunState) -> ItemDef:
	var best: ItemDef = null
	var best_value := 0
	for item_id: StringName in run.inventory:
		var item := Content.item(item_id)
		if item == null:
			continue
		var value := item.base_price * Inventory.count(run, item_id)
		if value > best_value:
			best = item
			best_value = value
	return best
