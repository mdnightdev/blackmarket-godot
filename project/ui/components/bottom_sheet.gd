class_name BottomSheet
extends Control

const OPEN_SECONDS := 0.28
const CLOSE_SECONDS := 0.2
const SWIPE_CLOSE_DISTANCE := 120.0

@onready var _dim: ColorRect = %Dim
@onready var _sheet: PanelContainer = %Sheet

var _tween: Tween
var _swipe_start := Vector2.ZERO
var _swiping := false


func _ready() -> void:
	hide()
	_dim.gui_input.connect(_on_dim_input)
	_sheet.gui_input.connect(_on_sheet_input)


## The sheet height depends on its new content, so it is measured one frame after showing.
func open_sheet() -> void:
	_sheet.modulate.a = 0.0
	_dim.modulate.a = 0.0
	show()
	await get_tree().process_frame
	var rest_y := size.y - _sheet.size.y
	_sheet.position.y = size.y
	_sheet.modulate.a = 1.0
	_animate(rest_y, 1.0, OPEN_SECONDS, Tween.EASE_OUT)


func close() -> void:
	if not visible:
		return
	_animate(size.y, 0.0, CLOSE_SECONDS, Tween.EASE_IN).chain().tween_callback(hide)


func _animate(sheet_y: float, dim_alpha: float, duration: float, easing: Tween.EaseType) -> Tween:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(easing)
	_tween.tween_property(_sheet, "position:y", sheet_y, duration)
	_tween.tween_property(_dim, "modulate:a", dim_alpha, duration)
	return _tween


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()


## A mostly vertical drag downwards on the sheet itself closes it. Scroll lists and buttons keep their own drags.
func _on_sheet_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_swiping = event.pressed
		_swipe_start = event.position
	elif event is InputEventMouseMotion and _swiping:
		var travel: Vector2 = event.position - _swipe_start
		if travel.y > SWIPE_CLOSE_DISTANCE and travel.y > absf(travel.x) * 2.0:
			_swiping = false
			close()
