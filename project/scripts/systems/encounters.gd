class_name Encounters

const POLICE := "police"
const RAID := "raid"
const ENFORCERS := "enforcers"
const EVENT := "event"
const RAID_WARNING := "raid_warning"
const RAID_WARNING_COOLING := 20

const CONTINUE: StringName = &"continue"
const BRIBE: StringName = &"bribe"
const RUN: StringName = &"run"
const COMPLY: StringName = &"comply"
const JAIL: StringName = &"jail"
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
		Heat.add_for_travel(run)
	var police_quiet := Police.is_quiet(run)
	var raid_due := Heat.is_maxed(run) and not police_quiet
	Heat.cool_down(run, new_day_started)
	StreetEvents.prune(run)
	Turf.vex_pushes(run)

	if new_day_started:
		Turf.collect_daily_cut(run)
		Loan.accrue_interest(run)
		if Loan.is_payment_due_today(run):
			if Loan.amount_due(run) > 0:
				run.missed_weeks += 1
				run.pending_encounter = send_enforcers(run)
			else:
				run.missed_weeks = 0
			Loan.start_next_period(run)
		if Campaign.update_outcome(run):
			return

	if has_pending(run):
		return
	Turf.check_victory(run)
	if has_pending(run) or Police.is_jailed(run):
		return
	if travelled and Smuggling.is_carrying(run) and Routes.ambush_due(run, rng.randf()):
		run.pending_encounter = Ambush.start(run)
	elif raid_due:
		run.pending_encounter = raid_or_warning(run)
	elif not police_quiet and rng.randf() < Police.stop_chance(run):
		run.pending_encounter = police_stop(run)
	elif Vex.hunt_due(run, rng.randf()):
		run.pending_encounter = Vex.hunt(run)
	elif Vex.gate_due(run, rng.randf()):
		run.pending_encounter = Vex.gate(run)
	elif Families.hostile_family_in(run, run.district_id) != null and rng.randf() < Families.SHAKEDOWN_CHANCE:
		run.pending_encounter = Families.shakedown(run)
	elif rng.randf() < StreetEvents.EVENT_CHANCE:
		run.pending_encounter = StreetEvents.roll_event(run, events, rng)
		if int(run.pending_encounter.get("effect", -1)) == EventDef.Effect.PRICE_SHIFT:
			StreetEvents.apply_shift(run, run.pending_encounter)


## A trip that ends inside the current phase. Vex, families and street events stay once per phase,
## so only travel heat, an ambush on a hot run and the police can catch up with the player here.
static func after_arrival(run: RunState, rng: RandomNumberGenerator) -> void:
	Heat.add_for_travel(run)
	if has_pending(run):
		return
	if Smuggling.is_carrying(run) and Routes.ambush_due(run, rng.randf()):
		run.pending_encounter = Ambush.start(run)
		return
	if Police.is_quiet(run):
		return
	if Heat.is_maxed(run):
		run.pending_encounter = raid_or_warning(run)
	elif rng.randf() < Police.stop_chance(run):
		run.pending_encounter = police_stop(run)


## Called after anything that raises heat outside of time passing.
static func check_raid(run: RunState) -> void:
	if Heat.is_maxed(run) and not Police.is_quiet(run) and not has_pending(run):
		run.pending_encounter = raid_or_warning(run)


## A lookout on the crew turns one raid a day into a warning and time to scatter the goods.
static func raid_or_warning(run: RunState) -> Dictionary:
	if not Crew.can_warn_of_raid(run):
		return raid(run)
	Crew.use_raid_warning(run)
	Heat.add(run, -RAID_WARNING_COOLING)
	return {
		"type": RAID_WARNING,
		"speaker": String(run.player_id),
		"title": "Raid warning",
		"body": "Your lookout spots a raid team forming down the street. You scatter the goods before they move in.",
	}


## The patrol working the district makes the stop, otherwise the beat officer.
## A cornered player already ran once: running is off the table and the bribe goes up.
static func police_stop(run: RunState, cornered := false) -> Dictionary:
	var patrol := Roster.strongest_patrol(run, run.district_id, Calendar.stamp(run))
	run.stop_stamp = Calendar.stamp(run)
	var bribe := Police.bribe_cost(run)
	return {
		"type": POLICE,
		"speaker": String(patrol.id if patrol != null else BEAT_OFFICER),
		"title": "Police stop",
		"body": "Nice try. Hands on the wall and open the bag." if cornered else "Hold it right there. Open the bag, nice and slow.",
		"bribe": roundi(bribe * Police.CORNERED_BRIBE_FACTOR) if cornered else bribe,
		"cornered": cornered,
	}


