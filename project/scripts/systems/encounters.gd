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
const STAY: StringName = &"stay"
const PAY: StringName = &"pay"
const FIGHT: StringName = &"fight"
const TAKE: StringName = &"take"
const LEAVE: StringName = &"leave"

const BEAT_OFFICER: StringName = Police.BRANDT
const RAID_LEAD: StringName = Police.BRANDT
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
	var police_quiet := Police.is_quiet(run)
	var raid_due := Heat.is_maxed(run) and not police_quiet
	Heat.cool_down(run, new_day_started)
	StreetEvents.prune(run)
	Turf.gangs_push(run)

	if new_day_started:
		Turf.collect_daily_cut(run)
		Loan.accrue_interest(run)
		if Loan.is_payment_due_today(run):
			var missed := Loan.amount_due(run) > 0
			if missed:
				run.missed_weeks += 1
				run.missed_total += 1
			else:
				run.missed_weeks = 0
			SharkTrust.settle_week(run, not missed)
			if missed and not DebtSale.is_due(run):
				run.pending_encounter = send_enforcers(run)
			Loan.start_next_period(run)
		if DebtSale.check(run):
			return

	if has_pending(run):
		return
	Turf.check_victory(run)
	if has_pending(run) or Police.is_jailed(run):
		return
	if RabbitCells.check(run, new_day_started):
		return
	if Corners.check(run, new_day_started):
		return
	if VexAmbush.check(run, new_day_started, rng.randf()):
		return
	if travelled and Smuggling.is_carrying(run) and Routes.ambush_due(run, rng.randf()):
		run.pending_encounter = Ambush.start(run)
	elif raid_due:
		run.pending_encounter = raid_or_warning(run)
	elif not police_quiet and rng.randf() < Police.stop_chance(run):
		run.pending_encounter = police_stop(run)
	elif Gangs.queue_encounter(run, rng):
		pass
	elif Families.hostile_family_in(run, run.district_id) != null and rng.randf() < Families.SHAKEDOWN_CHANCE:
		run.pending_encounter = Families.shakedown(run)
	elif rng.randf() < StreetEvents.EVENT_CHANCE:
		run.pending_encounter = StreetEvents.roll_event(run, events, rng)
		if int(run.pending_encounter.get("effect", -1)) == EventDef.Effect.PRICE_SHIFT:
			StreetEvents.apply_shift(run, run.pending_encounter)


## A trip that ends inside the current phase. Gangs, families and street events stay once per phase,
## so only an ambush on a hot run and the police can catch up with the player here.
static func after_arrival(run: RunState, rng: RandomNumberGenerator) -> void:
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


## Ramos tips the player off when he can. Otherwise a lookout on the crew, or Jin's old contacts, turn one raid a
## day into a warning and time to scatter the goods.
static func raid_or_warning(run: RunState) -> Dictionary:
	if Ramos.can_tip(run):
		return Ramos.tip(run)
	var lookout := Crew.can_warn_of_raid(run)
	if not lookout and not Edges.hears_of_raid(run):
		return raid(run)
	if lookout:
		Crew.use_raid_warning(run)
	else:
		Edges.use_raid_tip(run)
	Heat.add(run, -RAID_WARNING_COOLING)
	var source := "Your lookout spots" if lookout else "An old contact texts you about"
	return {
		"type": RAID_WARNING,
		"speaker": String(run.player_id),
		"title": "Raid warning",
		"body": "%s a raid team forming down the street. You scatter the goods before they move in." % source,
	}


## Brandt makes the stop, unless Ramos works for Vex and is the patrol in the district. The player runs or stays.
static func police_stop(run: RunState) -> Dictionary:
	var patrol := Roster.strongest_patrol(run, run.district_id, Calendar.stamp(run))
	var officer := Ramos.ID if patrol != null and patrol.id == Ramos.ID else BEAT_OFFICER
	run.stop_stamp = Calendar.stamp(run)
	RabbitCells.note_stop(run)
	return {
		"type": POLICE,
		"speaker": String(officer),
		"title": "Police stop",
		"body": "Hold it right there. Open the bag, nice and slow.",
		"bribe": Police.bribe_cost(run),
		"negotiating": false,
		"cornered": false,
	}


## The same officer, now face to face: the player bribes, talks, or lets him search. A cornered player already ran
## and got caught, so the bribe goes up.
static func police_talk(stop: Dictionary, cornered: bool) -> Dictionary:
	var bribe := int(stop.bribe)
	return {
		"type": POLICE,
		"speaker": str(stop.speaker),
		"title": "Police stop",
		"body": "Nice try. Hands on the wall." if cornered else "Smart. Now, what are you carrying?",
		"bribe": roundi(bribe * Police.CORNERED_BRIBE_FACTOR) if cornered else bribe,
		"negotiating": true,
		"cornered": cornered,
	}


## On the Vex branch Ramos leads the raid, and he knows where the stash is.
static func raid(run: RunState) -> Dictionary:
	var hostile := Ramos.is_hostile(run)
	Police.arrest(run, hostile)
	var share := "Half" if Campaign.is_act_two(run) else "Some"
	if hostile:
		return {
			"type": RAID,
			"speaker": String(Ramos.ID),
			"title": "Raid",
			"body": "Vex says hello. %s of the bag and the stash is evidence now. Nothing personal, amigo." % share,
		}
	return {
		"type": RAID,
		"speaker": String(RAID_LEAD),
		"title": "Raid",
		"body": "Your name keeps coming up on my street. %s of what you were carrying is evidence now." % share,
	}


