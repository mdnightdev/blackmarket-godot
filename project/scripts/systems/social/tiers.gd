class_name Tiers

## The city splits into three money tiers. Goods, districts and dealers each carry one.

const STREET := 1
const MIDDLE := 2
const WEALTHY := 3

const NAMES := { STREET: "Street", MIDDLE: "Middle class", WEALTHY: "Wealthy" }

const INSULTED_LINES: Array[String] = [
	"You brought me %s? Take that back to the street.",
	"%s? Do I look like a corner shop?",
	"Get those %s out of my sight. I deal in real money.",
]
const OUT_OF_RANGE_LINES: Array[String] = [
	"%s? That's above my pay grade. Try uptown.",
	"I can't move %s. My buyers don't have that kind of cash.",
]


## Trade goods a dealer of this tier deals in: its own tier and the one below.
static func goods(tier: int) -> Array[ItemDef]:
	var list: Array[ItemDef] = []
	for item in Content.tradable_items():
		if item.tier == tier or item.tier == tier - 1:
			list.append(item)
	return list


## What a dealer says when offered goods outside their tier. Empty when they would buy it.
static func refusal(dealer: DealerDef, item: ItemDef) -> String:
	if dealer.deals_in(item):
		return ""
	var lines := INSULTED_LINES if item.tier < dealer.tier else OUT_OF_RANGE_LINES
	var line: String = lines[absi(hash([dealer.id, item.id])) % lines.size()]
	var goods_name := item.display_name if line.begins_with("%") else item.display_name.to_lower()
	return line % goods_name
