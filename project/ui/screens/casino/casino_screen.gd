extends Control

enum Game { SIC_BO, BLACKJACK, SLOTS }

const GREETING_DELAY := 0.35
const DICE_ROLL_SECONDS := 0.8
const DICE_TICK_SECONDS := 0.07
const CARD_DELAY_SECONDS := 0.4
const REEL_SECONDS: Array[float] = [0.8, 1.15, 1.5]
const CARDS_BEFORE_OVERLAP := 5
const CARD_GAP := 10
const CARD_OVERLAP := -36
const PAYTABLE_ICON_SIZE := Vector2(52, 52)
const RULES := {
	Game.SIC_BO: "Three dice. Small is 4 to 10, Big is 11 to 17. Pays 1 to 1, any triple loses.",
	Game.BLACKJACK: "Blackjack pays 3 to 2. Dealer stands on 17. Double down on your first two cards.",
	Game.SLOTS: "Three alike pays the multiple shown. Pairs of SIMs, keys or drives pay 1x, 2x and 3x.",
}

@onready var _background: TextureRect = %Background
@onready var _margin: MarginContainer = %Margin
@onready var _portrait: TalkingPortrait = %Portrait
@onready var _venue_label: Label = %VenueLabel
@onready var _host_label: Label = %HostLabel
@onready var _speech: Typewriter = %Speech
@onready var _sic_bo_tab: Button = %SicBoTab
@onready var _blackjack_tab: Button = %BlackjackTab
@onready var _slots_tab: Button = %SlotsTab
@onready var _table: Control = %Table
@onready var _rules_label: Label = %RulesLabel
@onready var _dealer_label: Label = %DealerLabel
@onready var _dealer_hand: HBoxContainer = %DealerHand
@onready var _dice_row: HBoxContainer = %Dice
@onready var _reel_row: HBoxContainer = %Reels
@onready var _paytable: HBoxContainer = %Paytable
@onready var _player_hand: HBoxContainer = %PlayerHand
@onready var _player_label: Label = %PlayerLabel
@onready var _result_label: Label = %ResultLabel
@onready var _less_button: Button = %LessButton
@onready var _more_button: Button = %MoreButton
@onready var _bet_label: Label = %BetLabel
@onready var _bet_hint: Label = %BetHint
@onready var _small_button: Button = %SmallButton
@onready var _big_button: Button = %BigButton
@onready var _deal_button: Button = %DealButton
@onready var _hit_button: Button = %HitButton
@onready var _stand_button: Button = %StandButton
@onready var _double_button: Button = %DoubleButton
@onready var _spin_button: Button = %SpinButton
@onready var _back_button: Button = %BackButton

var _casino: CasinoDef
var _host: CharacterDef
var _game := Game.SIC_BO
var _bet_levels: Array[int] = []
var _bet_index := 0
## True while dice, cards or reels are animating.
var _busy := false
var _in_hand := false
var _stake := 0
## Winnings already decided but not yet paid, so leaving mid-animation still pays them.
var _pending_payout := 0
var _player: Array[int] = []
var _dealer: Array[int] = []
var _dice: Array[DieFace] = []
var _reels: Array[SlotReel] = []


func _ready() -> void:
	var district: DistrictDef = GameState.current_district() if GameState.run != null else null
	_casino = Content.venue(GameState.visiting_venue) as CasinoDef
	_host = Content.character(_casino.host) if _casino != null else null
	if district == null or _host == null or not district.venues.has(_casino.id):
		SceneRouter.go_to.call_deferred(SceneRouter.TITLE_SCREEN if district == null else SceneRouter.DISTRICT_SCREEN)
		return

	SafeArea.apply_top_margin(_margin, 40)
	_background.texture = _casino.background if _casino.background != null else district.background
	_venue_label.text = _casino.display_name.to_upper()
	_host_label.text = _host.display_name
	_portrait.show_speaker(_host)
	_speech.finished.connect(_portrait.set_talking.bind(false))
	_bet_levels = Casino.bet_levels(_casino)

	_build_dice()
	_build_reels()
	_build_paytable()
	_connect_buttons()
	GameState.run_changed.connect(_refresh_controls)

	_select_game(Game.SIC_BO)
	_play_entrance()
	get_tree().create_timer(GREETING_DELAY).timeout.connect(_host_says.bind(_host.line))


