class_name PersonChip
extends GameButton

## Portraits are chest-up, so the chip shows a square from the top of the image where the face sits.
const FACE_TOP := 0.04
const FACE_WIDTH := 0.8

@onready var _portrait: TextureRect = %Portrait
@onready var _name_label: Label = %NameLabel
@onready var _role_label: Label = %RoleLabel


func display(portrait: Texture2D, display_name: String, role: String, role_color: Color) -> void:
	_portrait.texture = _face_of(portrait)
	_name_label.text = display_name
	_role_label.text = role
	_role_label.add_theme_color_override("font_color", role_color)


func _face_of(portrait: Texture2D) -> Texture2D:
	if portrait == null:
		return null
	var size := portrait.get_size()
	var side := size.x * FACE_WIDTH
	var face := AtlasTexture.new()
	face.atlas = portrait
	face.region = Rect2((size.x - side) / 2.0, size.y * FACE_TOP, side, side)
	return face
