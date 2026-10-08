extends Node

const DISTRICTS_FOLDER := "res://data/districts"
const VENUES_FOLDER := "res://data/venues"
const ITEMS_FOLDER := "res://data/items"
const DEALERS_FOLDER := "res://data/dealers"
const EVENTS_FOLDER := "res://data/events"
const CHARACTERS_FOLDER := "res://data/characters"
const PLAYERS_FOLDER := "res://data/players"
const FAMILIES_FOLDER := "res://data/families"
const CREW_FOLDER := "res://data/crew"
const BUSINESSES_FOLDER := "res://data/businesses"
const HEISTS_FOLDER := "res://data/heists"

var _districts: Dictionary = {}
var _venues: Dictionary = {}
var _items: Dictionary = {}
var _dealers: Dictionary = {}
var _residents_by_district: Dictionary = {}
var _characters: Dictionary = {}
var _players: Dictionary = {}
var _families: Dictionary = {}
var _crew_roles: Dictionary = {}
var _businesses: Dictionary = {}
var _heists: Dictionary = {}
var _events: Array[EventDef] = []


func _ready() -> void:
	_districts = Catalog.index_by_id(Catalog.load_folder(DISTRICTS_FOLDER))
	_venues = Catalog.index_by_id(Catalog.load_folder(VENUES_FOLDER))
	_items = Catalog.index_by_id(Catalog.load_folder(ITEMS_FOLDER))
	_dealers = Catalog.index_by_id(Catalog.load_folder(DEALERS_FOLDER))
	for dealer: DealerDef in _dealers.values():
		if dealer.is_resident():
			_residents_by_district[dealer.district_id] = dealer
	_characters = Catalog.index_by_id(Catalog.load_folder(CHARACTERS_FOLDER))
	_players = Catalog.index_by_id(Catalog.load_folder(PLAYERS_FOLDER))
	_families = Catalog.index_by_id(Catalog.load_folder(FAMILIES_FOLDER))
	_crew_roles = Catalog.index_by_id(Catalog.load_folder(CREW_FOLDER))
	_businesses = Catalog.index_by_id(Catalog.load_folder(BUSINESSES_FOLDER))
	_heists = Catalog.index_by_id(Catalog.load_folder(HEISTS_FOLDER))
	_events.assign(Catalog.load_folder(EVENTS_FOLDER))


func district(id: StringName) -> DistrictDef:
	return _districts.get(id)


func districts() -> Array[DistrictDef]:
	var list: Array[DistrictDef] = []
	list.assign(_districts.values())
	return list


func venue(id: StringName) -> VenueDef:
	return _venues.get(id)


func item(id: StringName) -> ItemDef:
	return _items.get(id)


## Items of one kind, cheapest first.
func items(kind: ItemDef.Kind) -> Array[ItemDef]:
	var list: Array[ItemDef] = []
	for entry: ItemDef in _items.values():
		if entry.kind == kind:
			list.append(entry)
	list.sort_custom(func(a: ItemDef, b: ItemDef) -> bool: return a.base_price < b.base_price)
	return list


## The resident dealer who always trades in a district.
func dealer_in(district_id: StringName) -> DealerDef:
	return _residents_by_district.get(district_id)


func dealer(id: StringName) -> DealerDef:
	return _dealers.get(id)


## Residents and travelling dealers.
func dealers() -> Array[DealerDef]:
	var list: Array[DealerDef] = []
	list.assign(_dealers.values())
	return list


func characters() -> Array[CharacterDef]:
	var list: Array[CharacterDef] = []
	list.assign(_characters.values())
	return list


func character(id: StringName) -> CharacterDef:
	return _characters.get(id)


func players() -> Array[PlayerDef]:
	var list: Array[PlayerDef] = []
	list.assign(_players.values())
	return list


## Falls back to the first player so an old or edited save still has a face.
func player(id: StringName) -> PlayerDef:
	if _players.has(id):
		return _players[id]
	var all := players()
	return all[0] if not all.is_empty() else null


## Any character, dealer or player by id.
func speaker(id: StringName) -> SpeakerDef:
	if _characters.has(id):
		return _characters[id]
	if _dealers.has(id):
		return _dealers[id]
	return _players.get(id)


func events() -> Array[EventDef]:
	return _events


func family(id: StringName) -> FamilyDef:
	return _families.get(id)


func families() -> Array[FamilyDef]:
	var list: Array[FamilyDef] = []
	list.assign(_families.values())
	return list


func crew_role(id: StringName) -> CrewRoleDef:
	return _crew_roles.get(id)


## Cheapest to hire first.
func crew_roles() -> Array[CrewRoleDef]:
	var list: Array[CrewRoleDef] = []
	list.assign(_crew_roles.values())
	list.sort_custom(func(a: CrewRoleDef, b: CrewRoleDef) -> bool: return a.hire_cost < b.hire_cost)
	return list


func business(id: StringName) -> BusinessDef:
	return _businesses.get(id)


## Cheapest first.
func businesses() -> Array[BusinessDef]:
	var list: Array[BusinessDef] = []
	list.assign(_businesses.values())
	list.sort_custom(func(a: BusinessDef, b: BusinessDef) -> bool: return a.price < b.price)
	return list


func heist(id: StringName) -> HeistDef:
	return _heists.get(id)


## Lowest rank first.
func heists() -> Array[HeistDef]:
	var list: Array[HeistDef] = []
	list.assign(_heists.values())
	list.sort_custom(func(a: HeistDef, b: HeistDef) -> bool: return a.min_rank < b.min_rank)
	return list
