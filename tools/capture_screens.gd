extends SceneTree

const OUTPUT_DIR := "/tmp/blackmarket_shots"
const WATCHDOG_SECONDS := 240.0

var _game_state: Node
var _router: Node
var _content: Node


func _initialize() -> void:
	create_timer(WATCHDOG_SECONDS).timeout.connect(quit.bind(1))
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	_game_state = root.get_node("GameState")
	_router = root.get_node("SceneRouter")
	_content = root.get_node("Content")

	await _open(_router.TITLE_SCREEN, "01_title")

	_game_state.start_new_run()
	_game_state.has_unseen_new_day = false
	await _open(_router.DISTRICT_SCREEN, "02_district")
	current_scene.get_node("%BagButton").pressed.emit()
	await _wait(0.8)
	await _capture("03_bag_empty")

	await _open(_router.MARKET_SCREEN, "04_market_buy")
	var phones: Resource = _content.item(&"burner_phones")
	var dealer: Resource = _content.dealer_in(&"old_market")
	PriceIntel.record(_game_state.run, _content.dealer(&"ernesto"), _content.items(0))
	current_scene.get_node("%TradeSheet").show_trade(0, phones, dealer)
	await _wait(0.8)
	await _capture("05_trade_sheet")
	current_scene.get_node("%TradeSheet").get_node("%HaggleButton").pressed.emit()
	await _wait(0.5)
	await _capture("06_haggle")
	current_scene.get_node("%TradeSheet").close()
	await _wait(0.5)

	_game_state.buy(phones, 8, 95)
	_game_state.buy(_content.item(&"fake_ids"), 3, 170)
	current_scene.get_node("%SellTab").pressed.emit()
	await _wait(0.6)
	await _capture("07_market_sell")
	current_scene.get_node("%GearTab").pressed.emit()
	await _wait(0.6)
	await _capture("08_market_gear")

	current_scene.get_node("%DealFlash").play(1840, true)
	await _wait(0.8)
	await _capture("26_deal_handshake")
	await _wait(2.0)
	current_scene.get_node("%DealFlash").play(-190, false)
	await _wait(0.5)
	await _capture("27_deal_small")
	await _wait(1.5)

	_game_state.buy_gear(_content.item(&"messenger_bag"))
	current_scene.get_node("%BagButton").pressed.emit()
	await _wait(0.8)
	await _capture("09_bag_full")

	_game_state.dealer_walked_out(dealer)
	current_scene.get_node("%InventorySheet").close()
	await _wait(0.6)
	await _capture("10_dealer_walked")

	await _capture_phase_four(dealer)
	await _capture_roster()
	await _capture_bar()

	_router.go_to(_router.TITLE_SCREEN)
	await _wait(0.18)
	await _capture("28_shutter")
	await _wait(1.0)
	quit()


func _capture_roster() -> void:
	_game_state.start_new_run()
	_game_state.has_unseen_new_day = false
	var run: RunState = _game_state.run
	var busiest := 0
	var busiest_count := -1
	for stamp in 120:
		var count := Roster.dealers_at(run, &"old_market", stamp).size() + Roster.characters_at(run, &"old_market", stamp).size()
		if count > busiest_count and Roster.dealers_at(run, &"old_market", stamp).size() > 1:
			busiest = stamp
			busiest_count = count
	run.day = busiest / RunState.Phase.size() + 1
	run.phase = (busiest % RunState.Phase.size()) as RunState.Phase
	await _open(_router.DISTRICT_SCREEN, "20_district_crowd")

	var overlay: Node = root.get_node("GameOverlay")
	var dialogue: Node = overlay.get_child(1)
	StreetTalk.talk_to(_content.character(&"rival"))
	await _wait(2.4)
	await _capture("21_street_talk")
	overlay.end_talk()
	await _wait(0.4)

	StreetTalk.talk_to(_content.character(&"informant"))
	await _wait(2.2)
	await _capture("23_weasel_offer")
	dialogue.get_node("%ChoiceList").get_child(0).pressed.emit()
	await _wait(3.0)
	await _capture("24_weasel_tip")
	overlay.end_talk()
	await _wait(0.4)

	var visitors := Roster.dealers_at(run, &"old_market", busiest).filter(func(entry: DealerDef) -> bool: return not entry.is_resident())
	if not visitors.is_empty():
		_game_state.trading_with = visitors[0].id
		await _open(_router.MARKET_SCREEN, "22_market_traveller", 2.4)

	await _open(_router.CHARACTER_SELECT, "25_character_select", 2.6)


