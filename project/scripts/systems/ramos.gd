class_name Ramos

## Officer Ramos is loyal to money and street power, and he moves with the Shark's book. While the Shark holds it he
## is neutral. Once the player buys the Shark out he is their asset: he never raids them and tips them off before
## Officer Brandt does. If Vex holds the book he is her asset and raids the player himself.
## Every tip the player answers by clearing out leaves Brandt empty-handed, and the police start hunting for the leak.
## When the hunt gets close Ramos goes quiet for a while. Leaving Brandt something to find calms it down.

enum Book { SHARK, PLAYER, VEX, NOBODY }

const ID: StringName = &"officer"
const TIP := "ramos_tip"
const CLEAR_OUT: StringName = &"clear_out"
const LEAVE_GOODS: StringName = &"leave_goods"
## Empty raids in a row, give or take a raid that found something, before Ramos lies low.
const LEAK_LIMIT := 3
const QUIET_DAYS := 5
## Share of each stack left behind for Brandt, rounded up.
const LEFT_SHARE := 0.25
const MEDAL_RETURNED := "ramos_medal_returned"

const TIP_LINE := "Brandt's got a warrant with your name on it. Tonight. You didn't hear it from me."
const QUIET_LINE := "They're counting who knew. I'm on the list. Give them something next time, or I'm no use to you."
const JOIN_LINE := "New boss, same envelope. The old man always paid on time, amigo. So will you."
const MEDAL_LINES: Array[Dictionary] = [
	{ "speaker": ID, "line": "And this belongs to your friend. I don't keep things that belong to the people who pay me." },
	{ "speaker": RabbitCells.FRIEND, "line": "My medal. ...Thanks. I'll still never like him." },
]


static func book(run: RunState) -> Book:
	if Story.has(run, War.BOOK_BURNED):
		return Book.NOBODY
	if run.shark_bought:
		return Book.PLAYER
	if Loan.is_with_vex(run):
		return Book.VEX
	return Book.SHARK


static func is_asset(run: RunState) -> bool:
	return book(run) == Book.PLAYER


## Only on the Vex branch does Ramos stop and raid the player himself.
static func is_hostile(run: RunState) -> bool:
	return book(run) == Book.VEX


static func is_lying_low(run: RunState) -> bool:
	return run.day < run.ramos_quiet_until


static func can_tip(run: RunState) -> bool:
	return is_asset(run) and not is_lying_low(run)


## Ramos comes over with the book and hands back what he kept from 午夜兔子. Returns the scene to play.
static func join_player(run: RunState) -> Array[Dictionary]:
	var pages: Array[Dictionary] = [{ "speaker": ID, "line": JOIN_LINE }]
	if run.rabbit_medal_held and Story.mark(run, MEDAL_RETURNED):
		run.rabbit_medal_held = false
		pages.append_array(MEDAL_LINES)
	return pages


static func tip(run: RunState) -> Dictionary:
	return {
		"type": TIP,
		"speaker": String(ID),
		"title": "Ramos calls",
		"body": TIP_LINE,
	}


static func choices(run: RunState) -> Array[Encounters.Choice]:
	return [
		Encounters.Choice.new(CLEAR_OUT, "Clear out everything"),
		Encounters.Choice.new(LEAVE_GOODS, "Leave some goods for Brandt", Inventory.used(run) > 0),
	]


## Brandt raids either way. Returns what he found as { found, units, quiet }.
static func resolve(run: RunState, choice: StringName) -> Dictionary:
	var units := 0
	if choice == LEAVE_GOODS:
		for item_id: StringName in run.inventory.keys():
			var left := ceili(Inventory.count(run, item_id) * LEFT_SHARE)
			Inventory.discard(run, item_id, left)
			units += left
		run.leak_suspicion = maxi(0, run.leak_suspicion - 1)
	else:
		run.leak_suspicion += 1
	var quiet := run.leak_suspicion >= LEAK_LIMIT
	if quiet:
		run.leak_suspicion = 0
		run.ramos_quiet_until = run.day + QUIET_DAYS
	Police.raided(run)
	return { "found": units > 0, "units": units, "quiet": quiet }


static func outcome_text(result: Dictionary) -> String:
	var text := "Brandt kicks the door in and finds nothing. He stands in the empty room a long time."
	if bool(result.found):
		text = "Brandt bags %d units as evidence and leaves smiling. He thinks he is winning." % int(result.units)
	if bool(result.quiet):
		text += " Ramos calls once more: \"%s\"" % QUIET_LINE
	return text
