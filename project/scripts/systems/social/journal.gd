class_name Journal

## Finished jobs, newest first, for the Completed and Failed tabs of the jobs page.
## Each entry is { "title": String, "place": String, "stamp": int, "failed": bool } with stamp as the phase it closed.

const MAX_ENTRIES := 30


## A job that closed before its deadline without being done, such as a dropped order or a seized crate.
static func mark_failed(run: RunState, job_id: String) -> void:
	if not job_id.is_empty():
		run.failed_job_ids.append(job_id)


## Logs every job in before that is no longer active. A job gone past its last phase failed.
static func record_finished(run: RunState, before: Array[Dictionary]) -> void:
	var stamp := Calendar.stamp(run)
	var active := {}
	for job in Jobs.deadlines(run):
		active[job.id] = true
	for job in before:
		if active.has(job.id):
			continue
		run.journal.push_front({
			"title": str(job.title),
			"place": str(job.place),
			"stamp": stamp,
			"failed": stamp > int(job.due) or run.failed_job_ids.has(job.id),
		})
	run.failed_job_ids.clear()
	if run.journal.size() > MAX_ENTRIES:
		run.journal.resize(MAX_ENTRIES)


static func entries(run: RunState, failed: bool) -> Array[Dictionary]:
	var picked: Array[Dictionary] = []
	for entry in run.journal:
		if bool(entry.failed) == failed:
			picked.append(entry)
	return picked


static func sanitize(source: Dictionary) -> Dictionary:
	var title := str(source.get("title", ""))
	if title.is_empty():
		return {}
	return {
		"title": title,
		"place": str(source.get("place", "")),
		"stamp": maxi(0, int(source.get("stamp", 0))),
		"failed": bool(source.get("failed", false)),
	}
