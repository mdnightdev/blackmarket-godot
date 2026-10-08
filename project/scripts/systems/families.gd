class_name Families

## The three triad families. run.family_standing maps a family id to the player's standing,
## from -100 to 100. Missing families start at 0, which is Neutral.

enum Tier { HOSTILE, NEUTRAL, TRUSTED, FAMILY }

const TIER_NAMES: Array[String] = ["Hostile", "Neutral", "Trusted", "Family"]
const MIN_STANDING := -100
const MAX_STANDING := 100
const HOSTILE_AT := -30
const TRUSTED_AT := 30
const FAMILY_AT := 70

const BUY_FACTORS := { Tier.TRUSTED: 0.93, Tier.FAMILY: 0.85 }
const SELL_FACTORS := { Tier.TRUSTED: 1.05, Tier.FAMILY: 1.1 }

const SHAKEDOWN := "shakedown"
const SHAKEDOWN_CHANCE := 0.2
## The usual demand grows by the day. The actual demand lands between the low and high factors of it.
const SHAKEDOWN_BASE := 400
const SHAKEDOWN_PER_DAY := 40
const SHAKEDOWN_LOW_FACTOR := 0.6
const SHAKEDOWN_HIGH_FACTOR := 1.5
const PAID_GAIN := 10
const REFUSED_LOSS := 5
## Share of the player's cash taken when they refuse to pay: the floor, the usual and the rare worst case.
const BEATING_LOW := 0.03
const BEATING_USUAL := 0.06
const BEATING_HIGH := 0.1
const MAX_BEATING := 2500

const PAY_UP: StringName = &"pay_up"
const REFUSE: StringName = &"refuse"


static func standing(run: RunState, family_id: StringName) -> int:
	return int(run.family_standing.get(family_id, 0))


static func tier(run: RunState, family_id: StringName) -> Tier:
	var value := standing(run, family_id)
	if value <= HOSTILE_AT:
		return Tier.HOSTILE
	if value >= FAMILY_AT:
		return Tier.FAMILY
	if value >= TRUSTED_AT:
		return Tier.TRUSTED
	return Tier.NEUTRAL


static func tier_name(value: Tier) -> String:
	return TIER_NAMES[value]


static func family_of(speaker: SpeakerDef) -> FamilyDef:
	if speaker == null or speaker.family.is_empty():
		return null
	return Content.family(speaker.family)


## Moves standing with a family and returns the change actually applied.
static func shift(run: RunState, family_id: StringName, amount: int) -> int:
	if Content.family(family_id) == null:
		return 0
	var before := standing(run, family_id)
	var after := clampi(before + amount, MIN_STANDING, MAX_STANDING)
	run.family_standing[family_id] = after
	return after - before


static func buy_factor(run: RunState, speaker: SpeakerDef) -> float:
	var family := family_of(speaker)
	return float(BUY_FACTORS.get(tier(run, family.id), 1.0)) if family != null else 1.0


static func sell_factor(run: RunState, speaker: SpeakerDef) -> float:
	var family := family_of(speaker)
	return float(SELL_FACTORS.get(tier(run, family.id), 1.0)) if family != null else 1.0


## Family members turn the player away while their family is hostile.
static func refuses(run: RunState, speaker: SpeakerDef) -> bool:
	var family := family_of(speaker)
	return family != null and tier(run, family.id) == Tier.HOSTILE


## The hostile family that runs the district, or null when the player is safe there.
static func hostile_family_in(run: RunState, district_id: StringName) -> FamilyDef:
	for family in Content.families():
		if family.home_districts.has(district_id) and tier(run, family.id) == Tier.HOSTILE:
			return family
	return null


static func shakedown_cost(run: RunState) -> int:
	var usual := float(SHAKEDOWN_BASE + run.day * SHAKEDOWN_PER_DAY)
	var rng := Odds.rng_for(run, &"shakedown")
	return roundi(Odds.bell(rng, usual * SHAKEDOWN_LOW_FACTOR, usual, usual * SHAKEDOWN_HIGH_FACTOR))


static func beating_cost(run: RunState) -> int:
	var share := Odds.bell(Odds.rng_for(run, &"beating"), BEATING_LOW, BEATING_USUAL, BEATING_HIGH)
	return clampi(roundi(maxi(0, run.cash) * share), 0, MAX_BEATING)


static func shakedown(run: RunState) -> Dictionary:
	var family := hostile_family_in(run, run.district_id)
	if family == null:
		return {}
	return {
		"type": SHAKEDOWN,
		"speaker": String(family.lieutenant),
		"title": "Shakedown",
		"body": "The %s has not forgotten you. Walking our streets costs money now. Pay, or my people take it." % family.english_name,
		"family": String(family.id),
		"demand": shakedown_cost(run),
		"beating": beating_cost(run),
	}


static func resolve_shakedown(run: RunState, encounter: Dictionary, choice: StringName) -> String:
	var family_id := StringName(str(encounter.get("family", "")))
	match choice:
		PAY_UP:
			var paid := mini(int(encounter.demand), maxi(0, run.cash))
			run.cash -= paid
			shift(run, family_id, PAID_GAIN)
			return "You pay %s. The family takes note." % Format.money(paid)
		REFUSE:
			var lost := mini(int(encounter.get("beating", beating_cost(run))), maxi(0, run.cash))
			run.cash -= lost
			shift(run, family_id, -REFUSED_LOSS)
			return "Her people hold you against a wall and take %s." % Format.money(lost)
	return ""


static func sanitize(source: Variant) -> Dictionary:
	var result := {}
	if source is Dictionary:
		for key: Variant in source:
			var family_id := StringName(str(key))
			if Content.family(family_id) != null:
				result[family_id] = clampi(int(source[key]), MIN_STANDING, MAX_STANDING)
	return result
