class_name VenueSheet
extends BottomSheet

@onready var _name_label: Label = %NameLabel
@onready var _tagline_label: Label = %TaglineLabel
@onready var _status_label: Label = %StatusLabel
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
	super()
	_close_button.pressed.connect(close)


func show_venue(venue: VenueDef) -> void:
	_name_label.text = venue.display_name
	_tagline_label.text = venue.tagline
	_status_label.text = "Open" if venue.available else "Coming soon"
	open_sheet()
