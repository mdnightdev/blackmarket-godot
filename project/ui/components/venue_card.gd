class_name VenueCard
extends GameButton

signal venue_selected(venue: VenueDef)

var venue: VenueDef

@onready var _name_label: Label = %NameLabel
@onready var _tagline_label: Label = %TaglineLabel
@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	super()
	_name_label.text = venue.display_name
	_tagline_label.text = venue.tagline
	_status_label.visible = not venue.available
	pressed.connect(func() -> void: venue_selected.emit(venue))
