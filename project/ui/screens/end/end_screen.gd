extends Control

@onready var _margin: MarginContainer = %Margin
@onready var _story: Control = %Story
@onready var _stats_card: Control = %StatsCard
@onready var _actions: Control = %Actions
@onready var _day_label: Label = %DayLabel
@onready var _headline_label: Label = %HeadlineLabel
@onready var _summary_label: Label = %SummaryLabel
@onready var _net_worth_value: Label = %NetWorthValue
@onready var _profit_value: Label = %ProfitValue
@onready var _trades_value: Label = %TradesValue
@onready var _busts_value: Label = %BustsValue
@onready var _primary_button: Button = %PrimaryButton
@onready var _menu_button: Button = %MenuButton

var _won := false


func _ready() -> void:
	var run := GameState.run
	if run == null or not Campaign.is_over(run):
		SceneRouter.go_to.call_deferred(SceneRouter.TITLE_SCREEN)
		return

	SafeArea.apply_top_margin(_margin, 40)
	_won = run.outcome == RunState.Outcome.WON
	_day_label.text = "DAY %d" % run.day
	_net_worth_value.text = Format.money(Campaign.net_worth(run))
	_profit_value.text = Format.money(run.profit)
	_profit_value.add_theme_color_override("font_color", Palette.RISK_LOW if run.profit >= 0 else Palette.RISK_HIGH)
	_trades_value.text = str(run.trades)
	_busts_value.text = str(run.busts)

	if _won:
		var days_spare := run.campaign_days - run.day
		_headline_label.text = "DEBT CLEARED"
		_summary_label.text = "You paid off the shark with %d days to spare. The streets are yours." % days_spare if days_spare > 0 else "You paid off the shark on the final day. The streets are yours."
		_primary_button.text = "Keep playing"
	else:
		_headline_label.text = "THE SHARK TAKES EVERYTHING"
		_summary_label.text = "Day %d came and went with %s still owed. His men took the cash, the goods and the stash." % [run.campaign_days, Format.money(run.debt)]
		_primary_button.text = "New game"
		GameState.delete_run()

	_primary_button.pressed.connect(_on_primary_pressed)
	_menu_button.pressed.connect(SceneRouter.go_to.bind(SceneRouter.TITLE_SCREEN))
	_play_entrance()


func handle_back() -> bool:
	SceneRouter.go_to(SceneRouter.TITLE_SCREEN)
	return true


func _on_primary_pressed() -> void:
	if _won:
		GameState.continue_endless()
		SceneRouter.go_to(SceneRouter.DISTRICT_SCREEN)
	else:
		SceneRouter.go_to(SceneRouter.CHARACTER_SELECT)


func _play_entrance() -> void:
	var sections: Array[Control] = [_story, _stats_card, _actions]
	for section in sections:
		section.modulate.a = 0.0
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for index in sections.size():
		tween.tween_property(sections[index], "modulate:a", 1.0, 0.6).set_delay(0.2 + index * 0.3)
