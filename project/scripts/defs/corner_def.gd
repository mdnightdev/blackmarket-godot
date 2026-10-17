class_name CornerDef
extends Resource

## A street corner inside a district. The seller keeps working it whoever holds it, and pays the holder rent and
## protection every morning.

@export var id: StringName
@export var display_name: String
## Pin location on the district's corner map, as a fraction of its width and height.
@export var map_position := Vector2(0.5, 0.5)
## What the corner sells, in a few words.
@export var moves: String
## The dealer who works the corner, empty when nobody deals from it.
@export var seller: StringName
## Gang holding this corner when a district is split between two crews. Empty uses the district's primary gang.
@export var gang: StringName = &""
## The gang's strongest corner, fought for last.
@export var stronghold := false
## The seller's rent for the spot, paid to whoever holds the corner.
@export_range(0, 100_000) var rent: int = 0
## What the corner's business pays to be left alone.
@export_range(0, 100_000) var protection: int = 0
## Fighters the gang keeps on the corner before a war.
@export_range(0, 1_000_000) var defenders: int = 0


func daily_cut() -> int:
	return rent + protection
