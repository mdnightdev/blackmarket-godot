class_name VexTalk

## Vex while she runs Old Market in Act 1. One line per meeting, picked by what the player has done. No muscle yet.

const NEXT: StringName = &"next"
const MET := "vex_met"
const HEARD_EARLY_PAYMENT := "vex_early_payment"
## From this street rank on the player sells enough to bother her.
const COMFORTABLE_RANK := 3

const FIRST_LINES: Array[String] = [
	"New face, full bag. In my market. You know what that means?",
	"It means you pay me, or you sell somewhere I can't see you.",
]
const EARLY_PAYMENT_LINE := "The Shark likes you. The Shark likes a lot of people. Until he doesn't."
const COMFORTABLE_LINE := "You're getting comfortable. Comfortable people get cut."
const SMALL_LINE := "Cute. Keep it small and I'll pretend I didn't see."
const HINT := "Vex runs Old Market and taxes every corner in it."


## What she says this time. Marks one-time lines as heard.
static func lines(run: RunState) -> Array[String]:
	if Story.mark(run, MET):
		return FIRST_LINES.duplicate()
	if run.shark_letter_sent and Story.mark(run, HEARD_EARLY_PAYMENT):
		return [EARLY_PAYMENT_LINE]
	if StreetCred.rank(run) >= COMFORTABLE_RANK:
		return [COMFORTABLE_LINE]
	return [SMALL_LINE]


static func play(vex: CharacterDef) -> void:
	var pages := lines(GameState.run)
	GameState.save_run()
	_show(vex, pages, 0)


static func _show(vex: CharacterDef, pages: Array[String], index: int) -> void:
	if index >= pages.size():
		GameOverlay.end_talk()
		return
	var choices: Array[DialogueChoice] = [DialogueChoice.new(NEXT, "Next", true, false, true)]
	var hint := HINT if index == pages.size() - 1 else ""
	GameOverlay.talk(vex, pages[index], choices, func(_choice: StringName) -> void: _show(vex, pages, index + 1), hint)


const ENFORCER_INTRO := "vex_enforcer_intro"
const VEX_PROVEN := "vex_proven_enforcer"
const INTEL: StringName = &"intel"
const FORTIFY: StringName = &"fortify"
const LEAVE: StringName = &"leave"
const RABBIT: StringName = &"midnight_rabbit"


## True once the player has taken at least one corner outside Old Market, proving Vex to Midnight Rabbit.
static func passed_rabbit_test(run: RunState) -> bool:
	if Story.has(run, VEX_PROVEN):
		return true
	for corner_id in run.corners_held:
		var district_id := Corners.district_of(StringName(str(corner_id)))
		if not district_id.is_empty() and district_id != Corners.HOME:
			return true
	return false


static func play_enforcer(vex: CharacterDef) -> void:
	var run := GameState.run
	if not passed_rabbit_test(run):
		if Story.mark(run, ENFORCER_INTRO):
			GameState.save_run()
			var intro_pages: Array[Dictionary] = [
				{ "speaker": vex.id, "line": "You spared me at the Red Lantern. That makes my blade yours, boss. Point me at a district." },
				{ "speaker": RABBIT, "line": "Not yet. Taking orders in Old Market is easy. Take one corner outside this market first. I want to see her bleed for our crew before she touches the books." },
				{ "speaker": vex.id, "line": "Fair enough, soldier. Pick a corner in The Slums, The Docks, or Warehouse Row. Take it, and I'll run your street protection." },
			]
			_show_dialogue_pages(intro_pages, 0, func() -> void: _open_test_pending(vex))
			return
		_open_test_pending(vex)
		return
	if Story.mark(run, VEX_PROVEN):
		GameState.save_run()
		var proven_pages: Array[Dictionary] = [
			{ "speaker": RABBIT, "line": "She held the line when their lookouts counter-attacked. She's with us." },
			{ "speaker": vex.id, "line": "Told you. Desk is open, boss. Every corner we hold pays on time, and my lieutenants can fortify any district you name." },
		]
		_show_dialogue_pages(proven_pages, 0, func() -> void: _open_enforcer_desk(vex))
		return
	_open_enforcer_desk(vex)