func _capture_bar() -> void:
	_game_state.start_new_run()
	_game_state.has_unseen_new_day = false
	var run: RunState = _game_state.run
	var overlay: Node = root.get_node("GameOverlay")
	var dialogue: Node = overlay.get_child(1)

	_game_state.visiting_venue = &"tran_bar"
	await _open(_router.BAR_SCREEN, "29_bar", 2.6)
	current_scene.get_node("%List").get_child(1).pressed.emit()
	await _wait(2.6)
	await _capture("30_bar_order")
	dialogue.get_node("%ChoiceList").get_child(0).pressed.emit()
	await _wait(1.2)
	overlay.end_talk()
	await _wait(0.4)
	current_scene.get_node("%RumorButton").pressed.emit()
	await _wait(3.4)
	await _capture("31_bar_rumor")

	var order: Dictionary = run.orders[0]
	Inventory.add_units(run, StringName(order.item), int(order.quantity))
	_game_state.trading_with = StringName(order.dealer)
	run.district_id = _content.dealer(StringName(order.dealer)).district_id
	await _open(_router.MARKET_SCREEN, "32_market_order", 2.4)

	var missed: Array[Dictionary] = [order]
	_game_state.orders_missed.emit(missed)
	await _wait(2.6)
	await _capture("33_order_missed")
	overlay.end_talk()
	await _wait(0.4)


func _capture_phase_four(dealer: Resource) -> void:
	var run: RunState = _game_state.run
	var overlay: Node = root.get_node("GameOverlay")
	var dialogue: Node = overlay.get_child(1)

	run.walked_out.clear()
	await _open(_router.DISTRICT_SCREEN, "11_district_heat")
	run.pending_encounter = Encounters.police_stop(run)
	await _wait(2.4)
	await _capture("12_police_stop")
	dialogue.get_node("%ChoiceList").get_child(2).pressed.emit()
	await _wait(1.4)
	await _capture("13_police_result")
	dialogue.get_node("%ChoiceList").get_child(0).pressed.emit()
	await _wait(0.6)

	run.market_shifts.append({ "district": "old_market", "category": "comms", "multiplier": 1.6, "from": Calendar.stamp(run), "until": Calendar.stamp(run) + 3 })
	run.pending_encounter = StreetEvents.prepare(run, _event(&"shipment_seized"), RandomNumberGenerator.new())
	_game_state.run_changed.emit()
	await _wait(2.6)
	await _capture("14_event_card")
	dialogue.get_node("%ChoiceList").get_child(0).pressed.emit()
	await _wait(0.6)

	run.pending_encounter = Encounters.raid(run)
	await _wait(2.6)
	await _capture("14b_raid")
	dialogue.get_node("%ChoiceList").get_child(0).pressed.emit()
	await _wait(0.6)

	await _open(_router.MARKET_SCREEN, "15_market_news")

	run.district_id = &"downtown"
	await _open(_router.DISTRICT_SCREEN, "16_downtown")
	overlay.open_loan()
	await _wait(0.8)
	await _capture("17_loan_sheet")
	overlay.get_child(0).close()
	await _wait(0.4)
	StreetTalk.talk_to(_content.character(&"shark"))
	await _wait(2.4)
	await _capture("17b_shark_talk")
	overlay.end_talk()
	await _wait(0.4)

	run.debt = 0
	Campaign.update_outcome(run)
	run.trades = 14
	run.profit = 6200
	await _open(_router.END_SCREEN, "18_end_won", 2.2)

	_game_state.start_new_run()
	_game_state.run.day = RunState.CAMPAIGN_DAYS + 1
	Campaign.update_outcome(_game_state.run)
	await _open(_router.END_SCREEN, "19_end_lost", 2.2)


func _event(id: StringName) -> EventDef:
	for event: EventDef in _content.events():
		if event.id == id:
			return event
	return null


func _open(scene_path: String, shot_name: String, settle_seconds: float = 1.5) -> void:
	change_scene_to_file(scene_path)
	await _wait(settle_seconds)
	await _capture(shot_name)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _capture(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("%s/%s.png" % [OUTPUT_DIR, shot_name])
	image.resize(360, 640, Image.INTERPOLATE_BILINEAR)
	image.save_jpg("%s/%s.jpg" % [OUTPUT_DIR, shot_name], 0.8)
	print("CAPTURED ", shot_name)
