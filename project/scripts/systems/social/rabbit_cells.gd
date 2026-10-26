class_name RabbitCells

## 午夜兔子's night in the cells, the Act 1 scare. After the first police stop where the player carried goods,
## Ramos picks him up instead. From day 4 he is missing one morning and the player chooses how to get him out:
## pay Ramos, ask Lexie (half a day), or wait (a day, and he comes out angrier). Ramos keeps his medal either way.

enum Stage { NONE, DUE, WITH_LEXIE, WAITING, FREE }

const MISSING := "rabbit_missing"
const RELEASED := "rabbit_released"

const GO_TO_RAMOS: StringName = &"go_to_ramos"
const ASK_LEXIE: StringName = &"ask_lexie"
const WAIT: StringName = &"wait"

const EARLIEST_DAY := 4
const RAMOS_FEE := 300
const LEXIE_PHASES := 2
const FRIEND: StringName = &"midnight_rabbit"

const RELEASE_LINES: Array[String] = [
	"They didn't find anything. They kept my service medal, though.",
	"Don't look like that. I've been held by worse than Ramos.",
	"It's fine. Just... next time, tell me before you do something loud.",
]
const ANGRY_LAST_LINE := "A whole day and nobody came. Next time you do something loud, you tell me first."


## Called when the police stop the player. Only the first stop with goods on them counts.
static func note_stop(run: RunState) -> void:
	if run.career or run.rabbit_cells != Stage.NONE:
		return
	if Inventory.used(run) > 0:
		run.rabbit_cells = Stage.DUE


## Queues the next scene when its time has come. Returns true when one was queued.
static func check(run: RunState, new_day_started: bool) -> bool:
	if Encounters.has_pending(run):
		return false
	match run.rabbit_cells:
		Stage.DUE:
			if not new_day_started or run.day < EARLIEST_DAY or run.career:
				return false
			run.pending_encounter = {
				"type": MISSING,
				"speaker": String(run.player_id),
				"title": "Morning",
				"body": "Rabbit didn't come home last night. His phone goes straight to voicemail.",
			}
			return true
		Stage.WITH_LEXIE, Stage.WAITING:
			if Calendar.stamp(run) < run.rabbit_release_stamp:
				return false
			_release(run, run.rabbit_cells == Stage.WAITING)
			return true
	return false


static func choices(run: RunState, encounter: Dictionary) -> Array[Encounters.Choice]:
	var list: Array[Encounters.Choice] = []
	if str(encounter.get("type", "")) == MISSING:
		list.append(Encounters.Choice.new(GO_TO_RAMOS, "Go to Ramos (%s)" % Format.money(RAMOS_FEE), run.cash >= RAMOS_FEE))
		list.append(Encounters.Choice.new(ASK_LEXIE, "Ask Lexie (half a day)"))
		list.append(Encounters.Choice.new(WAIT, "Wait for him"))
	else:
		list.append(Encounters.Choice.new(Encounters.CONTINUE, "Continue"))
	return list


## Returns the line to show, empty when the next scene speaks for itself.
static func resolve(run: RunState, encounter: Dictionary, choice: StringName, _roll: float = 0.0) -> String:
	if str(encounter.get("type", "")) == RELEASED:
		var page := int(encounter.get("page", 0)) + 1
		if page < RELEASE_LINES.size():
			run.pending_encounter = _released(page, bool(encounter.get("angry", false)))
		return ""
	match choice:
		GO_TO_RAMOS:
			run.cash -= RAMOS_FEE
			_release(run, false)
			return ""
		ASK_LEXIE:
			run.rabbit_cells = Stage.WITH_LEXIE
			run.rabbit_release_stamp = Calendar.stamp(run) + LEXIE_PHASES
			return "Lexie knows who's on shift tonight. She says give her half a day."
		_:
			run.rabbit_cells = Stage.WAITING
			run.rabbit_release_stamp = run.day * RunState.Phase.size()
			return "You wait. The phone stays quiet all day."


static func _release(run: RunState, angry: bool) -> void:
	run.rabbit_cells = Stage.FREE
	run.rabbit_release_stamp = -1
	run.rabbit_medal_held = true
	run.pending_encounter = _released(0, angry)


static func _released(page: int, angry: bool) -> Dictionary:
	var line := ANGRY_LAST_LINE if angry and page == RELEASE_LINES.size() - 1 else RELEASE_LINES[page]
	return {
		"type": RELEASED,
		"speaker": String(FRIEND),
		"title": "Out of the cells",
		"body": line,
		"page": page,
		"angry": angry,
	}
