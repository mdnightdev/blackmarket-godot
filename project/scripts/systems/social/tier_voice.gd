class_name TierVoice

## Lines written for each money tier. Street talk is rough, middle class is businesslike,
## and wealthy clients are polished and impatient.

const CLOSING := {
	Tiers.STREET: [
		"Pleasure doing business.",
		"Done. Don't spend it all at once.",
		"Smart move. Come back soon.",
		"We never met.",
	],
	Tiers.MIDDLE: [
		"Clean and quick. That's how I like it.",
		"Good. Keep it off the books.",
		"Pleasure. Same time next week, maybe.",
		"Done. Nobody needs to hear about this.",
	],
	Tiers.WEALTHY: [
		"Splendid. My people will forget your face.",
		"Done. Do try to be quicker next time.",
		"Adequate. I may call on you again.",
		"Lovely. Now, if you'll excuse me.",
	],
}

const DELIVERED := {
	Tiers.STREET: ["Right on time. That's how you stay in business."],
	Tiers.MIDDLE: ["Exactly as agreed. I'll remember that."],
	Tiers.WEALTHY: ["Punctual. How refreshing."],
}

## Takes the quantity and the goods name.
const SHORT := {
	Tiers.STREET: ["You're short. I said %d %s, not a handful."],
	Tiers.MIDDLE: ["That's not the count we agreed. %d %s."],
	Tiers.WEALTHY: ["I asked for %d %s. Do count before you waste my time."],
}

## Ends a phoned-in job pitch. Takes the pay.
const PAY_TERMS := {
	Tiers.STREET: ["I pay %s for the lot.", "%s cash when it lands."],
	Tiers.MIDDLE: ["%s on delivery, no haggling.", "The fee is %s. Fair, I think."],
	Tiers.WEALTHY: ["%s. Do not keep me waiting.", "You will be paid %s. Discretion is included."],
}


static func pick(lines: Dictionary, tier: int) -> String:
	var pool: Array = lines.get(tier, lines[Tiers.STREET])
	return pool.pick_random()
