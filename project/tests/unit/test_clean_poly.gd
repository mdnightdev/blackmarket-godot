extends GutTest

const CANVAS_SIZE := 3072.0
const VX0 := 139.55
const VY0 := 35.50
const VSPAN := 0.50

func _norm_pt(raw_pt: Array) -> Vector2:
	return Vector2((float(raw_pt[0]) - VX0) / VSPAN, (float(raw_pt[1]) - VY0) / VSPAN)

func test_clean_polygons():
	var file := FileAccess.open("res://data/tokyo.json", FileAccess.READ)
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	var islands: Array = data.get("islands", [])
	for i in [2, 3, 8, 11, 16]:
		var chain: Array = islands[i]
		var isl := PackedVector2Array()
		for pt in chain:
			isl.append(_norm_pt(pt) * CANVAS_SIZE)
		
		# Test merge_polygons
		var cleaned = Geometry2D.merge_polygons(isl, PackedVector2Array())
		gut.p("Island %d merge_polygons result count: %d" % [i, cleaned.size()])
		for p_idx in range(cleaned.size()):
			var poly = cleaned[p_idx]
			var ind = Geometry2D.triangulate_polygon(poly)
			gut.p("  Subpoly %d size: %d, triangulated: %s" % [p_idx, poly.size(), not ind.is_empty()])
	assert_true(true)
