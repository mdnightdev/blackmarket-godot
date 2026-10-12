extends GutTest

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	Story.mark(_run, War.VEX_FELL)


func _as(player_id: StringName) -> RunState:
	_run.player_id = player_id
	return _run


func test_every_background_has_an_edge_and_an_origin() -> void:
	var edges := {}
	for player in Content.players():
		assert_ne(player.edge, PlayerDef.Edge.NONE, String(player.id))
		assert_false(player.edge_text.is_empty(), String(player.id))
		assert_false(player.origin_story.is_empty(), String(player.id))
		assert_false(player.origin_lines.is_empty(), String(player.id))
		for entry in player.origin_lines:
			var speaker := str(entry.speaker)
			assert_true(speaker == PlayerDef.ORIGIN_PLAYER or Content.speaker(StringName(speaker)) != null, speaker)
		edges[player.edge] = true
	assert_eq(edges.size(), Content.players().size(), "no two backgrounds share an edge")


func test_jin_hears_of_one_raid_a_day() -> void:
	_as(&"jin")
	_run.heat = Heat.MAX
	assert_eq(str(Encounters.raid_or_warning(_run).type), Encounters.RAID_WARNING)
	assert_false(Edges.hears_of_raid(_run))
	_run.heat = Heat.MAX
	assert_eq(str(Encounters.raid_or_warning(_run).type), Encounters.RAID)


func test_others_get_raided_without_a_lookout() -> void:
	_as(&"yuna")
	assert_eq(str(Encounters.raid_or_warning(_run).type), Encounters.RAID)


func test_jin_knows_where_a_boss_goes_next_phase() -> void:
	_as(&"jin")
	var vex := Content.gang(&"vex")
	var next := Gangs.boss_location(_run, vex, Calendar.stamp(_run) + 1)
	assert_eq(Edges.boss_next_phase(_run, next), vex)
	_as(&"kade")
	assert_null(Edges.boss_next_phase(_run, next))


func test_kade_travels_faster_and_pushes_through_safer() -> void:
	_as(&"kade")
	Travel.travel(_run, Content.district(&"docks"))
	assert_almost_eq(_run.phase_seconds_left, Calendar.PHASE_SECONDS - Travel.TRIP_SECONDS * Edges.ROUTES_TRIP_FACTOR, 0.01)
	assert_almost_eq(Roadblocks.push_risk(_run), Roadblocks.PUSH_RISK * Edges.ROUTES_PUSH_RISK_FACTOR, 0.0001)
	_as(&"mira")
	assert_almost_eq(Roadblocks.push_risk(_run), Roadblocks.PUSH_RISK, 0.0001)


func test_mira_spots_undercover_buyers() -> void:
	var sting := { "temperament": CustomerDef.Temperament.STING }
	assert_true(Edges.spots_sting(_as(&"mira"), sting))
	assert_false(Edges.spots_sting(_as(&"jin"), sting))
	assert_false(Edges.spots_sting(_as(&"mira"), { "temperament": CustomerDef.Temperament.FLAKY }))


func test_sasha_gets_better_bar_orders_and_blackjack() -> void:
	var venue := &"tran_bar"
	var normal := Orders.board(_as(&"jin"), venue)
	var better := Orders.board(_as(&"sasha"), venue)
	for index in normal.size():
		assert_eq(int(better[index].price), roundi(int(normal[index].price) * (1.0 + Edges.VENUE_ORDER_BONUS)))
	assert_eq(Edges.natural_payout(_run), Edges.VENUE_NATURAL_PAYOUT)


func test_tariq_rarely_gets_stiffed() -> void:
	var normal := Invoices.default_chance(_as(&"jin"))
	assert_almost_eq(Invoices.default_chance(_as(&"tariq")), normal * Edges.CREDIT_DEFAULT_FACTOR, 0.0001)


func test_yuna_buys_cheaper() -> void:
	var dealer := Content.dealer_in(&"old_market")
	var item := Content.item(&"burner_phones")
	var normal := Market.buy_price(_as(&"jin"), dealer, item)
	assert_lt(Market.buy_price(_as(&"yuna"), dealer, item), normal)
