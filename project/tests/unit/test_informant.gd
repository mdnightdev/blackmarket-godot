extends GutTest

var _run: RunState


func before_each() -> void:
	_run = RunState.new()
	_run.price_seed = 777


func test_tip_names_next_phase_patrols() -> void:
	var patrols := Informant.buy_tip(_run)
	assert_eq(_run.cash, RunState.STARTING_CASH - Informant.TIP_PRICE)
	assert_false(patrols.is_empty())
	var next_stamp := Calendar.stamp(_run) + 1
	for officer: CharacterDef in patrols:
		assert_eq(officer.role, CharacterDef.Role.POLICE)
		assert_eq(patrols[officer], Roster.character_location(_run, officer, next_stamp))


func test_tip_covers_every_police_character() -> void:
	var police := Content.characters().filter(func(character: CharacterDef) -> bool:
		return character.role == CharacterDef.Role.POLICE)
	assert_eq(Informant.patrols_next_phase(_run).size(), police.size())


func test_no_tip_without_cash() -> void:
	_run.cash = Informant.TIP_PRICE - 1
	assert_false(Informant.can_afford_tip(_run))
	assert_true(Informant.buy_tip(_run).is_empty())
	assert_eq(_run.cash, Informant.TIP_PRICE - 1)
