class_name CornerTalk

## Street corners: tapping one on the district screen, and Mama Lin selling hers through Auntie Tran.

const ATTACK: StringName = &"attack"
const BUY: StringName = &"buy"
const NEXT: StringName = &"next"
const LEAVE: StringName = &"leave"
const LEXIE: StringName = &"lexie"
const MAMA_LIN: StringName = &"mama_lin"

const TRAN_TIP := "Sit, child. Mama Lin is selling her corner. Vex squeezed her dry. Ten thousand, and she wants out before Vex hears."
const LEXIE_WARNING := "Buy it and Vex will hear by morning. You know that, right?"
const OFFER_LINE := "Mama Lin is still waiting on an answer. Ten thousand, and the corner is yours."
const MAMA_LIN_LINE := "Take it. The stall, the regulars, the trouble. All yours."
const RABBIT_LINES: Array[String] = [
	"A corner in Vex's market. You need someone standing next to you now.",
	"I'm in. Not for money. Someone has to make sure you come home.",
]


## people is everyone working the corner this phase, from Corners.people_at.
static func open(corner: CornerDef, people: Array[SpeakerDef]) -> void:
	var run := GameState.run
	var gang := Gangs.owner(run.district_id)
	var holder := "You hold it." if Corners.holds(run, corner.id) else "%s holds it." % (gang.display_name if gang != null else "Nobody")
	var line := "%s. %s It moves %s." % [corner.display_name, holder, corner.moves.to_lower()]
	var choices: Array[DialogueChoice] = []
	for person in people:
		choices.append(DialogueChoice.new(person.id, "Talk to %s" % person.display_name))
	var hint := "Pays %s rent and %s protection every morning to whoever holds it." % [Format.money(corner.rent), Format.money(corner.protection)]
	if corner.rent == 0:
		hint = "Pays %s protection every morning to whoever holds it." % Format.money(corner.protection)
	if War.is_open(run) and not Corners.holds(run, corner.id):
		choices.append(DialogueChoice.new(ATTACK, "Plan an attack", War.can_attack(run, corner)))
		if not War.can_attack(run, corner):
			hint = "You need men to take a corner. Auntie Tran knows who is looking for work."
	choices.append(DialogueChoice.new(LEAVE, "Leave", true, true))
	GameOverlay.talk(Content.player(run.player_id), line, choices, _on_corner_choice.bind(corner, people), hint)


static func _on_corner_choice(choice: StringName, corner: CornerDef, people: Array[SpeakerDef]) -> void:
	if choice == ATTACK:
		WarTalk.plan(corner)
		return
	for person in people:
		if person.id != choice:
			continue
		if person is DealerDef:
			DealerTalk.talk_to(person)
		elif person is CharacterDef:
			StreetTalk.talk_to(person)
		return
	GameOverlay.end_talk()


## Auntie Tran passes on Mama Lin's offer. The first time, Lexie warns the player about Vex.
static func offer_mama_lin(tran: CharacterDef) -> void:
	var run := GameState.run
	if not Story.mark(run, Corners.SALE_HEARD):
		_show_offer(tran, OFFER_LINE)
		return
	GameState.save_run()
	GameOverlay.talk(tran, TRAN_TIP, _next(), func(_choice: StringName) -> void:
		GameOverlay.talk(Content.speaker(LEXIE), LEXIE_WARNING, _next(), func(_id: StringName) -> void: _show_offer(tran, OFFER_LINE)))


static func _show_offer(tran: CharacterDef, line: String) -> void:
	var price := Format.money(Corners.MAMA_LIN_PRICE)
	var choices: Array[DialogueChoice] = [
		DialogueChoice.new(BUY, "Buy it (%s)" % price, GameState.run.cash >= Corners.MAMA_LIN_PRICE),
		DialogueChoice.new(LEAVE, "Not yet", true, true),
	]
	var hint := "Your first corner in Old Market. It pays %s every morning, and Rook starts selling you weapons." % Format.money(Corners.find(Corners.MAMA_LIN).daily_cut())
	GameOverlay.talk(tran, line, choices, _on_offer_choice, hint)


static func _on_offer_choice(choice: StringName) -> void:
	if choice != BUY:
		GameOverlay.end_talk()
		return
	if GameState.buy_mama_lin_corner() != Corners.Result.OK:
		GameOverlay.say("Ten thousand. Not a dollar less.", TripTalk.continue_only(), TripTalk.end)
		return
	AudioService.play_sfx(Sfx.COINS_OUT)
	var pages: Array[Dictionary] = [{ "speaker": Content.speaker(MAMA_LIN), "line": MAMA_LIN_LINE }]
	for line in RABBIT_LINES:
		pages.append({ "speaker": Content.speaker(Corners.FRIEND), "line": line })
	_show_pages(pages, 0)


static func _show_pages(pages: Array[Dictionary], index: int) -> void:
	if index >= pages.size():
		GameOverlay.end_talk()
		return
	var page := pages[index]
	var hint := "午夜兔子 joins you as muscle, free." if index == pages.size() - 1 else ""
	GameOverlay.talk(page.speaker, str(page.line), _next(), func(_choice: StringName) -> void: _show_pages(pages, index + 1), hint)


static func _next() -> Array[DialogueChoice]:
	return [DialogueChoice.new(NEXT, "Next", true, false, true)]
