class_name DebtSale

## The Act 1 failure branch. Three missed weeks in a row, or the Shark's trust at the floor, and he sells the debt
## to Vex and retires. Vex doubles it and her errands pay nothing. 午夜兔子 then offers his savings as a gift,
## or the player refuses and fights her. The scenes play in order: DEBT_SOLD, VEX_TERMS, RABBIT_OFFER.

enum RabbitOffer { NONE, REFUSED, TAKEN }

const DEBT_SOLD := "debt_sold"
const VEX_TERMS := "vex_terms"
const RABBIT_OFFER := "rabbit_offer"
const VEX_VISIT := "vex_visit"

const TAKE_GIFT: StringName = &"take_gift"
const REFUSE_GIFT: StringName = &"refuse_gift"

const SHARK: StringName = &"shark"
const FRIEND: StringName = &"midnight_rabbit"
const DEBT_MULTIPLIER := 2


static func is_due(run: RunState) -> bool:
	if run.career or run.lender != Loan.LENDER or run.debt <= 0:
		return false
	return run.missed_weeks >= Loan.MAX_MISSED_WEEKS or SharkTrust.at_floor(run)


## Sells the debt when it is due. Returns true when it happened now.
static func check(run: RunState) -> bool:
	if not is_due(run):
		return false
	run.lender = Loan.VEX_LENDER
	run.debt *= DEBT_MULTIPLIER
	run.missed_weeks = 0
	run.paid_this_period = 0
	run.covered_day = 0
	run.period_minimum = Loan.minimum_payment(run.debt)
	run.errand_offers.clear()
	run.errands.clear()
	run.pending_encounter = {
		"type": DEBT_SOLD,
		"speaker": String(SHARK),
		"title": "The Shark retires",
		"body": "I told you there is always someone less patient than me. I have sold your debt. I am retiring. Old men should. She runs my book now. All of it. Ramos too.",
	}
	return true


static func choices(run: RunState, encounter: Dictionary) -> Array[Encounters.Choice]:
	var list: Array[Encounters.Choice] = []
	if str(encounter.get("type", "")) == RABBIT_OFFER:
		list.append(Encounters.Choice.new(TAKE_GIFT, "Take his savings (%s)" % Format.money(run.debt)))
		list.append(Encounters.Choice.new(REFUSE_GIFT, "Refuse. We take it from her"))
	else:
		list.append(Encounters.Choice.new(Encounters.CONTINUE, "Continue"))
	return list


## Moves the branch to its next scene. Returns the line to show, empty when the next scene speaks for itself.
static func resolve(run: RunState, encounter: Dictionary, choice: StringName) -> String:
	match str(encounter.get("type", "")):
		DEBT_SOLD:
			run.pending_encounter = _vex_terms(run)
		VEX_TERMS:
			run.pending_encounter = _rabbit_offer()
		RABBIT_OFFER:
			if choice == TAKE_GIFT:
				run.rabbit_offer = RabbitOffer.TAKEN
				run.debt = 0
				Campaign.start_career_if_cleared(run)
				return "Then it's done. Go pay her before she changes her mind."
			run.rabbit_offer = RabbitOffer.REFUSED
			return "Then we take it from her. All of it."
	return ""


## Vex's answer to a refused or failed errand: her crew takes a cut of the carried cash.
static func send_crew(run: RunState) -> void:
	if Encounters.has_pending(run):
		return
	var taken := Loan.enforcer_cash_take(run)
	run.cash -= taken
	var what := Format.money(taken) if taken > 0 else "nothing worth taking"
	run.pending_encounter = {
		"type": VEX_VISIT,
		"speaker": String(Loan.VEX_LENDER),
		"title": "Vex's crew",
		"body": "Vex doesn't like hearing no. We took %s. Run her errands and we stay away from your door." % what,
	}


static func _vex_terms(run: RunState) -> Dictionary:
	return {
		"type": VEX_TERMS,
		"speaker": String(Loan.VEX_LENDER),
		"title": "Vex's terms",
		"body": "The old man sold you cheap. I don't sell cheap. Whatever you owed him, you owe me double: %s. And you'll run for me. For free." % Format.money(run.debt),
	}


static func _rabbit_offer() -> Dictionary:
	return {
		"type": RABBIT_OFFER,
		"speaker": String(FRIEND),
		"title": "午夜兔子",
		"body": "Vex has your debt now? How much? Forget it, I don't need the number. I walked out of one army, I'm not walking out on you. I have my service savings. Take it. It's not a loan. Don't make it weird.",
	}
