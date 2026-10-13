class_name GymSection
extends TurfSection

## The Gym on the Turf headquarters: 午夜兔子 trains the men. A card per tier opens its course and the men join on the
## spot. The outfit's level at the bottom sets how many go into one fight.

const ART: Texture2D = preload("res://assets/scenes/gym.jpg")
const CARD_COURSES := {
	Army.Tier.LUNATICS: Gym.Course.LUNATICS,
	Army.Tier.GUARDS: Gym.Course.GUARDS,
	Army.Tier.BLACK_HAND: Gym.Course.BLACK_HAND,
}

## What each card showed last time, so men who just joined are counted up in front of the player.
static var _shown := {}


func _build(run: RunState) -> void:
	if not Gym.is_open(run):
		_add_banner(ART, "Closed", "午夜兔子 opens it once he joins you. Buy Mama Lin's corner.")
		return
	_add_banner(ART, "%s ready" % Format.count(Army.active(run)), "%s go into one fight" % Format.count(Army.deploy_cap(run)))
	_add_unit_cards(run)
	_add_promotion(run)
	_add_level(run)


func _add_unit_cards(run: RunState) -> void:
	var cards := _add_card_row()
	for key: int in CARD_COURSES:
		var tier := key as Army.Tier
		var course: Gym.Course = CARD_COURSES[tier]
		var locked := course == Gym.Course.BLACK_HAND and not Army.black_hand_open(run)
		var count := Army.count(run, tier)
		var card := _add_card(cards)
		card.show_tier(tier, Format.count(count), "After Vex falls" if locked else per_man(Gym.price_per_thousand(course)), locked)
		card.disabled = locked
		card.pressed.connect(GameOverlay.pick_training.bind(course))
		if count > int(_shown.get(tier, count)):
			card.roll_count(int(_shown[tier]), count)
		_shown[tier] = count


func _add_promotion(run: RunState) -> void:
	var lunatics := Army.count(run, Army.Tier.LUNATICS)
	var text := "Promote Lunatics to Guards, %s" % per_man(Gym.price_per_thousand(Gym.Course.PROMOTION))
	var button := _add_button(&"SecondaryButton", text if lunatics > 0 else "Promote Lunatics to Guards: none ready", lunatics > 0)
	button.pressed.connect(GameOverlay.pick_training.bind(Gym.Course.PROMOTION))


func _add_level(run: RunState) -> void:
	var price := Army.expansion_price(run)
	_add_meter("Fight size: %s" % Army.expansion(run).name, "%s men" % Format.count(Army.deploy_cap(run)), float(run.army_level + 1) / Army.EXPANSIONS.size(), Palette.PEACH)
	if price < 0:
		return
	var next: Dictionary = Army.EXPANSIONS[run.army_level + 1]
	var button := _add_button(&"PrimaryButton", "Send %s into a fight, %s" % [Format.count(int(next.deploy)), Format.money(price)], run.cash >= price)
	button.pressed.connect(_expand)


func _expand() -> void:
	if GameState.expand_outfit() == Army.Result.OK:
		AudioService.play_sfx(Sfx.COINS_OUT)
