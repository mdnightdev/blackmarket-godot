class_name Story

## One-time story beats that already played, kept by id in run.story_flags.


static func has(run: RunState, flag: String) -> bool:
	return run.story_flags.has(flag)


## Returns true when the flag was not set before.
static func mark(run: RunState, flag: String) -> bool:
	if run.story_flags.has(flag):
		return false
	run.story_flags.append(flag)
	return true
