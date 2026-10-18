extends GutTest

const WHITE_TIGER: StringName = &"white_tiger"

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	_run.price_seed = 2024
	_run.district_id = &"golden_mile"
	_run.cash = 5000


func test_every_family_is_complete() -> void:
	var families := Content.families()
	assert_eq(families.size(), 3)
	for family in families:
		assert_false(family.chinese_name.is_empty(), String(family.id))
		assert_false(family.pinyin.is_empty(), String(family.id))
		assert_false(family.english_name.is_empty(), String(family.id))
		assert_not_null(family.emblem, String(family.id))
		assert_true(family.full_name().contains(family.chinese_name), String(family.id))
		var lieutenant := Content.character(family.lieutenant)
		assert_not_null(lieutenant, "%s lieutenant" % family.id)
		assert_eq(lieutenant.role, CharacterDef.Role.LIEUTENANT)
		assert_eq(lieutenant.family, family.id)
		assert_not_null(Content.family(family.rival), "%s rival" % family.id)
		assert_ne(family.rival, family.id)
		assert_false(family.home_districts.is_empty(), String(family.id))
		for district_id in family.home_districts:
			assert_not_null(Content.district(district_id), "%s home %s" % [family.id, district_id])


func test_members_point_at_real_families() -> void:
	var speakers: Array[SpeakerDef] = []
	speakers.append_array(Content.dealers())
	speakers.append_array(Content.characters())
	for speaker in speakers:
		if not speaker.family.is_empty():
			assert_not_null(Content.family(speaker.family), "%s family %s" % [speaker.id, speaker.family])


func test_tiers_follow_the_thresholds() -> void:
	assert_eq(Families.tier(_run, WHITE_TIGER), Families.Tier.NEUTRAL)
	_run.family_standing[WHITE_TIGER] = Families.HOSTILE_AT
	assert_eq(Families.tier(_run, WHITE_TIGER), Families.Tier.HOSTILE)
	_run.family_standing[WHITE_TIGER] = Families.TRUSTED_AT
	assert_eq(Families.tier(_run, WHITE_TIGER), Families.Tier.TRUSTED)
	_run.family_standing[WHITE_TIGER] = Families.FAMILY_AT
	assert_eq(Families.tier(_run, WHITE_TIGER), Families.Tier.FAMILY)


func test_shift_clamps_and_ignores_unknown_families() -> void:
	assert_eq(Families.shift(_run, WHITE_TIGER, 500), Families.MAX_STANDING)
	assert_eq(Families.standing(_run, WHITE_TIGER), Families.MAX_STANDING)
	assert_eq(Families.shift(_run, &"nobody", 10), 0)
	assert_false(_run.family_standing.has(&"nobody"))


func test_standing_moves_prices_only_at_family_dealers() -> void:
	var wei := Content.dealer(&"wei")
	var nadia := Content.dealer(&"nadia")
	var goods := Content.item(&"chip_kits")
	var neutral_buy := Market.buy_price(_run, wei, goods)
	var neutral_sell := Market.sell_price(_run, wei, goods)
	var outsider_buy := Market.buy_price(_run, nadia, goods)
	_run.family_standing[WHITE_TIGER] = Families.FAMILY_AT
	assert_lt(Market.buy_price(_run, wei, goods), neutral_buy)
	assert_gt(Market.sell_price(_run, wei, goods), neutral_sell)
	assert_eq(Market.buy_price(_run, nadia, goods), outsider_buy)


func test_hostile_families_refuse_business() -> void:
	var wei := Content.dealer(&"wei")
	assert_true(Market.is_open(_run, wei))
	_run.family_standing[WHITE_TIGER] = Families.MIN_STANDING
	assert_true(Families.refuses(_run, wei))
	assert_false(Market.is_open(_run, wei))
	assert_true(Market.is_open(_run, Content.dealer(&"nadia")))
	assert_false(Families.refuses(_run, Content.character(&"meiling")))


func test_shakedowns_only_happen_on_hostile_home_turf() -> void:
	assert_null(Families.hostile_family_in(_run, &"golden_mile"))
	assert_true(Families.shakedown(_run).is_empty())
	_run.family_standing[WHITE_TIGER] = Families.HOSTILE_AT
	assert_eq(Families.hostile_family_in(_run, &"golden_mile").id, WHITE_TIGER)
	assert_null(Families.hostile_family_in(_run, &"old_market"))
	var shakedown := Families.shakedown(_run)
	assert_eq(shakedown.type, Families.SHAKEDOWN)
	assert_eq(shakedown.speaker, "bai_shuang")
	assert_eq(int(shakedown.demand), Families.shakedown_cost(_run))


func test_paying_a_shakedown_wins_back_standing() -> void:
	_run.family_standing[WHITE_TIGER] = Families.HOSTILE_AT
	_run.pending_encounter = Families.shakedown(_run)
	var demand := int(_run.pending_encounter.demand)
	assert_ne(Encounters.resolve(_run, Families.PAY_UP, 0.0), "")
	assert_eq(_run.cash, 5000 - demand)
	assert_eq(Families.standing(_run, WHITE_TIGER), Families.HOSTILE_AT + Families.PAID_GAIN)
	assert_false(Encounters.has_pending(_run))


func test_refusing_a_shakedown_costs_cash_and_standing() -> void:
	_run.family_standing[WHITE_TIGER] = Families.HOSTILE_AT
	_run.pending_encounter = Families.shakedown(_run)
	Encounters.resolve(_run, Families.REFUSE, 0.0)
	var lost := 5000 - _run.cash
	assert_between(lost, floori(5000 * Families.BEATING_LOW), ceili(5000 * Families.BEATING_HIGH))
	assert_eq(Families.standing(_run, WHITE_TIGER), Families.HOSTILE_AT - Families.REFUSED_LOSS)


func test_cannot_pay_a_shakedown_without_the_cash() -> void:
	_run.family_standing[WHITE_TIGER] = Families.HOSTILE_AT
	_run.cash = 10
	_run.pending_encounter = Families.shakedown(_run)
	assert_eq(Encounters.resolve(_run, Families.PAY_UP, 0.0), "")
	assert_true(Encounters.has_pending(_run))


func test_standing_survives_a_save_and_is_sanitized() -> void:
	_run.family_standing = {WHITE_TIGER: 42, &"red_lotus": -35}
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(_run.to_dict())))
	assert_eq(restored.family_standing, {WHITE_TIGER: 42, &"red_lotus": -35})
	restored = RunState.from_dict({"family_standing": {"white_tiger": 900, "nobody": 5}})
	assert_eq(restored.family_standing, {WHITE_TIGER: Families.MAX_STANDING})
