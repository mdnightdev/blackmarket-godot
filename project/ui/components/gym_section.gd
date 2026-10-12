class_name GymSection
extends TurfSection

## The Gym on the Turf headquarters: 午夜兔子's training sessions, how the outfit's slots are split between the tiers,
## and the next training expansion.

const EXPAND: StringName = &"expand"
const LEAVE: StringName = &"leave"
const RABBIT: StringName = &"midnight_rabbit"
const GYM_ICON: Texture2D = preload("res://assets/icons/hud/dumbbell.svg")
const EXPAND_ICON: Texture2D = preload("res://assets/icons/hud/crown.svg")
const LOCK_ICON: Texture2D = preload("res://assets/icons/hud/lock.svg")
const SLIDER_STEPS := 20
const BLOCK_MARGIN := 12

var _slot_labels: Dictionary = {}


func _build(run: RunState) -> void:
	if not Gym.is_open(run):
		_add_heading("GYM")
		_add_row(LOCK_ICON, "Gym", "", "午夜兔子 runs the gym once he joins you. Buy Mama Lin's corner.", "LOCKED")
		return
	_add_heading("TRAINING SESSIONS")
	_add_row(GYM_ICON, "Next session", "Day %d" % Gym.next_session_day(run),
		"Four mornings a week. Fills empty slots and heals the wounded. About %s." % Format.money(Gym.estimate(run)))
	_add_heading("SLOTS  %d/%d" % [Army.slots_used(run), Army.capacity(run)])
	for tier in Army.DEPLOY_ORDER:
		_add_slider(run, tier)
	_add_expansion(run)


func _add_slider(run: RunState, tier: Army.Tier) -> void:
	var block := MarginContainer.new()
	block.add_theme_constant_override("margin_top", BLOCK_MARGIN)
	block.add_theme_constant_override("margin_bottom", BLOCK_MARGIN)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = Army.TIER_NAMES[tier]
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var value := Label.new()
	value.theme_type_variation = &"HudValueLabel"
	header.add_child(value)
	rows.add_child(header)
	var caption := Label.new()
	caption.theme_type_variation = &"MutedLabel"
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var locked := tier == Army.Tier.BLACK_HAND and not Army.black_hand_open(run)
	var counts := "%d ready, %d wounded." % [Army.count(run, tier), Army.count(run, tier, Army.State.WOUNDED)]
	if locked:
		caption.text = "Rabbit's unit only until Vex falls. %s" % counts
	else:
		caption.text = "%s for every hundred new men. %s" % [Format.money(Army.REPLACE_PRICES[tier]), counts]
	rows.add_child(caption)
	var slider := HSlider.new()
	slider.max_value = Army.capacity(run)
	slider.step = maxi(1, floori(Army.capacity(run) / float(SLIDER_STEPS)))
	slider.value = Army.slots(run, tier)
	slider.editable = not locked
	slider.value_changed.connect(_on_slider_moved.bind(slider, tier))
	slider.drag_ended.connect(func(_changed: bool) -> void: GameState.set_army_slots(tier, int(slider.value)))
	rows.add_child(slider)
	block.add_child(rows)
	add_child(block)
	_slot_labels[tier] = value
	_show_slots(tier, Army.slots(run, tier))


## Keeps the split inside the outfit's capacity while the slider moves. The run only changes when the drag ends.
func _on_slider_moved(amount: float, slider: HSlider, tier: Army.Tier) -> void:
	var run := GameState.run
	var allowed := Army.capacity(run) - (Army.slots_used(run) - Army.slots(run, tier))
	if amount > allowed:
		slider.set_value_no_signal(allowed)
	_show_slots(tier, int(slider.value))


func _show_slots(tier: Army.Tier, amount: int) -> void:
	(_slot_labels[tier] as Label).text = "%d slots" % amount


func _add_expansion(run: RunState) -> void:
	var current := Army.expansion(run)
	_add_heading("TRAINING EXPANSION")
	_add_row(EXPAND_ICON, str(current.name), "%d men" % Army.capacity(run), "Sends up to %d into one fight" % Army.deploy_cap(run))
	var price := Army.expansion_price(run)
	if price < 0:
		return
	var next: Dictionary = Army.EXPANSIONS[run.army_level + 1]
	var affordable := run.cash >= price
	_add_row(EXPAND_ICON, str(next.name), Format.money(price), "%d men, sends up to %d. New slots go to the Lunatics." % [int(next.capacity), int(next.deploy)],
		"TAP TO EXPAND" if affordable else "NOT ENOUGH CASH", Palette.TEXT_CREAM if affordable else Palette.TEXT_MUTED, _ask_expand.bind(next, price) if affordable else Callable())


func _ask_expand(next: Dictionary, price: int) -> void:
	var choices: Array[DialogueChoice] = [
		DialogueChoice.new(EXPAND, "Pay %s" % Format.money(price)),
		DialogueChoice.new(LEAVE, "Not now", true, true),
	]
	var line := "Room for %d men. I'll need more space and more mornings. You'll need more cash." % int(next.capacity)
	GameOverlay.talk(Content.speaker(RABBIT), line, choices, _on_expand_choice)


func _on_expand_choice(choice: StringName) -> void:
	GameOverlay.end_talk()
	if choice == EXPAND and GameState.expand_outfit() == Army.Result.OK:
		AudioService.play_sfx(Sfx.COINS_OUT)
