class_name BottomSheet
extends Control

const OPEN_SECONDS := 0.28
const CLOSE_SECONDS := 0.2

@onready var _dim: ColorRect = %Dim
@onready var _sheet: PanelContainer = %Sheet

var _tween: Tween


func _ready() -> void:
	hide()
	_dim.gui_input.connect(_on_dim_input)


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
