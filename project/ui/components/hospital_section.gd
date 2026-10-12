class_name HospitalSection
extends TurfSection

## The Hospital on the Turf headquarters: the wounded waiting for the next training session, what healing them costs,
## and the next upgrade.

const UPGRADE: StringName = &"upgrade"
const LEAVE: StringName = &"leave"
const BED_ICON: Texture2D = preload("res://assets/icons/hud/cross.svg")
const UPGRADE_ICON: Texture2D = preload("res://assets/icons/hud/wrench.svg")


func _build(run: RunState) -> void:
	_add_heading("HOSPITAL  %d BEDS" % Hospital.beds(run))
	_add_row(BED_ICON, "Wounded", "%d" % Army.wounded(run), "Healed at the next training session, day %d. %d beds, Black Hand first." % [Gym.next_session_day(run), Hospital.beds(run)],
		"WAITING" if Army.wounded(run) > 0 else "", Palette.RISK_HIGH)
	for tier in Army.DEPLOY_ORDER:
		_add_row(BED_ICON, Army.TIER_NAMES[tier], "%d" % Army.count(run, tier, Army.State.WOUNDED), "%s to heal every hundred" % Format.money(Hospital.HEAL_PRICES[tier]))
	_add_upgrade(run)


func _add_upgrade(run: RunState) -> void:
	var price := Hospital.upgrade_price(run)
	if price < 0:
		_add_row(UPGRADE_ICON, "Fully built", "", "The best hospital money can hide.", "MAXED")
		return
	var beds := int(Hospital.LEVELS[run.hospital_level + 1].beds)
	var affordable := run.cash >= price
	_add_row(UPGRADE_ICON, "Expand to %d beds" % beds, Format.money(price), "Heals more men at each session.",
		"TAP TO BUILD" if affordable else "NOT ENOUGH CASH", Palette.TEXT_CREAM if affordable else Palette.TEXT_MUTED, _ask_upgrade.bind(beds, price) if affordable else Callable())


func _ask_upgrade(beds: int, price: int) -> void:
	var choices: Array[DialogueChoice] = [
		DialogueChoice.new(UPGRADE, "Build it (%s)" % Format.money(price)),
		DialogueChoice.new(LEAVE, "Not now", true, true),
	]
	var line := "More beds means fewer men bleeding in the hallway. %d beds." % beds
	GameOverlay.talk(Content.player(GameState.run.player_id), line, choices, _on_upgrade_choice)


func _on_upgrade_choice(choice: StringName) -> void:
	GameOverlay.end_talk()
	if choice == UPGRADE and GameState.upgrade_hospital() == Hospital.Result.OK:
		AudioService.play_sfx(Sfx.COINS_OUT)
