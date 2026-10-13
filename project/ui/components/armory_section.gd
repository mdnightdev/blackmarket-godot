class_name ArmorySection
extends TurfSection

## The Armory on the Turf headquarters: how many of the men are armed, and a tile per weapon that orders more from
## Rook. Grades still in his back rooms stay locked until enough has been spent with him.

const ART: Texture2D = preload("res://assets/scenes/armory.jpg")
const WEAPON_ART := {
	Armory.Grade.BLADE: preload("res://assets/weapons/blades.jpg"),
	Armory.Grade.HANDGUN: preload("res://assets/weapons/handguns.jpg"),
	Armory.Grade.RIFLE: preload("res://assets/weapons/rifles.jpg"),
	Armory.Grade.MILITARY: preload("res://assets/weapons/military.jpg"),
}
const CHEAPEST_FIRST: Array[Armory.Grade] = [Armory.Grade.BLADE, Armory.Grade.HANDGUN, Armory.Grade.RIFLE, Armory.Grade.MILITARY]
const TILE_HEIGHT := 230.0

## What each tile showed last time, so weapons that just arrived are counted up in front of the player.
static var _shown := {}


func _build(run: RunState) -> void:
	if not Armory.unlocked(run):
		_add_banner(ART, "Locked", "Rook sells weapons once you own a corner in Old Market.")
		return
	var men := Army.active(run)
	var armed := mini(men, Armory.total(run))
	_add_banner(ART, "%s weapons" % Format.count(Armory.total(run)), "Guards are armed first, then Lunatics")
	_add_meter("Ready men armed", "%s / %s" % [Format.count(armed), Format.count(men)], float(armed) / men if men > 0 else 0.0,
		Palette.RISK_LOW if armed >= men else Palette.PEACH)
	for row_start in [0, 2]:
		var tiles := _add_card_row()
		for grade in CHEAPEST_FIRST.slice(row_start, row_start + 2):
			_add_tile(run, tiles, grade)


func _add_tile(run: RunState, parent: Container, grade: Armory.Grade) -> void:
	var owned := Armory.count(run, grade)
	var on_sale := Armory.is_on_sale(run, grade)
	var tile := _add_card(parent, TILE_HEIGHT)
	var status := "%s each" % Format.money(int(Armory.UNIT_PRICES[grade])) if on_sale else "Spend more with Rook"
	tile.show_art(WEAPON_ART[grade], str(Armory.GRADE_NAMES[grade]), Format.count(owned), status, not on_sale)
	tile.disabled = not on_sale
	tile.pressed.connect(GameOverlay.pick_weapons.bind(grade, false, Callable()))
	if owned > int(_shown.get(grade, owned)):
		tile.roll_count(int(_shown[grade]), owned)
	_shown[grade] = owned
