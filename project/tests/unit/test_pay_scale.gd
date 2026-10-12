extends GutTest

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	_run.price_seed = 99


func test_richer_tiers_pay_more() -> void:
	var rng := RandomNumberGenerator.new()
	for tier in [Tiers.STREET, Tiers.MIDDLE]:
		var band: Array = PayScale.BANDS[tier]
		var next_band: Array = PayScale.BANDS[tier + 1]
		assert_lte(band[2], next_band[2])
		rng.seed = tier
		assert_between(PayScale.roll(rng, _run, tier), band[0], band[2])


func test_pay_grows_with_rank_inside_a_tier() -> void:
	_run.street_cred = 0
	var low := PayScale.rank_scale(_run, Tiers.STREET)
	_run.street_cred = StreetCred.MAX
	assert_gt(PayScale.rank_scale(_run, Tiers.STREET), low)


func test_street_jobs_keep_coming_until_wealthy_districts_open() -> void:
	_run.street_cred = 0
	assert_eq(PayScale.top_tier(_run), Tiers.STREET)
	assert_false(PayScale.outgrown(_run, Tiers.STREET))
	_run.street_cred = int(StreetCred.RANKS[6].cred)
	assert_eq(PayScale.top_tier(_run), Tiers.MIDDLE, "wealthy districts open at rank 8")
	assert_false(PayScale.outgrown(_run, Tiers.STREET))
	_run.street_cred = StreetCred.MAX
	assert_eq(PayScale.top_tier(_run), Tiers.WEALTHY)
	assert_true(PayScale.outgrown(_run, Tiers.STREET))
