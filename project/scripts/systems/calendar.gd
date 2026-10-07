class_name Calendar

const PHASE_SECONDS := 300.0


## Counts phases since the run began. Used to seed prices and to expire per-phase state.
static func stamp(run: RunState) -> int:
	return (run.day - 1) * RunState.Phase.size() + run.phase


## Moves the run forward one phase. Returns true when this started a new day.
static func advance_phase(run: RunState) -> bool:
	run.phase_seconds_left = PHASE_SECONDS
	if run.phase < RunState.Phase.NIGHT:
		run.phase = (run.phase + 1) as RunState.Phase
		return false
	run.phase = RunState.Phase.MORNING
	run.day += 1
	return true
