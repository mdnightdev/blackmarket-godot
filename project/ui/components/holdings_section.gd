class_name HoldingsSection
extends TurfSection

## The headquarters on the Turf page: everything the player owns on one page. Each row opens the part of the turf it
## sums up.

signal section_requested(id: StringName)

const CRED_ICON: Texture2D = preload("res://assets/icons/hud/zap.svg")
const CASH_ICON: Texture2D = preload("res://assets/icons/hud/banknote.svg")
const INCOME_ICON: Texture2D = preload("res://assets/icons/hud/hand-coins.svg")
const DEBT_ICON: Texture2D = preload("res://assets/icons/hud/landmark.svg")
const CORNER_ICON: Texture2D = preload("res://assets/icons/hud/flag.svg")
const DISTRICT_ICON: Texture2D = preload("res://assets/icons/hud/map.svg")
const ARMY_ICON: Texture2D = preload("res://assets/icons/hud/swords.svg")
const CREW_ICON: Texture2D = preload("res://assets/icons/hud/users.svg")
const BUSINESS_ICON: Texture2D = preload("res://assets/icons/hud/briefcase-business.svg")
const FAMILY_ICON: Texture2D = preload("res://assets/icons/hud/handshake.svg")
const VIEW := "TAP TO VIEW"


## True when skill points are waiting.
static func needs_attention(run: RunState) -> bool:
	return Skills.points_free(run) > 0


func _build(run: RunState) -> void:
	_add_cred(run)
	_add_money(run)
	_add_territory(run)
	_add_operations(run)


func _add_cred(run: RunState) -> void:
	_add_heading("STREET CRED")
	var rank := StreetCred.rank(run)
	var next_cred := StreetCred.next_rank_cred(rank)
	var caption := "Top rank" if next_cred < 0 else "%s at %d cred" % [StreetCred.rank_name(rank + 1), next_cred]
	_add_row(CRED_ICON, StreetCred.rank_name(rank), "%d cred" % run.street_cred, caption)


func _add_money(run: RunState) -> void:
	_add_heading("MONEY")
	var stashed := "%s more in the safehouse cash box" % Format.money(run.stashed_cash) if run.stashed_cash > 0 else "Nothing in the safehouse cash box"
	_add_row(CASH_ICON, "Cash", Format.money(run.cash), stashed, VIEW, Palette.TEXT_CREAM, _open.bind(&"safehouse"))
	_add_row(INCOME_ICON, "Every morning", "+%s" % Format.money(Turf.daily_cut(run)), "Rent and protection from the corners and districts you hold")
	if run.debt > 0:
		_add_row(DEBT_ICON, "Debt", Format.money(run.debt), "Owed to %s" % ("Vex" if Loan.is_with_vex(run) else "the Shark"))


func _add_territory(run: RunState) -> void:
	_add_heading("TERRITORY")
	for district_id in Turf.contested():
		var corners := Corners.of(district_id)
		if corners.is_empty():
			continue
		var held := corners.filter(func(corner: CornerDef) -> bool: return Corners.holds(run, corner.id)).map(func(corner: CornerDef) -> String: return corner.display_name)
		var district := Content.district(district_id)
		_add_row(CORNER_ICON, "%s corners" % district.display_name, "%d/%d" % [held.size(), corners.size()], ", ".join(held) if not held.is_empty() else "None yet")
	_add_row(DISTRICT_ICON, "Districts", "%d/%d held" % [Turf.held_count(run), Turf.contested().size()], "The territory map, district by district",
		VIEW, Palette.TEXT_CREAM, _open.bind(&"districts"))


func _add_operations(run: RunState) -> void:
	_add_heading("OPERATIONS")
	var army := "Locked until you own a corner" if not Armory.unlocked(run) else "%d ready, %d weapons, attack power %d" % [Army.active(run), Armory.total(run), roundi(Army.strength(run))]
	_add_row(ARMY_ICON, "Army", "%d men" % Army.total(run), army, VIEW, Palette.TEXT_CREAM, _open.bind(&"armory"))
	_add_row(CREW_ICON, "Crew", "%d/%d" % [Crew.hired_count(run), Crew.cap(run)], "Hired hands and what they do for you", VIEW, Palette.TEXT_CREAM, _open.bind(&"crew"))
	var points := Skills.points_free(run)
	_add_row(CRED_ICON, "Skills", "%d free" % points, "Points to spend as your cred grows",
		"POINTS TO SPEND" if points > 0 else VIEW, Palette.PEACH_BRIGHT if points > 0 else Palette.TEXT_CREAM, _open.bind(&"skills"))
	_add_row(BUSINESS_ICON, "Businesses", "%d open" % run.businesses.size(), "Fronts that sell your stock", VIEW, Palette.TEXT_CREAM, _open.bind(&"businesses"))
	_add_row(FAMILY_ICON, "Families", "%d trust you" % Families.trusted_count(run), "Standing with the old families", VIEW, Palette.TEXT_CREAM, _open.bind(&"families"))


func _open(id: StringName) -> void:
	section_requested.emit(id)