func _exit_tree() -> void:
	GameState.clock_active = false
	if _pending_payout > 0:
		GameState.collect_winnings(_pending_payout, _stake)
		_pending_payout = 0


func can_present_encounter() -> bool:
	return not _busy and not _in_hand


func handle_back() -> bool:
	if not _busy and not _in_hand:
		SceneRouter.go_to(SceneRouter.DISTRICT_SCREEN)
	return true


func _connect_buttons() -> void:
	var tabs := ButtonGroup.new()
	for tab_button in [_sic_bo_tab, _blackjack_tab, _slots_tab]:
		tab_button.button_group = tabs
	_sic_bo_tab.pressed.connect(_select_game.bind(Game.SIC_BO))
	_blackjack_tab.pressed.connect(_select_game.bind(Game.BLACKJACK))
	_slots_tab.pressed.connect(_select_game.bind(Game.SLOTS))
	_less_button.pressed.connect(_change_bet.bind(-1))
	_more_button.pressed.connect(_change_bet.bind(1))
	_small_button.pressed.connect(_play_sic_bo.bind(Casino.SicBoBet.SMALL))
	_big_button.pressed.connect(_play_sic_bo.bind(Casino.SicBoBet.BIG))
	_deal_button.pressed.connect(_deal)
	_hit_button.pressed.connect(_hit)
	_stand_button.pressed.connect(_finish_hand)
	_double_button.pressed.connect(_double_down)
	_spin_button.pressed.connect(_spin)
	_back_button.pressed.connect(SceneRouter.go_to.bind(SceneRouter.DISTRICT_SCREEN))


func _build_dice() -> void:
	for i in 3:
		var face := DieFace.new()
		face.value = i + 4
		_dice_row.add_child(face)
		_dice.append(face)


func _build_reels() -> void:
	var textures: Array[Texture2D] = []
	for item_id in Casino.SLOT_SYMBOLS:
		textures.append(Content.item(item_id).icon)
	for i in 3:
		var reel := SlotReel.new()
		reel.symbols = textures
		reel.symbol = textures.size() - 1 - i
		reel.stopped.connect(AudioService.play_sfx.bind(Sfx.REEL_STOP, 0.08))
		_reel_row.add_child(reel)
		_reels.append(reel)


func _build_paytable() -> void:
	for index in Casino.SLOT_SYMBOLS.size():
		var entry := VBoxContainer.new()
		entry.add_theme_constant_override("separation", 2)
		var icon := TextureRect.new()
		icon.texture = Content.item(Casino.SLOT_SYMBOLS[index]).icon
		icon.custom_minimum_size = PAYTABLE_ICON_SIZE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var multiple := Label.new()
		multiple.theme_type_variation = &"CaptionLabel"
		multiple.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		multiple.text = "x%d" % Casino.SLOT_THREE_PAYS[index]
		entry.add_child(icon)
		entry.add_child(multiple)
		_paytable.add_child(entry)


func _select_game(game: Game) -> void:
	_game = game
	[_sic_bo_tab, _blackjack_tab, _slots_tab][game].button_pressed = true
	_rules_label.text = RULES[game]
	_result_label.text = ""
	var cards := game == Game.BLACKJACK
	_dealer_label.visible = cards
	_dealer_hand.visible = cards
	_player_hand.visible = cards
	_player_label.visible = cards
	_dice_row.visible = game == Game.SIC_BO
	_reel_row.visible = game == Game.SLOTS
	_paytable.visible = game == Game.SLOTS
	if cards:
		_update_hand_labels()
	_refresh_controls()


