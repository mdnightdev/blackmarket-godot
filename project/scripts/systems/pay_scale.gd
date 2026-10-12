class_name PayScale

## What a job is worth by the tier of the district it happens in. Each band is the floor, the usual and the rare
## big job, at the rank that first opens the tier. Pay grows with every rank above that.

const BANDS := {
	Tiers.STREET: [1500.0, 3000.0, 7500.0],
	Tiers.MIDDLE: [10000.0, 18000.0, 40000.0],
	Tiers.WEALTHY: [50000.0, 100000.0, 250000.0],
}
const ENTRY_RANKS := { Tiers.STREET: 1, Tiers.MIDDLE: 4, Tiers.WEALTHY: 7 }
const RANK_GROWTH := 0.1


static func roll(rng: RandomNumberGenerator, run: RunState, tier: int) -> float:
	var band: Array = BANDS.get(tier, BANDS[Tiers.STREET])
	return Odds.bell(rng, band[0], band[1], band[2]) * rank_scale(run, tier)


static func rank_scale(run: RunState, tier: int) -> float:
	return 1.0 + RANK_GROWTH * maxi(0, StreetCred.rank(run) - int(ENTRY_RANKS.get(tier, 1)))


## The richest tier with at least one district the player can travel to.
static func top_tier(run: RunState) -> int:
	var top := Tiers.STREET
	for district in Content.districts():
		if district.tier > top and not Travel.is_locked(run, district):
			top = district.tier
	return top


## Jobs two tiers below what the player can reach stop coming in.
static func outgrown(run: RunState, tier: int) -> bool:
	return tier <= top_tier(run) - 2