static func raid(run: RunState) -> Dictionary:
	Police.arrest(run)
	return {
		"type": RAID,
		"speaker": String(RAID_LEAD),
		"title": "Raid",
		"body": "Your name kept coming up, so we came looking. Half of what you were carrying is evidence now.",
	}


static func send_enforcers(run: RunState) -> Dictionary:
	var cash_taken := Loan.enforcer_cash_take(run)
	var penalty := Loan.enforcer_penalty(run)
	run.cash -= cash_taken
	run.debt += penalty
	var taken := Format.money(cash_taken) if cash_taken > 0 else "nothing worth taking"
	var body := "You missed The Shark's payment. I took %s, and %s goes on your debt." % [taken, Format.money(penalty)]
	if not run.career:
		body += " Missed %d of %d." % [run.missed_weeks, Loan.MAX_MISSED_WEEKS]
	return {
		"type": ENFORCERS,
		"speaker": String(COLLECTOR),
		"title": "Enforcers",
		"body": body,
	}


static func choices(run: RunState, encounter: Dictionary) -> Array[Choice]:
	var list: Array[Choice] = []
	match encounter.get("type"):
		POLICE:
			var bribe := int(encounter.bribe)
			list.append(Choice.new(BRIBE, "Bribe %s" % Format.money(bribe), run.cash >= bribe))
			if not bool(encounter.get("cornered", false)):
				list.append(Choice.new(RUN, "Run for it (%s)" % Odds.reading(Police.escape_chance(run))))
				var line := Talk.police_line(run)
				list.append(Choice.new(line, Talk.police_label(run, line)))
			list.append(Choice.new(COMPLY, "Comply"))
			list.append(Choice.new(JAIL, "Go to jail (%d min)" % roundi(Police.JAIL_SECONDS / 60.0)))
		Vex.GATE, Vex.HUNT:
			list.append_array(Vex.choices(run, encounter))
		Ambush.TYPE:
			list.append_array(Ambush.choices(run, encounter))
		Collections.TYPE:
			list.append_array(Collections.choices(run, encounter))
		CustomerHandover.TYPE:
			list.append_array(CustomerHandover.choices(run, encounter))
		Families.SHAKEDOWN:
			var demand := int(encounter.demand)
			list.append(Choice.new(Families.PAY_UP, "Pay %s" % Format.money(demand), run.cash >= demand))
			list.append(Choice.new(Families.REFUSE, "Refuse"))
		EVENT:
			match int(encounter.effect):
				EventDef.Effect.MUGGING:
					list.append(Choice.new(PAY, "Hand over %s" % Format.money(int(encounter.amount))))
					list.append(Choice.new(FIGHT, "Fight back (%s)" % Odds.reading(StreetEvents.fight_chance(run))))
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
	match encounter.get("type"):
		Vex.GATE, Vex.HUNT:
			return Vex.resolve(run, encounter, choice, roll)
		Ambush.TYPE:
			return Ambush.resolve(run, encounter, choice, roll)
		Collections.TYPE:
			return Collections.resolve(run, encounter, choice, roll)
		CustomerHandover.TYPE:
			return CustomerHandover.resolve(run, encounter, choice, roll)
		Families.SHAKEDOWN:
			return Families.resolve_shakedown(run, encounter, choice)
		Turf.VICTORY:
			return Turf.victory_summary()
	match choice:
		BRIBE:
			Police.pay_bribe(run, int(encounter.bribe))
			return "You slip them %s. They wave you on." % Format.money(int(encounter.bribe))
		RUN:
			if Police.run_for_it(run, roll):
				return "You lose them in the alleys, but they will remember your face."
			run.pending_encounter = police_stop(run, true)
			return "They cut you off at the end of the alley. No more running."
		Talk.PLAY_DUMB, Talk.SHOW_ID, Talk.NAME_DROP:
			return Talk.resolve_police(run, choice, roll)
		COMPLY:
			var taken := Police.comply(run)
			if taken.is_empty():
				return "They find nothing worth taking."
			if taken.has("crate"):
				return "They pry open Voronin's crate and keep it. He will hear about this."
			return "They take %d %s and let you go." % [taken.quantity, taken.item.display_name]
		JAIL:
			Police.go_to_jail(run)
			return "They book you and lock the door. You keep everything, but you are not going anywhere for a while."
		PAY:
			var paid := mini(int(encounter.amount), maxi(0, run.cash))
			run.cash -= paid
			return "You hand over %s." % Format.money(paid)
		FIGHT:
			if roll < StreetEvents.fight_chance(run):
				StreetCred.add(run, StreetCred.FIGHT_WON)
				return "You fight them off and keep your cash."
			var lost := mini(roundi(int(encounter.amount) * StreetEvents.FIGHT_LOSS_MULTIPLIER), maxi(0, run.cash))
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
