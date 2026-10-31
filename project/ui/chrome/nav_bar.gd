class_name NavBar
extends PanelContainer

@onready var _turf_tab: NavTab = %TurfTab
@onready var _market_tab: NavTab = %MarketTab
@onready var _bag_tab: NavTab = %BagTab
@onready var _jobs_tab: NavTab = %JobsTab
@onready var _menu_tab: NavTab = %MenuTab


func _ready() -> void:
	_turf_tab.set_icon(ItemsAtlas.get_icon(&"nav_turf"))
	_market_tab.set_icon(ItemsAtlas.get_icon(&"nav_market"))
	_bag_tab.set_icon(ItemsAtlas.get_icon(&"nav_bag"))
	_jobs_tab.set_icon(ItemsAtlas.get_icon(&"nav_jobs"))
	_menu_tab.set_icon(ItemsAtlas.get_icon(&"nav_menu"))
	_turf_tab.pressed.connect(GameOverlay.open_turf)
	_market_tab.pressed.connect(_open_market)
	_bag_tab.pressed.connect(GameOverlay.open_bag)
	_jobs_tab.pressed.connect(GameOverlay.open_jobs)
	_menu_tab.pressed.connect(GameOverlay.open_profile)
	GameState.run_changed.connect(_refresh_tabs)
	Settings.changed.connect(_refresh_tabs)
	visibility_changed.connect(_refresh_tabs)
	_apply_safe_area()
	get_tree().root.size_changed.connect(_apply_safe_area)
	_refresh_tabs()


func _apply_safe_area() -> void:
	SafeArea.apply_bottom_margin(self, 10)


func _refresh_tabs() -> void:
	var run := GameState.run
	_turf_tab.set_enabled(run != null)
	_market_tab.set_enabled(run != null and Content.dealer_in(run.district_id) != null)
	_jobs_tab.set_badge(run != null and (not Jobs.due_soon(run).is_empty() or _offers_waiting_silently(run)))


## With Do not disturb on, the badge is the only sign that offers came in.
func _offers_waiting_silently(run: RunState) -> bool:
	if not Settings.do_not_disturb:
		return false
	return not (run.errand_offers.is_empty() and run.customer_offers.is_empty() and run.job_pings.is_empty())


func _open_market() -> void:
	GameState.trading_with = &""
	SceneRouter.go_to(SceneRouter.MARKET_SCREEN)
