class_name NavBar
extends PanelContainer

@onready var _turf_tab: NavTab = %TurfTab
@onready var _market_tab: NavTab = %MarketTab
@onready var _bag_tab: NavTab = %BagTab
@onready var _jobs_tab: NavTab = %JobsTab
@onready var _menu_tab: NavTab = %MenuTab


func _ready() -> void:
	_turf_tab.pressed.connect(GameOverlay.open_turf)
	_market_tab.pressed.connect(_open_market)
	_bag_tab.pressed.connect(GameOverlay.open_bag)
	_jobs_tab.pressed.connect(GameOverlay.open_jobs)
	_menu_tab.pressed.connect(GameOverlay.open_profile)
	GameState.run_changed.connect(_refresh_tabs)
	visibility_changed.connect(_refresh_tabs)
	_refresh_tabs()


func _refresh_tabs() -> void:
	var run := GameState.run
	_turf_tab.set_enabled(run != null)
	_market_tab.set_enabled(run != null and Content.dealer_in(run.district_id) != null)
	_jobs_tab.set_badge(run != null and not Jobs.due_soon(run).is_empty())


func _open_market() -> void:
	GameState.trading_with = &""
	SceneRouter.go_to(SceneRouter.MARKET_SCREEN)
