extends SceneTree

## Headless balance report. Run from project/:
## ../Godot_v4.3-stable_linux.arm64 --headless -s "$(realpath ../tools/balance/balance_sim.gd)" -- [runs]
## The bot is loaded after the autoloads exist, since the game systems reference them.

const DEFAULT_RUNS := 40
const STRATEGIES: Array[StringName] = [&"idle", &"local", &"route"]
const REPORT_PATH := "/tmp/balance_report.txt"
const SAVE_PATH := "/tmp/balance_sim_run.json"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var runs := DEFAULT_RUNS
	var args := OS.get_cmdline_user_args()
	if not args.is_empty() and args[0].is_valid_int():
		runs = int(args[0])

	var game_state := root.get_node("GameState")
	game_state.set("_store", load("res://scripts/core/save_store.gd").new(SAVE_PATH))
	var bot_script: GDScript = load(get_script().resource_path.get_base_dir().path_join("balance_bot.gd"))
	var bot: RefCounted = bot_script.new(game_state, root.get_node("Content"))

	var lines: PackedStringArray = ["BLACK MARKET balance report, %d runs per strategy, %d days" % [runs, bot_script.DAYS]]
	for strategy in STRATEGIES:
		var results: Array[Dictionary] = []
		for index in runs:
			results.append(bot.play(strategy, 1000 + index))
		lines.append_array(_summarize(strategy, results, bot_script.CHECKPOINT_DAYS))

	var report := "\n".join(lines)
	print(report)
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	file.store_string(report)
	file.close()
	quit()


func _summarize(strategy: StringName, results: Array[Dictionary], checkpoint_days: Array[int]) -> PackedStringArray:
	var lines: PackedStringArray = ["", "== %s ==" % strategy]
	for day in checkpoint_days:
		var values: Array[int] = []
		for result in results:
			if result.checkpoints.has(day):
				values.append(int(result.checkpoints[day]))
		if values.is_empty():
			continue
		values.sort()
		var losing := values.filter(func(value: int) -> bool: return value < 0).size()
		lines.append("day %2d  net worth change: median %+d, worst %+d, best %+d, behind start in %d%% of runs" % [
			day, values[values.size() / 2], values[0], values[-1], roundi(100.0 * losing / values.size()),
		])

	var lost := results.filter(func(result: Dictionary) -> bool: return result.lost).size()
	var busts := 0
	var realized := 0
	for result in results:
		busts += int(result.busts)
		realized += int(result.realized_profit)
	lines.append("lost the run: %d%%, busts per run: %.1f, realized trade profit per run: %+d" % [
		roundi(100.0 * lost / results.size()), float(busts) / results.size(), realized / results.size(),
	])

	lines.append("average per run, by source:")
	for entry in _averaged(results, "ledger"):
		lines.append("  %-28s %+8d" % [entry.label, entry.value])
	lines.append("average count per run:")
	for entry in _averaged(results, "counts"):
		lines.append("  %-40s %6.1f" % [entry.label, entry.exact])
	return lines


func _averaged(results: Array[Dictionary], key: String) -> Array[Dictionary]:
	var totals := {}
	for result in results:
		var source: Dictionary = result[key]
		for label: StringName in source:
			totals[label] = int(totals.get(label, 0)) + int(source[label])
	var entries: Array[Dictionary] = []
	for label: StringName in totals:
		var exact := float(totals[label]) / results.size()
		entries.append({ "label": String(label), "value": roundi(exact), "exact": exact })
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.value < b.value)
	return entries
