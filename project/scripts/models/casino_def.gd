class_name CasinoDef
extends VenueDef

@export_range(1, 1_000_000) var min_bet: int = 50
@export_range(1, 1_000_000) var max_bet: int = 1000
## Cash the player must carry to be let in. 0 means anyone may enter.
@export_range(0, 10_000_000) var entry_cash: int = 0
