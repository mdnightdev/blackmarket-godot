class_name WeaponsTalk

## Rook's weapons, sold out of the back of his garage in any amount, cash only. He buys them back at half his price.
## Jackal's men drop by once to collect.

const NEXT: StringName = &"next"
const LEAVE: StringName = &"leave"
const SELL: StringName = &"sell"
const BACK: StringName = &"back"

const ASKED := "rook_weapons"
const BACK_ROOM_SHOWN := "rook_back_room"
const MILITARY_SHOWN := "rook_military"
const JACKAL_VISITED := "rook_jackal"
## Orders placed before Jackal's men walk in on a sale.
const JACKAL_VISIT_ORDERS := 2

const FIRST_LINE := "Who told you? Doesn't matter. Name the number. You don't say my name, I don't remember your face."
const BACK_ROOM_LINE := "You pay, you don't talk. Rare combination. Come round the back."
const MILITARY_LINE := "This is the stuff armies argue about. Don't ask where it comes from. Don't use it near my garage."
const SHOP_LINE := "Cash first. What do you need?"
const SOLD_LINE := "Done. It never came from here."
const SELL_LINE := "Half what I charge. I have to sell it twice and lie about it once."
const BOUGHT_BACK_LINE := "I'll find it a new home. Anything else?"
const JACKAL_VISIT := "Two of Jackal's men walk in. \"Collection day, Rook.\" He hands over an envelope without a word."
const JACKAL_AFTER := "Every month a little more. That's why I sell what I sell."


static func open(rook: CharacterDef) -> void:
	var run := GameState.run
	if run.rook_orders >= JACKAL_VISIT_ORDERS and Story.mark(run, JACKAL_VISITED):
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
	for grade in Armory.on_sale(run):
		var label := "%s, %s each" % [Armory.GRADE_NAMES[grade], Format.money(int(Armory.UNIT_PRICES[grade]))]
		choices.append(DialogueChoice.new(StringName(str(grade)), label, Armory.most_affordable(run, grade) > 0))
	choices.append(DialogueChoice.new(SELL, "Sell to Rook", Armory.total(run) > 0))
	choices.append(DialogueChoice.new(LEAVE, "Leave", true, true))
	GameOverlay.talk(rook, line, choices, _on_choice.bind(rook), _stock_hint(run))


static func _on_choice(choice: StringName, rook: CharacterDef) -> void:
	match choice:
		LEAVE:
			GameOverlay.end_talk()
		SELL:
			_show_buy_back(rook)
		_:
			GameOverlay.pick_weapons(int(String(choice)) as Armory.Grade, false, _after_buying.bind(rook))


static func _show_buy_back(rook: CharacterDef) -> void:
	var run := GameState.run
	var choices: Array[DialogueChoice] = []
	for grade: int in Armory.GRADE_NAMES:
		var owned := Armory.count(run, grade as Armory.Grade)
		if owned > 0:
			choices.append(DialogueChoice.new(StringName(str(grade)), "%s, %s owned" % [Armory.GRADE_NAMES[grade], Format.count(owned)]))
	choices.append(DialogueChoice.new(BACK, "Back", true, true))
	GameOverlay.talk(rook, SELL_LINE, choices, _on_buy_back_choice.bind(rook), _stock_hint(run))


static func _on_buy_back_choice(choice: StringName, rook: CharacterDef) -> void:
	if choice == BACK:
		_show_shop(rook, SHOP_LINE)
		return
	GameOverlay.pick_weapons(int(String(choice)) as Armory.Grade, true, _after_selling.bind(rook))


static func _after_buying(bought: bool, rook: CharacterDef) -> void:
	var line := opening_line(GameState.run)
	_show_shop(rook, SOLD_LINE if bought and line == SHOP_LINE else line)


static func _after_selling(sold: bool, rook: CharacterDef) -> void:
	_show_shop(rook, BOUGHT_BACK_LINE if sold else SHOP_LINE)


static func _stock_hint(run: RunState) -> String:
	var owned: PackedStringArray = []
	for grade: int in Armory.GRADE_NAMES:
		var count := Armory.count(run, grade as Armory.Grade)
		if count > 0:
			owned.append("%s %s" % [Format.count(count), str(Armory.GRADE_NAMES[grade]).to_lower()])
	if owned.is_empty():
		return "Each weapon arms one man in a fight."
	return "You own %s. Each weapon arms one man in a fight." % ", ".join(owned)


static func _next() -> Array[DialogueChoice]:
	return [DialogueChoice.new(NEXT, "Next", true, false, true)]
