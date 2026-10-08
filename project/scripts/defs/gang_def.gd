class_name GangDef
extends Resource

## A street crew fighting the player for turf. Its boss walks the turf on the boss character's route, and the
## player wins a district from the crew by holding most of it. Taking every district of its turf drives the crew out.

## What the crew does to a player working its corners.
enum Style {
	## Asks for a cut. Refusing costs ground and angers the boss.
	TAX,
	## Jumps the player for a share of the cash carried. Hand it over, fight or run.
	MUGGING,
	## Wants hush money. Refusing sends the police after the player.
	INFORMER,
}

@export var id: StringName
## Short name for labels, for example "Vex".
@export var display_name: String
## How the street names the crew, for example "Vex's crew".
@export var crew_name: String
## Character id of the boss.
@export var boss: StringName
@export var style := Style.TAX
@export var turf: Array[StringName] = []
## Districts where the crew starts strong, mapped to the player's starting share there.
@export var strongholds: Dictionary = {}
@export var color: Color = Color.WHITE

@export_group("Lines")
@export var gate_title: String
## %s is the district name.
@export_multiline var gate_line: String
@export var hunt_title: String
@export_multiline var hunt_line: String
## Spoken by the boss when the crew catches the player moving a crate.
@export_multiline var ambush_line: String
## Said by a dealer in a district the crew holds.
@export_multiline var dealer_line: String
@export var victory_title: String
## %s is the reward.
@export_multiline var victory_line: String

@export_group("Numbers")
## Chance per phase of a corner tax when the crew holds the whole district. It falls to nothing at an even split.
@export_range(0.0, 1.0) var max_gate_chance := 0.35
@export var bribe_base := 200
@export var bribe_per_anger := 100
@export var hunt_fee := 500
## Share taken in a phase where the crew holds the whole district. It takes less the less it holds.
@export var max_push := 6
@export var victory_reward := 5000
