class_name PlayerDef
extends SpeakerDef

## The small advantage each background brings. See Edges.
enum Edge { NONE, INTEL, ROUTES, STINGS, VENUES, CREDIT, BUY_PRICES }

## The speaker id origin lines use for the player.
const ORIGIN_PLAYER := "player"

@export var tagline: String
## Spoken on the character pick screen.
@export var intro_line: String
@export var edge: Edge
## Shown under the tagline on the character pick screen.
@export var edge_text: String
## How this character ended up owing the Shark, told before the run starts.
@export_multiline var origin_story: String
## The scene that follows the story: { speaker, line }, where speaker is a character id or ORIGIN_PLAYER.
@export var origin_lines: Array[Dictionary] = []


func title() -> String:
	return "You"
