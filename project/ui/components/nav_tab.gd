class_name NavTab
extends GameButton

const DISABLED_ALPHA := 0.35

@export var icon_texture: Texture2D
@export var caption := ""

@onready var _content: Control = %Content
@onready var _icon: TextureRect = %Icon
@onready var _caption: Label = %Caption
@onready var _badge: Control = %Badge


func _ready() -> void:
	super()
	_icon.texture = icon_texture
	_caption.text = caption
	set_enabled(not disabled)


func set_enabled(enabled: bool) -> void:
	disabled = not enabled
	_content.modulate.a = 1.0 if enabled else DISABLED_ALPHA


func set_badge(shown: bool) -> void:
	_badge.visible = shown
