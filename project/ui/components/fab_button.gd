class_name FabButton
extends GameButton

@export var icon_texture: Texture2D
@export var caption := ""

@onready var _icon: TextureRect = %Icon
@onready var _caption: Label = %Caption


func _ready() -> void:
	super()
	_icon.texture = icon_texture
	_caption.text = caption
	_caption.visible = not caption.is_empty()
