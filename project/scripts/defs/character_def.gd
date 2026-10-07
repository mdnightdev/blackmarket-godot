class_name CharacterDef
extends SpeakerDef

enum Role { LENDER, ENFORCER, POLICE, INFORMANT, RIVAL }

const ROLE_NAMES := {
	Role.LENDER: "Lender",
	Role.ENFORCER: "Enforcer",
	Role.POLICE: "Police",
	Role.INFORMANT: "Informant",
	Role.RIVAL: "Rival",
}

@export var role: Role
## What the character says when the player walks up to them.
@export var line: String
## What the character means for play, shown under their line.
@export var blurb: String
## Fixed location when there is no route. Empty means the character never appears on the street.
@export var district_id: StringName
## Districts the character moves between, a new pick every phase.
@export var route: Array[StringName] = []
## Police only. Multiplies the stop chance in the district they patrol.
@export_range(1.0, 3.0, 0.05) var stop_multiplier: float = 1.0


func title() -> String:
	return role_name()


func role_name() -> String:
	return ROLE_NAMES[role]
