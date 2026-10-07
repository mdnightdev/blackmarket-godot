class_name SaveStore
extends RefCounted

const FORMAT_VERSION := 1

var path: String


func _init(save_path: String) -> void:
	path = save_path


func exists() -> bool:
	return FileAccess.file_exists(path)


## Writes to a temp file first and renames it over the old save,
## so a crash or kill mid-write never leaves a half-written save.
func write(data: Dictionary) -> Error:
	var payload := {
		"version": FORMAT_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"data": data,
	}
	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(payload))
	file.close()
	return DirAccess.rename_absolute(temp_path, path)


## Returns an empty Dictionary when the save is missing, unreadable, or from a newer build.
func read() -> Dictionary:
	if not exists():
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_warning("Save at %s is not valid JSON" % path)
		return {}
	var version := int(parsed.get("version", 0))
	if version < 1 or version > FORMAT_VERSION:
		push_warning("Save at %s has unsupported version %d" % [path, version])
		return {}
	var data: Variant = parsed.get("data")
	if not data is Dictionary:
		push_warning("Save at %s has no data block" % path)
		return {}
	return data


func delete() -> void:
	if exists():
		DirAccess.remove_absolute(path)
