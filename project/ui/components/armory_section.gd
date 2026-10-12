class_name ArmorySection
extends TurfSection

## The Armory on the Turf headquarters: the outfit's size, each tier of men and where they are, and the weapons
## bought from Rook with who carries them.

const MEN_ICON: Texture2D = preload("res://assets/icons/hud/biceps-flexed.svg")
const WEAPON_ICON: Texture2D = preload("res://assets/icons/hud/swords.svg")
const STAGE_ICON: Texture2D = preload("res://assets/icons/hud/crown.svg")
const FALLEN_ICON: Texture2D = preload("res://assets/icons/hud/flame.svg")
const LOCK_ICON: Texture2D = preload("res://assets/icons/hud/lock.svg")
const TIER_ICONS := {
	Army.Tier.LUNATICS: preload("res://assets/icons/hud/biceps-flexed.svg"),
	Army.Tier.GUARDS: preload("res://assets/icons/hud/shield.svg"),
	Army.Tier.BLACK_HAND: preload("res://assets/icons/hud/swords.svg"),
}
const TIER_ROLES := {
	Army.Tier.LUNATICS: "Cheap numbers from Auntie Tran",
	Army.Tier.GUARDS: "Trained by 午夜兔子 to take and hold corners",
	Army.Tier.BLACK_HAND: "Elite. They bring their own steel",
}


func _build(run: RunState) -> void:
	if not Armory.unlocked(run):
		_add_heading("ARMORY")
		_add_row(LOCK_ICON, "Armory", "", "Rook sells weapons once you own a corner in Old Market.", "LOCKED")
		return
	_add_heading("FORCES  ATTACK POWER %d" % roundi(Army.strength(run)))
	_add_row(STAGE_ICON, str(Army.expansion(run).name), "%d/%d men" % [Army.total(run), Army.capacity(run)],
		"Sends up to %d into one fight. Expand in the Gym." % Army.deploy_cap(run))
	for tier in Army.DEPLOY_ORDER:
		_add_tier(run, tier)
	if Army.fallen(run) > 0:
		_add_row(FALLEN_ICON, "Fallen", "%d" % Army.fallen(run), "Men who died fighting for you")
	_add_weapons(run)


func _add_tier(run: RunState, tier: Army.Tier) -> void:
	var wounded := Army.count(run, tier, Army.State.WOUNDED)
	var detail := "%d WOUNDED" % wounded if wounded > 0 else ""
	_add_row(TIER_ICONS[tier], Army.TIER_NAMES[tier], "%d/%d" % [Army.count(run, tier), Army.slots(run, tier)], TIER_ROLES[tier], detail, Palette.RISK_HIGH)


func _add_weapons(run: RunState) -> void:
	var everyone := {}
	for tier in Army.Tier.values():
		everyone[tier] = Army.count(run, tier)
	var carried := Army.issue(run, everyone)
	var unarmed := 0
	for tier: int in carried:
		unarmed += int(carried[tier].get(Armory.Grade.NONE, 0))
	_add_heading("WEAPONS  %d" % Armory.total(run))
	if unarmed > 0:
		_add_row(MEN_ICON, "Bare hands", "1 man" if unarmed == 1 else "%d men" % unarmed, "Rook in Warehouse Row sells weapons. The Guards are armed first.", "NEEDS WEAPONS", Palette.RISK_HIGH)
	for grade in Armory.BEST_FIRST:
		var owned := Armory.count(run, grade)
		var in_hands := 0
		for tier: int in carried:
			in_hands += int(carried[tier].get(grade, 0))
		var power := _power_text(Armory.power_of(grade))
		var caption := "%d carried, %s power each" % [in_hands, power] if owned > 0 else "None yet. %s power each." % power
		_add_row(WEAPON_ICON, Armory.GRADE_NAMES[grade], "%d" % owned, caption)


func _power_text(power: float) -> String:
	return ("%.1f" % power).trim_suffix(".0")
