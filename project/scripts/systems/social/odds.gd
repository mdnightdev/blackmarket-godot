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


## Maps a uniform [0, 1) roll onto a Gaussian bell curve between low and high, centered at usual for roll = 0.5.
static func bell_from_roll(roll: float, low: float, usual: float, high: float) -> float:
	var deviation := probit(roll)
	var spread := (usual - low if deviation < 0.0 else high - usual) / SPREAD_DEVIATIONS
	return clampf(usual + deviation * spread, low, high)


## Standard normal quantile (inverse CDF) approximation in [-SPREAD_DEVIATIONS, SPREAD_DEVIATIONS]. Returns 0.0 at 0.5.
static func probit(p: float) -> float:
	var clamped := clampf(p, 0.001, 0.999)
	var x := 2.0 * clamped - 1.0
	if is_zero_approx(x):
		return 0.0
	var a := 0.147
	var ln_term := log(1.0 - x * x)
	var part1 := 2.0 / (PI * a) + ln_term / 2.0
	var part2 := ln_term / a
	var erfinv := signf(x) * sqrt(sqrt(part1 * part1 - part2) - part1)
	return clampf( sqrt(2.0) * erfinv, -SPREAD_DEVIATIONS, SPREAD_DEVIATIONS)


## Samples an index from candidate utility scores using Gaussian noise + Boltzmann Softmax exploration.
static func softmax_pick(rng: RandomNumberGenerator, scores: Array[float], temperature := 0.6, noise_sigma := 0.25) -> int:
	if scores.is_empty():
		return -1
	if scores.size() == 1:
		return 0
	var noisy: Array[float] = []
	var peak := -INF
	for s in scores:
		var val := s + (rng.randfn(0.0, noise_sigma) if noise_sigma > 0.0 else 0.0)
		noisy.append(val)
		if val > peak:
			peak = val
	var temp := maxf(0.05, temperature)
	var weights: Array[float] = []
	var total := 0.0
	for val in noisy:
		var w := exp((val - peak) / temp)
		weights.append(w)
		total += w
	var pick := rng.randf() * total
	var accum := 0.0
	for i in weights.size():
		accum += weights[i]
		if pick <= accum:
			return i
	return weights.size() - 1


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
