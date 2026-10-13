extends GutTest

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	_run.price_seed = 4242


func test_story_flags_mark_once_and_survive_a_save() -> void:
	assert_true(Story.mark(_run, "test_flag"))
	assert_false(Story.mark(_run, "test_flag"))
	var loaded := RunState.from_dict(JSON.parse_string(JSON.stringify(_run.to_dict())))
	assert_true(Story.has(loaded, "test_flag"))


func test_vex_opens_with_two_lines_then_one_per_meeting() -> void:
	assert_eq(VexTalk.lines(_run), VexTalk.FIRST_LINES)
	assert_eq(VexTalk.lines(_run), [VexTalk.SMALL_LINE])
	_run.shark_letter_sent = true
	assert_eq(VexTalk.lines(_run), [VexTalk.EARLY_PAYMENT_LINE])
	assert_eq(VexTalk.lines(_run), [VexTalk.SMALL_LINE], "the early payment line plays once")


func test_moreau_moves_through_her_stages() -> void:
	var moreau := Content.character(Moreau.ID)
	assert_eq(Moreau.stage(_run), Moreau.Stage.WATCHING)
	assert_true(Moreau.PASSING_LINES.has(Moreau.line(_run)))
	assert_false(Moreau.watches_player(_run, moreau))
	_run.shark_bought = true
	assert_eq(Moreau.stage(_run), Moreau.Stage.ATTENTION)
	assert_true(Moreau.watches_player(_run, moreau))
	assert_eq(Moreau.line(_run), Moreau.BUYOUT_LINE)
	assert_eq(Moreau.line(_run), Moreau.AROUND_LINE)
	Story.mark(_run, Moreau.WATCHLIST)
	assert_eq(Moreau.stage(_run), Moreau.Stage.RECORDING)


func test_only_moreau_follows_the_player() -> void:
	_run.shark_bought = true
	assert_false(Moreau.watches_player(_run, Content.character(&"officer")))


func test_voronin_greets_kade_as_the_courier_who_lost_his_crate() -> void:
	var voronin := Content.character(Errands.VORONIN)
	_run.player_id = &"kade"
	assert_eq(VoroninTalk.greeting(_run, voronin), VoroninTalk.FIRST_LINE_KADE)
	assert_eq(VoroninTalk.greeting(_run, voronin), voronin.line)


func test_voronin_notices_a_reliable_runner_once() -> void:
	var voronin := Content.character(Errands.VORONIN)
	_run.player_id = &"jin"
	assert_eq(VoroninTalk.greeting(_run, voronin), VoroninTalk.FIRST_LINE)
	_run.crate_streak = Smuggling.RELIABLE_STREAK
	assert_eq(VoroninTalk.greeting(_run, voronin), VoroninTalk.RELIABLE_LINE)
	assert_eq(VoroninTalk.greeting(_run, voronin), voronin.line)


func test_voronin_turns_cold_on_a_banned_day() -> void:
	_run.smuggling_ban_day = _run.day
	assert_eq(VoroninTalk.greeting(_run, Content.character(Errands.VORONIN)), VoroninTalk.BANNED_LINE)


func test_rook_talks_guns_once_then_opens_rooms() -> void:
	assert_eq(WeaponsTalk.opening_line(_run), WeaponsTalk.FIRST_LINE)
	assert_eq(WeaponsTalk.opening_line(_run), WeaponsTalk.SHOP_LINE)
	_run.rook_spent = int(Armory.ROOM_SPEND[Armory.Room.BACK])
	assert_eq(WeaponsTalk.opening_line(_run), WeaponsTalk.BACK_ROOM_LINE)
	_run.rook_spent = int(Armory.ROOM_SPEND[Armory.Room.MILITARY])
	assert_eq(WeaponsTalk.opening_line(_run), WeaponsTalk.MILITARY_LINE)
	assert_eq(WeaponsTalk.opening_line(_run), WeaponsTalk.SHOP_LINE)
