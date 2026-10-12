extends SceneTree

## Headless balance report. Run from project/:
## ../Godot_v4.3-stable_linux.arm64 --headless -s "$(realpath ../tools/balance/balance_sim.gd)" -- [days] [runs] [strategies]
## strategies is an optional comma separated subset, for example local,broker.
## The bot is loaded after the autoloads exist, since the game systems reference them.

const DEFAULT_DAYS := 60
const DEFAULT_RUNS := 20
const STRATEGIES: Array[StringName] = [&"idle", &"local", &"route", &"broker"]
const REPORT_PATH := "/tmp/balance_report.txt"
const SAVE_PATH := "/tmp/balance_sim_run.json"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var days := _int_arg(args, 0, DEFAULT_DAYS)
	var runs := _int_arg(args, 1, DEFAULT_RUNS)
	var strategies := STRATEGIES
	if args.size() > 2:
		strategies = STRATEGIES.filter(func(strategy: StringName) -> bool: return args[2].split(",").has(String(strategy)))

	var game_state := root.get_node("GameState")
	game_state.set("_store", load("res://scripts/core/save_store.gd").new(SAVE_PATH))
	var bot_script: GDScript = load(get_script().resource_path.get_base_dir().path_join("balance_bot.gd"))
	var bot: RefCounted = bot_script.new(game_state, root.get_node("Content"))

	var lines: PackedStringArray = ["BLACK MARKET balance report, %d runs per strategy, %d days" % [runs, days]]
	for strategy in strategies:
		var results: Array[Dictionary] = []
		for index in runs:
			results.append(bot.play(strategy, 1000 + index, days))
		lines.append_array(_summarize(strategy, results, bot_script.CHECKPOINT_DAYS))

	var report := "\n".join(lines)
	print(report)
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	file.store_string(report)
	file.close()
	quit()


func _int_arg(args: PackedStringArray, index: int, fallback: int) -> int:
	if args.size() > index and args[index].is_valid_int():
		return maxi(1, int(args[index]))
	return fallback


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

	lines.append(_day_line("cleared the debt", _days_of(results, "cleared_day"), results.size()))
	lines.append(_day_line("debt sold to Vex", _days_of(results, "sold_day"), results.size()))

	var busts := 0
	var realized := 0
	var missed := 0
	var worst_streak := 0
	var final_debts: Array[int] = []
	for result in results:
		busts += int(result.busts)
		realized += int(result.realized_profit)
		missed += int(result.missed_weeks)
		worst_streak = maxi(worst_streak, int(result.worst_streak))
		final_debts.append(int(result.final_debt))
	final_debts.sort()
	lines.append("missed weeks per run: %.1f, longest streak: %d, median final debt: %d" % [
		float(missed) / results.size(), worst_streak, final_debts[final_debts.size() / 2],
	])
	lines.append("busts per run: %.1f, realized trade profit per run: %+d" % [
		float(busts) / results.size(), realized / results.size(),
	])

	lines.append_array(_order_lines(results))
	lines.append("average per run, by source:")
	for entry in _averaged(results, "ledger"):
		lines.append("  %-28s %+8d" % [entry.label, entry.value])
	lines.append("average count per run:")
	for entry in _averaged(results, "counts"):
		lines.append("  %-40s %6.1f" % [entry.label, entry.exact])
	return lines


## Customer orders handed over, by temperament: how many per run and the average profit over the goods cost, before fares.
func _order_lines(results: Array[Dictionary]) -> PackedStringArray:
	var totals := {}
	for result in results:
		var orders: Dictionary = result.get("orders", {})
		for temperament: String in orders:
			var total: Dictionary = totals.get(temperament, { "count": 0, "profit": 0, "cost": 0, "walked": 0 })
			total.count += int(orders[temperament].count)
			total.profit += int(orders[temperament].profit)
			total.cost += int(orders[temperament].cost)
			total.walked += int(orders[temperament].walked)
			totals[temperament] = total
	var lines: PackedStringArray = []
	if totals.is_empty():
		return lines
	lines.append("customer orders handed over, by temperament:")
	for temperament: String in totals:
		var total: Dictionary = totals[temperament]
		lines.append("  %-10s %5.1f per run, average profit %+6d (%+.0f%% of goods cost), walked off %d" % [
			temperament, float(total.count) / results.size(), roundi(float(total.profit) / maxi(1, int(total.count) - int(total.walked))),
			100.0 * total.profit / maxi(1, int(total.cost)), int(total.walked),
		])
	return lines


func _days_of(results: Array[Dictionary], key: String) -> Array[int]:
	var days: Array[int] = []
	for result in results:
		if int(result[key]) > 0:
			days.append(int(result[key]))
	days.sort()
	return days


func _day_line(label: String, days: Array[int], total: int) -> String:
	if days.is_empty():
		return "%s: 0%% of runs" % label
	return "%s: %d%% of runs, median day %d, earliest %d, latest %d" % [
		label, roundi(100.0 * days.size() / total), days[days.size() / 2], days[0], days[-1],
	]


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