static func send_enforcers(run: RunState) -> Dictionary:
	var cash_taken := Loan.enforcer_cash_take(run)
	var interest := Loan.missed_week_interest(run)
	run.cash -= cash_taken
	run.debt += interest
	var taken := Format.money(cash_taken) if cash_taken > 0 else "nothing worth taking"
	if Loan.is_with_vex(run):
		return {
			"type": ENFORCERS,
			"speaker": String(Loan.VEX_LENDER),
			"title": "Vex's crew",
			"body": "Vex says you're late. We took %s, and %s goes on your tab." % [taken, Format.money(interest)],
		}
	var body := "The Shark sends his regards. And his interest. I took %s, and %s goes on your debt." % [taken, Format.money(interest)]
	if not run.career:
		body += " Missed %d of %d in a row." % [run.missed_weeks, Loan.MAX_MISSED_WEEKS]
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
			if not bool(encounter.get("negotiating", false)):
				list.append(Choice.new(RUN, "Run for it"))
				list.append(Choice.new(STAY, "Stay put"))
				return list
			var bribe := int(encounter.bribe)
			list.append(Choice.new(BRIBE, "Bribe %s" % Format.money(bribe), run.cash >= bribe))
			var line := Talk.police_line(run)
			list.append(Choice.new(line, Talk.police_label(run, line)))
			list.append(Choice.new(COMPLY, "Let him search"))
		Gangs.GATE, Gangs.HUNT:
			list.append_array(Gangs.choices(run, encounter))
		Ambush.TYPE:
			list.append_array(Ambush.choices(run, encounter))
		Collections.TYPE:
			list.append_array(Collections.choices(run, encounter))
		CustomerHandover.TYPE:
			list.append_array(CustomerHandover.choices(run, encounter))
		DebtSale.RABBIT_OFFER:
			list.append_array(DebtSale.choices(run, encounter))
		RabbitCells.MISSING, RabbitCells.RELEASED:
			list.append_array(RabbitCells.choices(run, encounter))
		Corners.TIP, Corners.STALL_SMASHED:
			list.append_array(Corners.choices(run, encounter))
		Ramos.TIP:
			list.append_array(Ramos.choices(run))
		VexAmbush.TYPE:
			list.append_array(VexAmbush.choices(run))
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
		Gangs.GATE, Gangs.HUNT:
			return Gangs.resolve(run, encounter, choice, roll)
		Ambush.TYPE:
			return Ambush.resolve(run, encounter, choice, roll)
		Collections.TYPE:
			return Collections.resolve(run, encounter, choice, roll)
		CustomerHandover.TYPE:
			return CustomerHandover.resolve(run, encounter, choice, roll)
		Families.SHAKEDOWN:
			return Families.resolve_shakedown(run, encounter, choice)
		Turf.VICTORY:
			return Turf.victory_summary(Gangs.of_encounter(encounter))
		DebtSale.DEBT_SOLD, DebtSale.VEX_TERMS, DebtSale.RABBIT_OFFER:
			return DebtSale.resolve(run, encounter, choice)
		RabbitCells.MISSING, RabbitCells.RELEASED:
			return RabbitCells.resolve(run, encounter, choice)
		Corners.TIP, Corners.STALL_SMASHED:
			return Corners.resolve(run, encounter, choice)
		Ramos.TIP:
			return Ramos.outcome_text(Ramos.resolve(run, choice))
		VexAmbush.TYPE:
			return VexAmbush.resolve(run, encounter, choice, roll)
	match choice:
		BRIBE:
			Police.pay_bribe(run, int(encounter.bribe))
			return "You slip them %s. They wave you on." % Format.money(int(encounter.bribe))
		RUN:
			if Police.run_for_it(run, roll):
				return "You lose them in the alleys, but they will remember your face."
			run.pending_encounter = police_talk(encounter, true)
			return "They cut you off at the end of the alley. No more running."
		STAY:
			run.pending_encounter = police_talk(encounter, false)
			return ""
		Talk.PLAY_DUMB, Talk.SHOW_ID, Talk.NAME_DROP:
			var talked := Talk.resolve_police(run, choice, roll)
			if talked.free:
				return str(talked.text)
			return "%s %s" % [talked.text, search(run)]
		COMPLY:
			return search(run)
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


## Nothing illegal and the officer lets the player go. Anything he finds is evidence, and the player is booked.
static func search(run: RunState) -> String:
	var carried := Police.carried_value(run)
	var taken := Police.comply(run)
	if taken.is_empty():
		return "He turns the bag inside out and finds nothing. He lets you go, and writes your name down."
	Police.go_to_jail(run, carried)
	var bail := Format.money(run.jail_bail)
	if taken.has("crate"):
		return "He pries open Voronin's crate and books you. Bail is %s. Voronin will hear about this." % bail
	return "He bags %d %s as evidence and books you. Bail is %s." % [taken.quantity, taken.item.display_name, bail]
