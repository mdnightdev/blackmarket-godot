extends GutTest

const FIXTURE_FOLDER := "res://tests/fixtures/items"


func test_load_folder_returns_resources_sorted_by_file_name() -> void:
	var items := Catalog.load_folder(FIXTURE_FOLDER)
	assert_eq(items.size(), 2)
	assert_eq(items[0].id, &"burner_phone")
	assert_eq(items[1].id, &"forged_passport")
	assert_true(items[0] is ItemDef)


func test_index_by_id_maps_ids_to_definitions() -> void:
	var index := Catalog.index_by_id(Catalog.load_folder(FIXTURE_FOLDER))
	assert_eq(index.size(), 2)
	var phone: ItemDef = index[&"burner_phone"]
	assert_eq(phone.kind, ItemDef.Kind.EQUIPMENT)
	assert_eq(phone.base_price, 120)


func test_index_by_id_keeps_first_of_duplicate_ids() -> void:
	var first := ItemDef.new()
	first.id = &"lockpick"
	first.base_price = 50
	var second := ItemDef.new()
	second.id = &"lockpick"
	second.base_price = 999
	var index := Catalog.index_by_id([first, second])
	assert_eq(index.size(), 1)
	assert_eq(index[&"lockpick"].base_price, 50)
