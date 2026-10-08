extends GutTest

const EXPECTED_DISTRICTS := 10


func test_all_districts_load() -> void:
	assert_eq(Content.districts().size(), EXPECTED_DISTRICTS)


func test_district_ids_are_unique() -> void:
	var seen := {}
	for district in Content.districts():
		assert_false(seen.has(district.id), "Duplicate district id %s" % district.id)
		seen[district.id] = true


func test_starting_district_exists() -> void:
	assert_not_null(Content.district(RunState.STARTING_DISTRICT))


func test_districts_are_fully_configured() -> void:
	for district in Content.districts():
		var label := String(district.id)
		assert_false(district.display_name.is_empty(), label)
		assert_not_null(district.background, label)
		assert_not_null(district.ambient_effect, label)
		assert_gt(district.travel_cost, 0, label)
		assert_false(district.venues.is_empty(), label)


func test_map_positions_are_inside_the_map() -> void:
	for district in Content.districts():
		var position := district.map_position
		assert_between(position.x, 0.0, 1.0, String(district.id))
		assert_between(position.y, 0.0, 1.0, String(district.id))


func test_every_listed_venue_exists() -> void:
	for district in Content.districts():
		for venue_id in district.venues:
			assert_not_null(Content.venue(venue_id), "%s lists %s" % [district.id, venue_id])


func test_roads_run_both_ways() -> void:
	for district in Content.districts():
		for road_id in district.roads:
			var other := Content.district(road_id)
			assert_not_null(other, "%s road to %s" % [district.id, road_id])
			if other != null:
				assert_true(other.roads.has(district.id), "%s to %s has no road back" % [district.id, road_id])


func test_pins_sit_on_the_map() -> void:
	for district in Content.districts():
		assert_between(district.map_position.x, 0.05, 0.95, String(district.id))
		assert_between(district.map_position.y, 0.15, 0.88, String(district.id))
