class_name Jobs

## Deadlines across bar orders, family favours, Voronin's crate and the Shark's errands, for reminders.
## Each entry is { "title": String, "place": String, "due": int } with due as the last phase stamp.

## Jobs whose last phase is this one or the next.
const SOON_PHASES := 1


static func deadlines(run: RunState) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for order in run.orders:
		var item := Content.item(StringName(order.item))
		var dealer := Content.dealer(StringName(order.dealer))
		if item == null or dealer == null:
			continue
		var district := Content.district(dealer.district_id)
		list.append({
			"title": "%d %s for %s" % [int(order.quantity), item.display_name, dealer.display_name],
			"place": district.display_name if district != null else "",
			"due": int(order.due),
		})
	for favour in run.favours:
		var item := Content.item(StringName(favour.item))
		var family := Content.family(StringName(favour.family))
		var lieutenant := Content.character(family.lieutenant) if family != null else null
		if item == null or lieutenant == null:
			continue
		list.append({
			"title": "%d %s for %s" % [int(favour.quantity), item.display_name, lieutenant.display_name],
			"place": "",
			"due": int(favour.due),
		})
	if Smuggling.is_carrying(run):
		var destination := Smuggling.destination(run.crate)
		list.append({
			"title": "Voronin's crate",
			"place": destination.display_name if destination != null else "",
			"due": int(run.crate.get("due", -1)),
		})
	for errand in run.errands:
		var place := Content.district(Errands.target_district(errand))
		list.append({
			"title": Errands.job_title(errand),
			"place": place.display_name if place != null else "",
			"due": int(errand.due_stamp),
		})
	return list


static func due_soon(run: RunState) -> Array[Dictionary]:
	var stamp := Calendar.stamp(run)
	return deadlines(run).filter(func(job: Dictionary) -> bool: return int(job.due) >= stamp and int(job.due) - stamp <= SOON_PHASES)


## Jobs that have just entered their final phase.
static func in_last_phase(run: RunState) -> Array[Dictionary]:
	var stamp := Calendar.stamp(run)
	return deadlines(run).filter(func(job: Dictionary) -> bool: return int(job.due) == stamp)
