class_name HospitalSection
extends TurfSection

## The Hospital on the Turf headquarters: the wounded, the beds they fill, one button that heals them and the next
## expansion. When every bed is taken, men hit in a fight die instead of coming here.

const ART: Texture2D = preload("res://assets/scenes/hospital.jpg")
const CARD_HEIGHT := 170.0


func _build(run: RunState) -> void:
	var wounded := Army.wounded(run)
	var beds := Hospital.beds(run)
	_add_banner(ART, "%s wounded" % Format.count(wounded) if wounded > 0 else "Nobody hurt",
		"Full beds mean the next wounded die" if Hospital.free_beds(run) == 0 else "",
		Palette.PEACH_BRIGHT if wounded > 0 else Palette.TEXT_CREAM)
	_add_meter("Beds taken", "%s / %s" % [Format.count(wounded), Format.count(beds)], float(wounded) / beds,
		Palette.RISK_HIGH if Hospital.free_beds(run) == 0 else Palette.PEACH)
	var cards := _add_card_row()
	for tier: Army.Tier in Army.Tier.values():
		var card := _add_card(cards, CARD_HEIGHT)
		card.show_tier(tier, Format.count(Army.count(run, tier, Army.State.WOUNDED)), per_man(int(Hospital.HEAL_PRICES[tier])))
		card.disabled = true
	_add_heal_button(run, wounded)
	_add_upgrade(run)


func _add_heal_button(run: RunState, wounded: int) -> void:
	var cost := Hospital.estimate(run)
	var text := "Heal everyone, %s" % Format.money(cost)
	if wounded == 0:
		text = "Nobody to heal"
	elif run.cash < cost:
		text = "Heal what %s covers" % Format.money(run.cash)
	var button := _add_button(&"PrimaryButton", text, wounded > 0 and run.cash > 0)
	button.pressed.connect(_heal)


func _heal() -> void:
	if int(GameState.heal_wounded().healed) > 0:
		AudioService.play_sfx(Sfx.COINS_OUT)


func _add_upgrade(run: RunState) -> void:
	var price := Hospital.upgrade_price(run)
	if price < 0:
		return
	var beds := int(Hospital.LEVELS[run.hospital_level + 1].beds)
	var button := _add_button(&"SecondaryButton", "Grow to %s beds, %s" % [Format.count(beds), Format.money(price)], run.cash >= price)
	button.pressed.connect(_upgrade)


func _upgrade() -> void:
	if GameState.upgrade_hospital() == Hospital.Result.OK:
		AudioService.play_sfx(Sfx.COINS_OUT)
