class_name TradeSheet
extends BottomSheet

## A TradeForm sliding up from the bottom, for screens that list items without room to open one in place.

signal completed(message: String, cash_delta: int)
signal dealer_said(line: String)

@onready var _form: TradeForm = %TradeForm


func _ready() -> void:
	super()
	_form.completed.connect(_on_completed)
	_form.dealer_said.connect(dealer_said.emit)
	_form.close_requested.connect(close)


func show_trade(mode: TradeForm.Mode, item: ItemDef, dealer: DealerDef) -> void:
	_form.show_trade(mode, item, dealer)
	open_sheet()


func _on_completed(message: String, cash_delta: int) -> void:
	completed.emit(message, cash_delta)
	close()
