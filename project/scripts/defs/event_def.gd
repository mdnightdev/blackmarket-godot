class_name EventDef
extends Resource

enum Effect { PRICE_SHIFT, MUGGING, LUCKY_FIND }
## Where a price shift lands: the player's district, a random other district with a market, or a category the player carries here.
enum Scope { HERE, ELSEWHERE, CARRIED_HERE }

@export var id: StringName
@export var title: String
## Spoken by the speaker. Placeholders: {district}, {category}, {item}, {quantity}, {amount}.
@export_multiline var body: String
## Character id who delivers the event. Empty means the player's own narration.
@export var speaker: StringName
@export var effect: Effect = Effect.PRICE_SHIFT
@export_range(1, 100) var weight: int = 10
@export_range(1, 365) var min_day: int = 1

@export_group("Price shift")
@export var scope: Scope = Scope.ELSEWHERE
## Leave empty to pick a random trade category.
@export var category: StringName
@export_range(0.2, 3.0, 0.05) var multiplier: float = 1.0
@export_range(1, 12) var duration_phases: int = 4
## Shifts that start next morning read as a tip rather than news.
@export var starts_next_day := false

@export_group("Mugging")
@export_range(0.0, 1.0, 0.01) var cash_fraction: float = 0.0

@export_group("Lucky find")
@export_range(1, 50) var min_quantity: int = 1
@export_range(1, 50) var max_quantity: int = 1
