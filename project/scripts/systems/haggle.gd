class_name Haggle

enum Outcome { ACCEPTED, COUNTERED, WALKED }

## Furthest an offer may stray from the asking price.
const MAX_DISCOUNT := 0.3
const MIN_TOLERANCE := 0.02
const MOOD_SWING := 0.04
const RISK_PENALTY_PER_POINT := 0.002
const RELAXED_MOOD := 0.14
const WARY_MOOD := 0.09


class Response:
	var outcome: Outcome
	var price: int

	func _init(response_outcome: Outcome, response_price: int) -> void:
		outcome = response_outcome
		price = response_price


## The dealer's mood shifts every phase. Higher means more room to bargain.
static func mood(run: RunState, dealer: DealerDef) -> float:
	return dealer.haggle_tolerance + Market.roll(run, [Calendar.stamp(run), dealer.id, &"mood"], -MOOD_SWING, MOOD_SWING)


static func mood_label(dealer_mood: float) -> String:
	if dealer_mood >= RELAXED_MOOD:
		return "Relaxed"
	if dealer_mood >= WARY_MOOD:
		return "Wary"
	return "Tense"


static func tolerance(run: RunState, dealer: DealerDef, item: ItemDef) -> float:
	var value := mood(run, dealer) + Gear.haggle_bonus(run) - item.risk * RISK_PENALTY_PER_POINT
	return clampf(value, MIN_TOLERANCE, MAX_DISCOUNT)


static func offer_range(asking: int, buying: bool) -> Vector2i:
	if buying:
		return Vector2i(ceili(asking * (1.0 - MAX_DISCOUNT)), asking)
	return Vector2i(asking, floori(asking * (1.0 + MAX_DISCOUNT)))


## Offers inside the tolerance are taken, offers up to twice as greedy get a counter, anything further ends the talk.
static func respond(asking: int, offer: int, buying: bool, dealer_tolerance: float) -> Response:
	var greed := float(asking - offer) / asking if buying else float(offer - asking) / asking
	if greed <= dealer_tolerance:
		return Response.new(Outcome.ACCEPTED, offer)
	if greed <= dealer_tolerance * 2.0:
		var counter := ceili(asking * (1.0 - dealer_tolerance)) if buying else floori(asking * (1.0 + dealer_tolerance))
		return Response.new(Outcome.COUNTERED, counter)
	return Response.new(Outcome.WALKED, asking)
