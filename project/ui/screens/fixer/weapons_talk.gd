class_name WeaponsTalk

## Rook's weapons, sold out of the back of his garage in lots, cash only. Jackal's men drop by once to collect.

const NEXT: StringName = &"next"
const LEAVE: StringName = &"leave"

const ASKED := "rook_weapons"
const BACK_ROOM_SHOWN := "rook_back_room"
const MILITARY_SHOWN := "rook_military"
const JACKAL_VISITED := "rook_jackal"
## Lots bought before Jackal's men walk in on a sale.
const JACKAL_VISIT_LOTS := 2

const FIRST_LINE := "Who told you? Doesn't matter. Small lots. You don't say my name, I don't remember your face."
const BACK_ROOM_LINE := "You pay, you don't talk. Rare combination. Come round the back."
const MILITARY_LINE := "This is the stuff armies argue about. Don't ask where it comes from. Don't use it near my garage."
const SHOP_LINE := "Cash first. What do you need?"
const SOLD_LINE := "Done. It never came from here."
const NO_CASH_LINE := "Cash only. Come back when you have it."
const JACKAL_VISIT := "Two of Jackal's men walk in. \"Collection day, Rook.\" He hands over an envelope without a word."
const JACKAL_AFTER := "Every month a little more. That's why I sell what I sell."


static func open(rook: CharacterDef) -> void:
	var run := GameState.run
	if run.rook_lots >= JACKAL_VISIT_LOTS and Story.mark(run, JACKAL_VISITED):
		GameState.save_run()
		var player := Content.player(run.player_id)
		GameOverlay.talk(player, JACKAL_VISIT, _next(), func(_choice: StringName) -> void:
			GameOverlay.talk(rook, JACKAL_AFTER, _next(), func(_id: StringName) -> void: _show_shop(rook, SHOP_LINE)))
		return
	_show_shop(rook, opening_line(run))
	GameState.save_run()


## The first time he talks guns, or the room he just opened up. Marks the line as heard.
static func opening_line(run: RunState) -> String:
	if Story.mark(run, ASKED):
		return FIRST_LINE
	if Armory.room(run) == Armory.Room.MILITARY and Story.mark(run, MILITARY_SHOWN):
		return MILITARY_LINE
	if Armory.room(run) >= Armory.Room.BACK and Story.mark(run, BACK_ROOM_SHOWN):
		return BACK_ROOM_LINE
	return SHOP_LINE


static func _show_shop(rook: CharacterDef, line: String) -> void:
	var run := GameState.run
	var choices: Array[DialogueChoice] = []
	for index in Armory.lots_on_sale(run):
		var lot := Armory.LOTS[index]
		choices.append(DialogueChoice.new(StringName(str(index)), "Buy %s" % Armory.describe_lot(lot), run.cash >= Armory.lot_price(lot)))
	choices.append(DialogueChoice.new(LEAVE, "Leave", true, true))
	GameOverlay.talk(rook, line, choices, _on_choice.bind(rook), _stock_hint(run))


static func _on_choice(choice: StringName, rook: CharacterDef) -> void:
	if choice == LEAVE:
		GameOverlay.end_talk()
		return
	match GameState.buy_weapons(int(String(choice))):
		Armory.Result.OK:
			AudioService.play_sfx(Sfx.GEAR_BUY)
			var run := GameState.run
			var line := opening_line(run)
			_show_shop(rook, SOLD_LINE if line == SHOP_LINE else line)
			GameState.save_run()
		_:
			_show_shop(rook, NO_CASH_LINE)


static func _stock_hint(run: RunState) -> String:
	var owned: PackedStringArray = []
	for grade: int in Armory.GRADE_NAMES:
		var count := Armory.count(run, grade)
		if count > 0:
			owned.append("%d %s" % [count, str(Armory.GRADE_NAMES[grade]).to_lower()])
	if owned.is_empty():
		return "Each weapon arms one man in a fight."
	return "You own %s. Each weapon arms one man in a fight." % ", ".join(owned)


static func _next() -> Array[DialogueChoice]:
	return [DialogueChoice.new(NEXT, "Next", true, false, true)]
