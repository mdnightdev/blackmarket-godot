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


func _ready() -> void:
	var run := GameState.run
	if run == null or not Campaign.is_over(run):
		SceneRouter.go_to.call_deferred(SceneRouter.TITLE_SCREEN)
		return

	SafeArea.apply_top_margin(_margin, 40)
	_day_label.text = "DAY %d" % run.day
	_net_worth_value.text = Format.money(Campaign.net_worth(run))
	_profit_value.text = Format.money(run.profit)
	_profit_value.add_theme_color_override("font_color", Palette.RISK_LOW if run.profit >= 0 else Palette.RISK_HIGH)
	_trades_value.text = str(run.trades)
	_busts_value.text = str(run.busts)

	_headline_label.text = "THE SHARK TAKES EVERYTHING"
	_summary_label.text = "You missed %d payments in a row with %s still owed. The Shark stopped waiting. His men took the cash, the goods and the stash." % [Loan.MAX_MISSED_WEEKS, Format.money(run.debt)]
	_primary_button.text = "New game"
	GameState.delete_run()

	_primary_button.pressed.connect(SceneRouter.go_to.bind(SceneRouter.CHARACTER_SELECT))
	_menu_button.pressed.connect(SceneRouter.go_to.bind(SceneRouter.TITLE_SCREEN))
	_play_entrance()


func handle_back() -> bool:
	SceneRouter.go_to(SceneRouter.TITLE_SCREEN)
	return true


func _play_entrance() -> void:
	var sections: Array[Control] = [_story, _stats_card, _actions]
	for section in sections:
		section.modulate.a = 0.0
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for index in sections.size():
		tween.tween_property(sections[index], "modulate:a", 1.0, 0.6).set_delay(0.2 + index * 0.3)
