class_name WarTalk

## The war for Old Market: sizing up a corner, the fight itself, and what everyone says after.
## The odds are never shown, before or after.

const NEXT: StringName = &"next"
const LEAVE: StringName = &"leave"
const HIRE_UNIT: StringName = &"hire_unit"
const MERCY: StringName = &"mercy"

const LEXIE: StringName = &"lexie"
const TRAN: StringName = &"tran"
const RAMOS: StringName = &"officer"
const VEX: StringName = &"rival"
const RABBIT: StringName = &"midnight_rabbit"
const LEXIE_WARNED := "lexie_war_warning"
const FIRST_LOSS_HEARD := "rabbit_first_loss"

const BLADE_FIGHTERS: Array[Texture2D] = [
	preload("res://assets/battle/blades_1.png"), preload("res://assets/battle/blades_2.png"),
	preload("res://assets/battle/blades_3.png"), preload("res://assets/battle/blades_4.png"),
]
const GUN_FIGHTERS: Array[Texture2D] = [
	preload("res://assets/battle/rifles_1.png"), preload("res://assets/battle/rifles_2.png"),
	preload("res://assets/battle/rifles_3.png"), preload("res://assets/battle/rifles_4.png"),
]
const PLAYER_SQUADS: Array[String] = ["Front line", "Second line", "Reserve"]

const FIRST_LOSS_LINES: Array[String] = [
	"That was my fault. I let you go in with what you had.",
	"I still have friends from my unit. They don't work cheap and they don't work for strangers. They'll work for me.",
]
const LOST_AGAIN_LINE := "We regroup. They're bleeding too."
const SURRENDER: Array[Dictionary] = [
	{ "speaker": VEX, "line": "Enough. Enough. Show me mercy." },
]
const SURRENDER_OFFER := "My crew is done. I'm not. Give me a reason to stand up and I'll fight for you."
const AFTER_MERCY: Array[Dictionary] = [
	{ "speaker": RABBIT, "line": "I don't trust her." },
	{ "speaker": LEXIE, "line": "You don't have to trust her. Half this market only listens to her. Keep her and they listen to you." },
	{ "speaker": VEX, "line": "You won't regret it. Or you will, but not because of me." },
	{ "speaker": TRAN, "line": "So. My bar is in your market now. Drinks are still not free." },
	{ "speaker": LEXIE, "line": "Lesson's over. You're the one people come to now." },
	{ "speaker": RAMOS, "line": "Old Market's quiet. I like quiet. Quiet costs the same as before, amigo." },
	{ "speaker": Moreau.ID, "line": "Vex had four thousand blades and a market. Now she has neither, and you have both." },
	{ "speaker": Moreau.ID, "line": "I don't have a file on you yet. I'm buying the folder today." },
]


static func plan(corner: CornerDef) -> void:
	var run := GameState.run
	if Story.mark(run, LEXIE_WARNED):
		GameState.save_run()
		var lexie := Content.speaker(LEXIE)
		GameOverlay.talk(lexie, "Vex's people fight with blades. Old school. Doesn't mean they're slow.", _next(), func(_choice: StringName) -> void: plan(corner))
		return
	var message := "Pick who goes in. The wounded go to the hospital, the dead take their weapons with them."
	GameOverlay.pick_crew(corner.display_name, message, "Attack with %d", "Not yet", _attack.bind(corner), Callable())


static func _attack(deployment: Dictionary, corner: CornerDef) -> void:
	var run := GameState.run
	var carried := Army.issue(run, deployment)
	var result := GameState.attack_corner(corner.id, deployment)
	if result.is_empty():
		return
	var teams := sides(result, corner, carried)
	var line := "%s IS YOURS" % corner.display_name.to_upper() if bool(result.won) else "PULL BACK"
	GameOverlay.play_battle(teams[0], teams[1], line, hash(result), func() -> void:
		War.reconcile_live_battle(run, result, teams[0], teams[1])
		_aftermath(result, corner))


static func _aftermath(result: Dictionary, corner: CornerDef) -> void:
	var run := GameState.run
	var losses := report(result)
	if bool(result.ended):
		_show_pages(SURRENDER, 0, _offer_mercy)
	elif bool(result.won):
		var line := "%s moves %s. Now it moves it for you." % [corner.display_name, corner.moves.to_lower()]
		GameOverlay.talk(Content.speaker(LEXIE), line, _next(), _end, losses)
	elif War.unit_on_offer(run) and Story.mark(run, FIRST_LOSS_HEARD):
		GameState.save_run()
		var pages: Array[Dictionary] = []
		for page_line in FIRST_LOSS_LINES:
			pages.append({ "speaker": RABBIT, "line": page_line })
		_show_pages(pages, 0, offer_unit.bind(losses))
	else:
		GameOverlay.talk(Content.speaker(RABBIT), LOST_AGAIN_LINE, _next(), _end, losses)


## Rabbit's old unit, offered once the first attack fails. Also offered at Auntie Tran's.
static func offer_unit(hint := "") -> void:
	var run := GameState.run
	var price := Format.money(War.RABBIT_UNIT_PRICE)
	var choices: Array[DialogueChoice] = [
		DialogueChoice.new(HIRE_UNIT, "Hire them (%s)" % price, run.cash >= War.RABBIT_UNIT_PRICE),
		DialogueChoice.new(LEAVE, "Not now", true, true),
	]
	var line := "%s and they stand with us. Say the word." % price
	var joins := "%d of them join you as the Black Hand and stay after the war." % War.RABBIT_UNIT_SIZE
	var note := "%s %s" % [hint, joins] if not hint.is_empty() else joins
	GameOverlay.talk(Content.speaker(RABBIT), line, choices, _on_unit_choice, note)


