class_name CustomerDef
extends Resource

## How the customer prices and handles an order. See CustomerOffers.PROFILES for the numbers.
enum Temperament { LOWBALLER, FAIR, GENEROUS, BULK, HAGGLER, FLAKY, STING }

@export var id: StringName
@export var display_name: String
## Where the customer waits for the handover.
@export var district_id: StringName
## Opening line shown with every order this customer posts.
@export var line: String
## Trade good categories this customer orders.
@export var wants: Array[StringName] = []
@export var temperament: Temperament = Temperament.FAIR
## RunState.Phase values in which this customer posts orders. Empty means every phase.
@export var active_phases: Array[int] = []
## Street cred rank needed before this customer starts posting.
@export_range(1, 10) var min_rank: int = 1


func posts_in(phase: int) -> bool:
	return active_phases.is_empty() or active_phases.has(phase)
