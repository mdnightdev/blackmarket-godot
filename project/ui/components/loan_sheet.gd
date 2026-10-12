class_name LoanSheet
extends BottomSheet

enum Mode { REPAY, BORROW }

var _mode := Mode.REPAY
var _amount := 0

@onready var _section_label: Label = %Section
@onready var _debt_value: Label = %DebtValue
@onready var _interest_caption: Label = %InterestCaption
@onready var _interest_value: Label = %InterestValue
@onready var _due_value: Label = %DueValue
@onready var _owed_value: Label = %OwedValue
@onready var _note_label: Label = %NoteLabel
@onready var _action_box: Control = %ActionBox
@onready var _tabs: Control = %Tabs
@onready var _repay_tab: Button = %RepayTab
@onready var _borrow_tab: Button = %BorrowTab
@onready var _amount_label: Label = %AmountLabel
@onready var _due_button: Button = %DueButton
@onready var _max_button: Button = %MaxButton
@onready var _amount_slider: HSlider = %AmountSlider
@onready var _confirm_button: Button = %ConfirmButton


func _ready() -> void:
	super()
	var tabs := ButtonGroup.new()
	_repay_tab.button_group = tabs
	_borrow_tab.button_group = tabs
	_repay_tab.pressed.connect(_select_mode.bind(Mode.REPAY))
	_borrow_tab.pressed.connect(_select_mode.bind(Mode.BORROW))
	_due_button.pressed.connect(func() -> void: _set_amount(Loan.amount_due(GameState.run)))
	_max_button.pressed.connect(func() -> void: _set_amount(_max_amount()))
	_amount_slider.value_changed.connect(func(value: float) -> void: _set_amount(int(value)))
	_confirm_button.pressed.connect(_confirm)
	GameState.run_changed.connect(_on_run_changed)


## Repayments work anywhere. Borrowing only happens at The Shark, once the career has started.
func open_loan(mode := Mode.REPAY) -> void:
	if GameState.run == null:
		return
	_mode = mode if GameState.run.career else Mode.REPAY
	(_repay_tab if _mode == Mode.REPAY else _borrow_tab).button_pressed = true
	_amount = _default_amount()
	_refresh()
	open_sheet()


func _on_run_changed() -> void:
	if visible and GameState.run != null:
		_refresh()


func _select_mode(mode: Mode) -> void:
	_mode = mode
	_amount = _default_amount()
	_refresh()


func _refresh() -> void:
	var run := GameState.run
	_section_label.text = "VEX" if Loan.is_with_vex(run) else "THE SHARK"
	_debt_value.text = Format.money(run.debt)
	if run.career:
		_interest_caption.text = "INTEREST / DAY"
		_interest_value.text = "+%s" % Format.money(Loan.daily_interest(run))
	elif Loan.is_with_vex(run):
		_interest_caption.text = "MISSED"
		_interest_value.text = "%d in a row" % run.missed_weeks
	else:
		_interest_caption.text = "TRUST"
		_interest_value.text = SharkTrust.level_name(run)
	_due_value.text = "Day %d" % (run.next_due_day - 1)
	_owed_value.text = Format.money(Loan.amount_due(run))
	_note_label.text = _note(run)
	_tabs.visible = run.career
	_action_box.visible = _mode == Mode.REPAY or Loan.can_borrow(run)
	if _action_box.visible:
		_refresh_amount()


func _note(run: RunState) -> String:
	var lines: Array[String] = []
	var vex := Loan.is_with_vex(run)
	if run.debt <= 0:
		lines.append("You owe %s nothing." % ("Vex" if vex else "the Shark"))
	elif Loan.amount_due(run) > 0:
		var collectors := "her crew comes" if vex else "his men come"
		lines.append("Pay %s by the end of day %d or %s to collect. A missed week adds %d%% to the debt." % [
			Format.money(Loan.amount_due(run)), run.next_due_day - 1, collectors, roundi(Loan.MISSED_WEEK_INTEREST * 100),
		])
	else:
		lines.append("This week is covered. The next payment is set on day %d." % (run.next_due_day - 1))
	if run.debt > 0 and not run.career and not vex and run.outcome == RunState.Outcome.ONGOING:
		var streak := " Missed %d in a row so far." % run.missed_weeks if run.missed_weeks > 0 else ""
		lines.append("Miss %d payments in a row, or lose his trust, and he sells your debt.%s" % [Loan.MAX_MISSED_WEEKS, streak])
	if _mode == Mode.BORROW and not Loan.can_visit(run):
		lines.append("Borrow at The Shark in Downtown.")
	return "\n".join(lines)


func _max_amount() -> int:
	return Loan.max_repay(GameState.run) if _mode == Mode.REPAY else Loan.max_borrow(GameState.run)


func _default_amount() -> int:
	if _mode == Mode.BORROW:
		return mini(1000, _max_amount())
	var due := Loan.amount_due(GameState.run)
	return mini(due if due > 0 else _max_amount(), _max_amount())


func _refresh_amount() -> void:
	var limit := _max_amount()
	_amount_slider.max_value = maxi(1, limit)
	_amount_slider.editable = limit > 1
	_due_button.visible = _mode == Mode.REPAY
	_set_amount(_amount)


func _set_amount(value: int) -> void:
	var limit := _max_amount()
	_amount = clampi(value, mini(1, limit), limit)
	_amount_slider.set_value_no_signal(_amount)
	_amount_label.text = Format.money(_amount)
	_max_button.disabled = _amount >= limit
	_due_button.disabled = Loan.amount_due(GameState.run) <= 0 or Loan.amount_due(GameState.run) > limit
	_confirm_button.disabled = _amount <= 0
	_confirm_button.text = _confirm_text(limit)


func _confirm_text(limit: int) -> String:
	if _mode == Mode.BORROW:
		return "Borrow %s" % Format.money(_amount) if limit > 0 else "He will not lend more"
	if GameState.run.debt <= 0:
		return "Nothing to repay"
	return "Repay %s" % Format.money(_amount) if limit > 0 else "No cash to repay"


func _confirm() -> void:
	var done := GameState.repay_debt(_amount) if _mode == Mode.REPAY else GameState.borrow(_amount)
	if done:
		_amount = _default_amount()
		_refresh()
