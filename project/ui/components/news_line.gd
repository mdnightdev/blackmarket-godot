class_name NewsLine
extends Label

## Shows the street-event price shifts currently active in one district. Hidden when there are none.
func show_for(district_id: StringName) -> void:
	var headlines: Array[String] = []
	for shift in StreetEvents.active_shifts(GameState.run, district_id):
		headlines.append(StreetEvents.headline(shift))
	text = "NEWS: %s" % ". ".join(headlines) if not headlines.is_empty() else ""
	visible = not headlines.is_empty()
