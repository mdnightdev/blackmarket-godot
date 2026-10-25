class_name CornerPin
extends GameButton

## A street corner on a district's corner map. The marker takes the holder's color and the faces of whoever works the
## corner this phase sit under its name.

const MARKER_CENTER := Vector2(100, 22)
const MAX_FACES := 4
const FACE_SIZE := Vector2(40, 40)

@export var face_frame: StyleBox

var corner: CornerDef
var holder_color := Palette.TEXT_MUTED
var people: Array[SpeakerDef] = []

@onready var _marker: Panel = %Marker
@onready var _name_label: Label = %NameLabel
@onready var _faces: HBoxContainer = %Faces


func _ready() -> void:
	super()
	_name_label.text = corner.display_name
	var style: StyleBoxFlat = _marker.get_theme_stylebox("panel").duplicate()
	style.bg_color = holder_color
	_marker.add_theme_stylebox_override("panel", style)
	for person in people.slice(0, MAX_FACES):
		_faces.add_child(_face(person.portrait))
	if people.size() > MAX_FACES:
		var more := Label.new()
		more.theme_type_variation = &"PinLabel"
		more.text = "+%d" % (people.size() - MAX_FACES)
		_faces.add_child(more)
	if GameState.run != null and corner != null and Corners.holds(GameState.run, corner.id):
		_add_garrison_bar(GameState.run)


func _add_garrison_bar(run: RunState) -> void:
	var posted := Corners.garrison(run, corner.id)
	var cap := Corners.CORNER_GARRISON_CAP
	var ratio := clampf(float(posted) / float(cap), 0.08, 1.0) if posted > 0 else 0.0
	var track := ColorRect.new()
	track.custom_minimum_size = Vector2(96.0, 5.0)
	track.color = Color(0.08, 0.09, 0.12, 0.85)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := ColorRect.new()
	fill.color = Palette.RISK_LOW if posted > 0 else TurfBar.PLAYER_COLOR
	fill.size = Vector2(96.0 * ratio, 5.0)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(fill)
	_name_label.get_parent().add_child(track)


func place_at(map_point: Vector2) -> void:
	position = map_point - MARKER_CENTER


func _face(portrait: Texture2D) -> Control:
	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", face_frame)
	var face := TextureRect.new()
	face.custom_minimum_size = FACE_SIZE
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	face.texture = PersonChip.face_of(portrait)
	frame.add_child(face)
	return frame
