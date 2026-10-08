class_name DistrictSheet
extends BottomSheet

signal travel_requested(district: DistrictDef, walking: bool)
signal enter_requested

@onready var _preview: TextureRect = %Preview
@onready var _name_label: Label = %NameLabel
@onready var _tagline_label: Label = %TaglineLabel
@onready var _description_label: Label = %DescriptionLabel
@onready var _fare_value: Label = %FareValue
@onready var _travel_button: Button = %TravelButton

var _district: DistrictDef
var _is_here := false
var _walking := false


func _ready() -> void:
	super()
	_travel_button.pressed.connect(_on_travel_pressed)


func _on_travel_pressed() -> void:
	if _is_here:
		enter_requested.emit()
	else:
		travel_requested.emit(_district, _walking)


func show_district(district: DistrictDef, travel_check: Travel.Check) -> void:
	_district = district
	_preview.texture = district.background
	_name_label.text = district.display_name
	_tagline_label.text = district.tagline
	_description_label.text = district.description
	_fare_value.text = Format.money(Travel.fare(GameState.run, district))
	_is_here = travel_check == Travel.Check.ALREADY_HERE
	_walking = travel_check == Travel.Check.NOT_ENOUGH_CASH
	match travel_check:
		Travel.Check.OK:
			_travel_button.text = "Travel"
		Travel.Check.ALREADY_HERE:
			_travel_button.text = "Enter"
		Travel.Check.NOT_ENOUGH_CASH:
			_travel_button.text = "Walk there. Free, but slow"
		Travel.Check.LOCKED:
			_travel_button.text = Travel.lock_reason(GameState.run, district)
	_travel_button.disabled = travel_check == Travel.Check.LOCKED
	open_sheet()
