class_name Odds

## Hidden chances and amounts. The player never sees these numbers.
## Amounts land on a bell curve between a floor and a cap, so the usual value comes up most and the
## floor and cap only rarely. Contests compare strengths, so a much stronger side nearly always wins
## and an even match is a coin flip.

const MIN_CHANCE := 0.05
const MAX_CHANCE := 0.95
## How sharply a strength lead turns into wins. An edge of 0.1 wins about 68%, 0.2 about 82%, 0.4 about 95%.
const EDGE_SCALE := 7.5
## The floor and cap sit this many standard deviations away from the usual value.
const SPREAD_DEVIATIONS := 2.5
const GOOD_ODDS_AT := 0.7
const EVEN_ODDS_AT := 0.4


## The chance of winning a contest with this strength lead. A negative edge means the other side is stronger.
static func contest(edge: float) -> float:
	return clampf(1.0 / (1.0 + exp(-edge * EDGE_SCALE)), MIN_CHANCE, MAX_CHANCE)


## A value between low and high that is usually close to usual.
static func bell(rng: RandomNumberGenerator, low: float, usual: float, high: float) -> float:
	var deviation := rng.randfn(0.0, 1.0)
	var spread := (usual - low if deviation < 0.0 else high - usual) / SPREAD_DEVIATIONS
	return clampf(usual + deviation * spread, low, high)


## A random source fixed for this run, phase and purpose, so reloading a save cannot reroll the result.
static func rng_for(run: RunState, purpose: StringName) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run.price_seed, Calendar.stamp(run), purpose])
	return rng


## Words for a chance, for choices where the player needs a feel for the odds without the number.
static func reading(chance: float) -> String:
	if chance >= GOOD_ODDS_AT:
		return "good odds"
	if chance >= EVEN_ODDS_AT:
		return "even odds"
	return "long odds"