func _refresh_controls() -> void:
	var run := GameState.run
	var locked := _busy or _in_hand
	GameState.clock_active = not locked
	for tab_button in [_sic_bo_tab, _blackjack_tab, _slots_tab]:
		tab_button.disabled = locked
	_back_button.disabled = locked

	var bet := _current_bet()
	var affordable := Casino.can_bet(run, _casino, bet)
	_bet_label.text = "BET %s" % Format.money(_stake if _in_hand else bet)
	_bet_label.add_theme_color_override("font_color", Palette.TEXT if affordable or locked else Palette.RISK_HIGH)
	if affordable or locked:
		_bet_hint.text = "TABLE %s TO %s" % [Format.money(_casino.min_bet), Format.money(_casino.max_bet)]
	else:
		_bet_hint.text = "NOT ENOUGH CASH FOR THIS BET"
	_less_button.disabled = locked or _bet_index == 0
	_more_button.disabled = locked or _bet_index >= _bet_levels.size() - 1

	var can_play := affordable and not locked
	_small_button.visible = _game == Game.SIC_BO
	_big_button.visible = _game == Game.SIC_BO
	_small_button.disabled = not can_play
	_big_button.disabled = not can_play

	var blackjack := _game == Game.BLACKJACK
	_deal_button.visible = blackjack and not _in_hand
	_deal_button.disabled = not can_play
	for hand_button in [_hit_button, _stand_button, _double_button]:
		hand_button.visible = blackjack and _in_hand
		hand_button.disabled = _busy
	_double_button.disabled = _busy or _player.size() != 2 or run.cash < _stake

	_spin_button.visible = _game == Game.SLOTS
	_spin_button.disabled = not can_play


func _current_bet() -> int:
	return _bet_levels[_bet_index] if not _bet_levels.is_empty() else _casino.min_bet


func _change_bet(direction: int) -> void:
	_bet_index = clampi(_bet_index + direction, 0, _bet_levels.size() - 1)
	_refresh_controls()


func _take_stake() -> bool:
	var bet := _current_bet()
	if not GameState.place_bet(_casino, bet):
		_refresh_controls()
		return false
	AudioService.play_sfx(Sfx.CHIPS_BET, 0.06)
	_stake = bet
	_result_label.text = ""
	return true


func _play_sic_bo(bet: Casino.SicBoBet) -> void:
	if not _take_stake():
		return
	var rng := GameState.casino_rng()
	var dice := Casino.roll_dice(rng)
	_pending_payout = Casino.sic_bo_payout(dice, bet, _stake)
	_set_busy(true)
	AudioService.play_sfx(Sfx.DICE_SHAKE)
	var elapsed := 0.0
	while elapsed < DICE_ROLL_SECONDS:
		for face in _dice:
			face.value = rng.randi_range(1, 6)
		await get_tree().create_timer(DICE_TICK_SECONDS).timeout
		elapsed += DICE_TICK_SECONDS
	for i in _dice.size():
		_dice[i].value = dice[i]
	AudioService.play_sfx(Sfx.DICE_THROW)
	var total: int = dice[0] + dice[1] + dice[2]
	var call := "Big" if total >= Casino.SIC_BO_BIG_MIN else "Small"
	if dice[0] == dice[1] and dice[1] == dice[2]:
		call = "Triple"
	_settle("%d, %s. " % [total, call])
	_set_busy(false)


func _spin() -> void:
	if not _take_stake():
		return
	var rng := GameState.casino_rng()
	var landed: Array[int] = []
	for i in _reels.size():
		landed.append(Casino.spin_reel(rng))
	_pending_payout = Casino.slot_payout(landed, _stake)
	_set_busy(true)
	AudioService.play_sfx(Sfx.REEL_SPIN)
	for i in _reels.size():
		_reels[i].spin(landed[i], REEL_SECONDS[i])
	await _reels.back().stopped
	var lead := ""
	if landed[0] == landed[1] and landed[1] == landed[2]:
		lead = "Three %s. " % Content.item(Casino.SLOT_SYMBOLS[landed[0]]).display_name
	_settle(lead)
	_set_busy(false)


func _deal() -> void:
	if not _take_stake():
		return
	_in_hand = true
	_player.clear()
	_dealer.clear()
	_clear_hand(_player_hand)
	_clear_hand(_dealer_hand)
	_set_busy(true)
	AudioService.play_sfx(Sfx.CARD_SHUFFLE)
	await _deal_card(true)
	await _deal_card(false)
	await _deal_card(true)
	await _deal_card(false, true)
	if Casino.is_natural(_player) or Casino.is_natural(_dealer):
		await _finish_hand()
		return
	_set_busy(false)


func _hit() -> void:
	_set_busy(true)
	await _deal_card(true)
	if Casino.hand_value(_player) >= Casino.BLACKJACK:
		await _finish_hand()
		return
	_set_busy(false)


