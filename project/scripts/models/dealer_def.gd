class_name DealerDef
extends SpeakerDef

## Home district. Residents always trade here.
@export var district_id: StringName
@export var greeting: String
## Categories this dealer sells.
@export var stock_categories: Array[StringName] = []
## District tier the dealer works. Dealers buy every trade good of their tier and the one below.
@export_range(1, 3) var tier: int = 1
## Category to price multiplier. Missing categories trade at 1.0.
@export var price_bias: Dictionary = {}
## Discount fraction the dealer accepts on an average mood.
@export_range(0.0, 0.3, 0.01) var haggle_tolerance: float = 0.1
## Market districts a travelling dealer picks from, one per day. Empty means a resident.
@export var route: Array[StringName] = []
## RunState.Phase values this dealer works. Empty means every phase.
@export var working_phases: Array[int] = []


func title() -> String:
	return "Dealer"


func sells(item: ItemDef) -> bool:
	return stock_categories.has(item.category) and deals_in(item)


func deals_in(item: ItemDef) -> bool:
	return item.tier == tier or item.tier == tier - 1


func bias_for(category: StringName) -> float:
	return float(price_bias.get(category, 1.0))


func is_resident() -> bool:
	return route.is_empty()


func works_in(phase: int) -> bool:
	return working_phases.is_empty() or working_phases.has(phase)