static func _on_unit_choice(choice: StringName) -> void:
	if choice != HIRE_UNIT:
		GameOverlay.end_talk()
		return
	if GameState.hire_rabbit_unit():
		AudioService.play_sfx(Sfx.COINS_OUT)
		GameOverlay.talk(Content.speaker(RABBIT), "I'll make the calls. They'll be there.", _next(), _end)
	else:
		GameOverlay.talk(Content.speaker(RABBIT), "They want the money up front. All of it.", _next(), _end)


static func _offer_mercy() -> void:
	var choices: Array[DialogueChoice] = [DialogueChoice.new(MERCY, "Show mercy")]
	GameOverlay.talk(Content.speaker(VEX), SURRENDER_OFFER, choices, func(_choice: StringName) -> void: _show_pages(AFTER_MERCY, 0, GameOverlay.end_talk), "Vex becomes your enforcer.")


## The battle report for the player's side: dead, wounded and unhurt, then the tiers that bled.
static func report(result: Dictionary) -> String:
	var sent := Army.deployed_count(result.deployed)
	var dead := int(result.dead)
	var wounded := int(result.wounded)
	var text := "Dead %d, wounded %d, unhurt %d of %d." % [dead, wounded, sent - dead - wounded, sent]
	var parts: PackedStringArray = []
	for tier in Army.DEPLOY_ORDER:
		var loss: Dictionary = result.losses.get(tier, {})
		if int(loss.get("dead", 0)) + int(loss.get("wounded", 0)) > 0:
			parts.append("%s %d dead, %d wounded" % [Army.TIER_NAMES[tier], int(loss.dead), int(loss.wounded)])
	if not parts.is_empty():
		text += " %s." % ". ".join(parts)
	return text


static func _show_pages(pages: Array[Dictionary], index: int, then: Callable) -> void:
	if index >= pages.size():
		then.call()
		return
	var page := pages[index]
	var speaker := Content.speaker(StringName(str(page.speaker)))
	GameOverlay.talk(speaker, str(page.line), _next(), func(_choice: StringName) -> void: _show_pages(pages, index + 1, then))


## The two sides of a fight for a corner, from a War.attack or RivalStrike.defend result.
static func sides(result: Dictionary, corner: CornerDef, carried: Dictionary) -> Array[BattleSide]:
	var run := GameState.run
	var gang := Corners.gang_of(corner.id)
	var black_hand := int(result.deployed.get(Army.Tier.BLACK_HAND, 0)) > 0
	var mine := BattleSide.new()
	mine.display_name = "Your crew"
	mine.color = TurfBar.PLAYER_COLOR
	mine.head_count = Army.deployed_count(result.deployed)
	mine.survivors = mine.head_count - int(result.dead) - int(result.wounded)
	mine.squad_names = PLAYER_SQUADS
	mine.ranged = black_hand or _has_guns(carried)
	mine.fighters = GUN_FIGHTERS if mine.ranged else BLADE_FIGHTERS
	if black_hand:
		mine.skill_name = "Black Hand"
		mine.skill_owner = Content.speaker(RABBIT).display_name
		mine.skill_portrait = Content.speaker(RABBIT).portrait
	var theirs := BattleSide.new()
	theirs.display_name = gang.crew_name if gang != null else "Their crew"
	theirs.color = gang.color if gang != null else Palette.RISK_HIGH
	theirs.head_count = int(result.defenders)
	theirs.survivors = theirs.head_count - int(result.defenders_lost)
	theirs.ranged = gang != null and Rivals.gear(run, gang) >= Armory.Grade.HANDGUN
	theirs.fighters = GUN_FIGHTERS if theirs.ranged else BLADE_FIGHTERS
	theirs.squad_names = _rival_squads(gang, theirs.ranged)
	if mine.ranged == theirs.ranged:
		mine.team_color = mine.color
	var boss := Content.character(gang.boss) if gang != null else null
	if corner.stronghold and boss != null:
		theirs.skill_name = "Vex's sword" if gang.id == War.VEX_GANG else "%s's guard" % gang.display_name
		theirs.skill_owner = gang.display_name
		theirs.skill_portrait = boss.portrait
	return [mine, theirs]


static func _rival_squads(gang: GangDef, ranged: bool) -> Array[String]:
	var squads: Array[String] = ["Lookouts", "Gunmen" if ranged else "Blades"]
	squads.append("%s's guard" % gang.display_name if gang != null else "The guard")
	return squads


static func _has_guns(carried: Dictionary) -> bool:
	for tier: int in carried:
		for grade: int in [Armory.Grade.HANDGUN, Armory.Grade.RIFLE, Armory.Grade.MILITARY]:
			if int(carried[tier].get(grade, 0)) > 0:
				return true
	return false


## What the deployment carries into the fight, best weapons first. Empty when nobody is armed or sent.
static func weapons_text(run: RunState, deployment: Dictionary) -> String:
	var totals := {}
	var carried := Army.issue(run, deployment)
	for tier: int in carried:
		for grade: int in carried[tier]:
			totals[grade] = int(totals.get(grade, 0)) + int(carried[tier][grade])
	var parts: PackedStringArray = []
	for grade in Armory.BEST_FIRST:
		if int(totals.get(grade, 0)) > 0:
			parts.append("%d with %s" % [int(totals[grade]), str(Armory.GRADE_NAMES[grade]).to_lower()])
	if int(totals.get(Armory.Grade.NONE, 0)) > 0:
		parts.append("%d with bare hands" % int(totals[Armory.Grade.NONE]))
	return ("Armed: %s." % ", ".join(parts)) if not parts.is_empty() else ""


static func _next() -> Array[DialogueChoice]:
	return [DialogueChoice.new(NEXT, "Next", true, false, true)]


static func _end(_choice: StringName) -> void:
	GameOverlay.end_talk()