func _double_down() -> void:
	if not GameState.place_bet(_casino, _stake):
		return
	AudioService.play_sfx(Sfx.CHIPS_BET, 0.06)
	_stake *= 2
	_set_busy(true)
	await _deal_card(true)
	await _finish_hand()


func _finish_hand() -> void:
	_set_busy(true)
	_reveal_dealer()
	var player_total := Casino.hand_value(_player)
	var player_natural := Casino.is_natural(_player)
	if player_total <= Casino.BLACKJACK and not player_natural:
		while Casino.dealer_should_hit(_dealer):
			await _deal_card(false)
	_pending_payout = Casino.blackjack_payout(_player, _dealer, _stake)
	var dealer_total := Casino.hand_value(_dealer)
	var lead := ""
	if player_total > Casino.BLACKJACK:
		lead = "Bust. "
	elif player_natural and _pending_payout > _stake:
		lead = "Blackjack. "
	elif dealer_total > Casino.BLACKJACK:
		lead = "Dealer busts. "
	else:
		lead = "%d against %d. " % [player_total, dealer_total]
	_in_hand = false
	_settle(lead)
	_set_busy(false)


func _deal_card(to_player: bool, face_down := false) -> void:
	var rng := GameState.casino_rng()
	var rank := Casino.draw_card(rng)
	var hand := _player if to_player else _dealer
	hand.append(rank)
	var card := PlayingCard.new()
	card.rank = rank
	card.suit = rng.randi_range(0, PlayingCard.Suit.size() - 1) as PlayingCard.Suit
	card.face_down = face_down
	card.modulate.a = 0.0
	var row := _player_hand if to_player else _dealer_hand
	row.add_child(card)
	row.add_theme_constant_override("separation", CARD_GAP if row.get_child_count() <= CARDS_BEFORE_OVERLAP else CARD_OVERLAP)
	create_tween().tween_property(card, "modulate:a", 1.0, CARD_DELAY_SECONDS * 0.6)
	AudioService.play_sfx(Sfx.CARD_DEAL, 0.1)
	_update_hand_labels()
	await get_tree().create_timer(CARD_DELAY_SECONDS).timeout


func _reveal_dealer() -> void:
	for card: PlayingCard in _dealer_hand.get_children():
		card.face_down = false
	_update_hand_labels()


func _clear_hand(row: HBoxContainer) -> void:
	row.add_theme_constant_override("separation", CARD_GAP)
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()


func _update_hand_labels() -> void:
	var hidden := _dealer_hand.get_children().any(func(card: PlayingCard) -> bool: return card.face_down)
	if _dealer.is_empty():
		_dealer_label.text = "DEALER"
	elif hidden:
		var showing: Array[int] = [_dealer[0]]
		_dealer_label.text = "DEALER %d" % Casino.hand_value(showing)
	else:
		_dealer_label.text = "DEALER %d" % Casino.hand_value(_dealer)
	_player_label.text = "YOU %d" % Casino.hand_value(_player) if not _player.is_empty() else "YOU"


func _settle(lead: String) -> void:
	var payout := _pending_payout
	_pending_payout = 0
	GameState.collect_winnings(payout, _stake)
	if payout > _stake:
		AudioService.play_sfx(Sfx.CHIPS_WIN)
		_result_label.text = lead + "Won %s" % Format.money(payout - _stake)
		_result_label.add_theme_color_override("font_color", Palette.RISK_LOW.lightened(0.3))
	elif payout == _stake:
		_result_label.text = lead + "Push, stake returned"
		_result_label.add_theme_color_override("font_color", Palette.TEXT)
	else:
		_result_label.text = lead + "Lost %s" % Format.money(_stake)
		_result_label.add_theme_color_override("font_color", Palette.RISK_HIGH)


func _set_busy(busy: bool) -> void:
	_busy = busy
	_refresh_controls()


func _host_says(line: String) -> void:
	if not is_inside_tree():
		return
	_portrait.set_talking(true)
	_speech.type_text("\"%s\"" % line)


func _play_entrance() -> void:
	_table.modulate.a = 0.0
	create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).tween_property(_table, "modulate:a", 1.0, 0.45).set_delay(0.12)