static func _open_test_pending(vex: CharacterDef) -> void:
	var choices: Array[DialogueChoice] = [
		DialogueChoice.new(INTEL, "Size up the rival crews"),
		DialogueChoice.new(LEAVE, "Leave", true, true),
	]
	var line := "Rabbit is watching me. Take one corner outside Old Market and I'll open your enforcer desk."
	var hint := "Hit a corner in The Slums, The Docks, or Warehouse Row to prove Vex's loyalty."
	GameOverlay.talk(vex, line, choices, func(choice: StringName) -> void:
		if choice == INTEL:
			_show_rival_intel(vex, func() -> void: _open_test_pending(vex))
		else:
			GameOverlay.end_talk(), hint)


static func _open_enforcer_desk(vex: CharacterDef) -> void:
	var run := GameState.run
	var held_corners := run.corners_held.size()
	var held_districts := Turf.held_count(run)
	var reserve := Army.reserve(run)
	var unposted := _unposted_held_corners(run)
	var line := "Your desk, boss. We hold %d corners across %d/%d contested districts (+%s/day). %s men in reserve." % [
		held_corners, held_districts, Turf.contested().size(), Format.money(Turf.daily_cut(run)), Format.count(reserve)
	]
	var choices: Array[DialogueChoice] = []
	var can_fortify := reserve >= unposted.size() * 10 and not unposted.is_empty()
	choices.append(DialogueChoice.new(
		FORTIFY,
		"Post 10 lookouts on %d unguarded corner%s" % [unposted.size(), "" if unposted.size() == 1 else "s"] if not unposted.is_empty() else "All held corners fortified",
		can_fortify
	))
	choices.append(DialogueChoice.new(INTEL, "Brief me on the rival crews"))
	choices.append(DialogueChoice.new(LEAVE, "Leave", true, true))
	var hint := "Enforcer Desk: manage street protection and track the four rival crews."
	GameOverlay.talk(vex, line, choices, func(choice: StringName) -> void:
		if choice == FORTIFY:
			for c in unposted:
				Corners.post_garrison(run, c.id, 10)
			GameState.save_run()
			AudioService.play_sfx(Sfx.FAVOUR_TAKEN)
			_open_enforcer_desk(vex)
		elif choice == INTEL:
			_show_rival_intel(vex, func() -> void: _open_enforcer_desk(vex))
		else:
			GameOverlay.end_talk(), hint)


static func _unposted_held_corners(run: RunState) -> Array[CornerDef]:
	var list: Array[CornerDef] = []
	for id_str in run.corners_held:
		var corner := Corners.find(StringName(str(id_str)))
		if corner != null and Corners.garrison(run, corner.id) <= 0:
			list.append(corner)
	return list


static func _show_rival_intel(vex: CharacterDef, then: Callable) -> void:
	var run := GameState.run
	var reports: PackedStringArray = []
	for gang in Gangs.confronting(run):
		var left := Rivals.corners(run, gang).size()
		var weapon := str(Armory.GRADE_NAMES[Rivals.gear(run, gang)]).to_lower()
		reports.append("%s holds %d corner%s with %s" % [gang.display_name, left, "" if left == 1 else "s", weapon])
	var text := "Every rival crew is out of the city. The streets are yours." if reports.is_empty() else ". ".join(reports) + "."
	var choices: Array[DialogueChoice] = [DialogueChoice.new(NEXT, "Back", true, false, true)]
	GameOverlay.talk(vex, text, choices, func(_c: StringName) -> void: then.call())


static func _show_dialogue_pages(pages: Array[Dictionary], index: int, then: Callable) -> void:
	if index >= pages.size():
		then.call()
		return
	var page := pages[index]
	var speaker := Content.speaker(StringName(str(page.speaker)))
	var choices: Array[DialogueChoice] = [DialogueChoice.new(NEXT, "Next", true, false, true)]
	GameOverlay.talk(speaker, str(page.line), choices, func(_c: StringName) -> void: _show_dialogue_pages(pages, index + 1, then))

