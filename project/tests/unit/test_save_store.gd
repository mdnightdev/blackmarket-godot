extends GutTest

const TEST_PATH := "user://test_save_store.json"

var _store: SaveStore


func before_each() -> void:
	_store = SaveStore.new(TEST_PATH)
	_store.delete()


func after_each() -> void:
	_store.delete()


func test_missing_save_reads_empty() -> void:
	assert_false(_store.exists())
	assert_eq(_store.read(), {})


func test_write_then_read_round_trips() -> void:
	assert_eq(_store.write({"cash": 1500, "district_id": "docks"}), OK)
	assert_true(_store.exists())
	var data := _store.read()
	assert_eq(int(data.get("cash")), 1500)
	assert_eq(data.get("district_id"), "docks")


func test_write_leaves_no_temp_file() -> void:
	_store.write({"cash": 1})
	assert_false(FileAccess.file_exists(TEST_PATH + ".tmp"))


func test_overwrite_replaces_previous_save() -> void:
	_store.write({"cash": 1})
	_store.write({"cash": 2})
	assert_eq(int(_store.read().get("cash")), 2)


func test_corrupt_save_reads_empty() -> void:
	_write_raw("{not json")
	assert_eq(_store.read(), {})


func test_newer_format_version_is_rejected() -> void:
	_write_raw(JSON.stringify({"version": SaveStore.FORMAT_VERSION + 1, "data": {"cash": 5}}))
	assert_eq(_store.read(), {})


func test_legacy_version_zero_is_migrated() -> void:
	_write_raw(JSON.stringify({"version": 0, "data": {"district_id": "docks"}}))
	var data := _store.read()
	assert_eq(data.get("district_id"), "docks")
	assert_eq(data.get("cash"), 0)
	assert_eq(data.get("day"), 1)


func test_raw_save_dictionary_without_wrapper_is_recovered() -> void:
	_write_raw(JSON.stringify({"cash": 2500, "day": 4, "district_id": "old_market"}))
	var data := _store.read()
	assert_eq(data.get("district_id"), "old_market")
	assert_eq(int(data.get("cash")), 2500)
	assert_eq(int(data.get("day")), 4)


func test_delete_removes_save() -> void:
	_store.write({"cash": 1})
	_store.delete()
	assert_false(_store.exists())


func _write_raw(text: String) -> void:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()
