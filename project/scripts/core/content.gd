extends Node

const DISTRICTS_FOLDER := "res://data/districts"
const VENUES_FOLDER := "res://data/venues"
const ITEMS_FILE := "res://data/items_db.json"
const DEALERS_FOLDER := "res://data/dealers"
const EVENTS_FOLDER := "res://data/events"
const CHARACTERS_FOLDER := "res://data/characters"
const PLAYERS_FOLDER := "res://data/players"
const FAMILIES_FOLDER := "res://data/families"
const GANGS_FOLDER := "res://data/gangs"
const CREW_FOLDER := "res://data/crew"
const BUSINESSES_FOLDER := "res://data/businesses"
const HEISTS_FOLDER := "res://data/heists"
const CUSTOMERS_FOLDER := "res://data/customers"

var _districts: Dictionary = {}
var _venues: Dictionary = {}
var _items: Dictionary = {}
var _dealers: Dictionary = {}
var _residents_by_district: Dictionary = {}
var _characters: Dictionary = {}
var _players: Dictionary = {}
var _families: Dictionary = {}
var _gangs: Dictionary = {}
var _crew_roles: Dictionary = {}
var _businesses: Dictionary = {}
var _heists: Dictionary = {}
var _customers: Dictionary = {}
var _events: Array[EventDef] = []
var _is_loaded := false


func _ready() -> void:
	# Load immediately if running headless test suite
	if DisplayServer.get_name() == "headless":
		ensure_loaded()


func is_loaded() -> bool:
	return _is_loaded


func ensure_loaded() -> void:
	if _is_loaded:
		return
	for step in range(6):
		load_step(step)


func load_step(step_idx: int) -> String:
	match step_idx:
		0:
			_districts = Catalog.index_by_id(Catalog.load_folder(DISTRICTS_FOLDER))
			_venues = Catalog.index_by_id(Catalog.load_folder(VENUES_FOLDER))
			return "Mapping District Venues..."
		1:
			_items = _load_items()
			_dealers = Catalog.index_by_id(Catalog.load_folder(DEALERS_FOLDER))
			for d: DealerDef in _dealers.values():
				if d.is_resident():
					_residents_by_district[d.district_id] = d
			return "Indexing Contraband & Markets..."
		2:
			_characters = Catalog.index_by_id(Catalog.load_folder(CHARACTERS_FOLDER))
			_players = Catalog.index_by_id(Catalog.load_folder(PLAYERS_FOLDER))
			return "Locating Underworld Contacts..."
		3:
			_families = Catalog.index_by_id(Catalog.load_folder(FAMILIES_FOLDER))
			_gangs = Catalog.index_by_id(Catalog.load_folder(GANGS_FOLDER))
			return "Establishing Syndicate Intelligence..."
		4:
			_crew_roles = Catalog.index_by_id(Catalog.load_folder(CREW_FOLDER))
			_businesses = Catalog.index_by_id(Catalog.load_folder(BUSINESSES_FOLDER))
			_heists = Catalog.index_by_id(Catalog.load_folder(HEISTS_FOLDER))
			return "Preparing Fronts & Operations..."
		5:
			_customers = Catalog.index_by_id(Catalog.load_folder(CUSTOMERS_FOLDER))
			_events.assign(Catalog.load_folder(EVENTS_FOLDER))
			_is_loaded = true
			return "Connecting to Black Market..."
	return "Ready"


func district(id: StringName) -> DistrictDef:
	ensure_loaded()
	return _districts.get(id)


func districts() -> Array[DistrictDef]:
	ensure_loaded()
	var list: Array[DistrictDef] = []
	list.assign(_districts.values())
	return list


func venue(id: StringName) -> VenueDef:
	ensure_loaded()
	return _venues.get(id)


func item(id: StringName) -> ItemDef:
	ensure_loaded()
	return _items.get(id)


## Items of one kind, cheapest first.
func items(kind: ItemDef.Kind) -> Array[ItemDef]:
	ensure_loaded()
	var list: Array[ItemDef] = []
	for entry: ItemDef in _items.values():
		if entry.kind == kind:
			list.append(entry)
	list.sort_custom(func(a: ItemDef, b: ItemDef) -> bool: return a.base_price < b.base_price)
	return list


## Trade goods and consumables that can be bought and sold on the market.
func tradable_items() -> Array[ItemDef]:
	ensure_loaded()
	var list: Array[ItemDef] = []
	for entry: ItemDef in _items.values():
		if entry.kind == ItemDef.Kind.TRADE_GOOD or entry.kind == ItemDef.Kind.CONSUMABLE:
			list.append(entry)
	list.sort_custom(func(a: ItemDef, b: ItemDef) -> bool: return a.base_price < b.base_price)
	return list


## The resident dealer who always trades in a district.
func dealer_in(district_id: StringName) -> DealerDef:
	ensure_loaded()
	return _residents_by_district.get(district_id)


func dealer(id: StringName) -> DealerDef:
	ensure_loaded()
	return _dealers.get(id)


## Residents and travelling dealers.
func dealers() -> Array[DealerDef]:
	ensure_loaded()
	var list: Array[DealerDef] = []
	list.assign(_dealers.values())
	return list


func characters() -> Array[CharacterDef]:
	ensure_loaded()
	var list: Array[CharacterDef] = []
	list.assign(_characters.values())
	return list


func character(id: StringName) -> CharacterDef:
	ensure_loaded()
	return _characters.get(id)


func players() -> Array[PlayerDef]:
	ensure_loaded()
	var list: Array[PlayerDef] = []
	list.assign(_players.values())
	return list


## Falls back to the first player so an old or edited save still has a face.
func player(id: StringName) -> PlayerDef:
	ensure_loaded()
	if _players.has(id):
		return _players[id]
	var all := players()
	return all[0] if not all.is_empty() else null


## Any character, dealer or player by id.
func speaker(id: StringName) -> SpeakerDef:
	ensure_loaded()
	if _characters.has(id):
		return _characters[id]
	if _dealers.has(id):
		return _dealers[id]
	return _players.get(id)


func events() -> Array[EventDef]:
	ensure_loaded()
	return _events


func gang(id: StringName) -> GangDef:
	ensure_loaded()
	return _gangs.get(id)


func gangs() -> Array[GangDef]:
	ensure_loaded()
	var list: Array[GangDef] = []
	list.assign(_gangs.values())
	return list


func family(id: StringName) -> FamilyDef:
	ensure_loaded()
	return _families.get(id)


func families() -> Array[FamilyDef]:
	ensure_loaded()
	var list: Array[FamilyDef] = []
	list.assign(_families.values())
	return list


func crew_role(id: StringName) -> CrewRoleDef:
	ensure_loaded()
	return _crew_roles.get(id)


## Cheapest to hire first.
func crew_roles() -> Array[CrewRoleDef]:
	ensure_loaded()
	var list: Array[CrewRoleDef] = []
	list.assign(_crew_roles.values())
	list.sort_custom(func(a: CrewRoleDef, b: CrewRoleDef) -> bool: return a.hire_cost < b.hire_cost)
	return list


func business(id: StringName) -> BusinessDef:
	ensure_loaded()
	return _businesses.get(id)


## Cheapest first.
func businesses() -> Array[BusinessDef]:
	ensure_loaded()
	var list: Array[BusinessDef] = []
	list.assign(_businesses.values())
	list.sort_custom(func(a: BusinessDef, b: BusinessDef) -> bool: return a.price < b.price)
	return list


func heist(id: StringName) -> HeistDef:
	ensure_loaded()
	return _heists.get(id)


## Lowest rank first.
func heists() -> Array[HeistDef]:
	ensure_loaded()
	var list: Array[HeistDef] = []
	list.assign(_heists.values())
	list.sort_custom(func(a: HeistDef, b: HeistDef) -> bool: return a.min_rank < b.min_rank)
	return list


func customer(id: StringName) -> CustomerDef:
	ensure_loaded()
	return _customers.get(id)


## Sorted by id, so seeded picks stay stable when files are added.
func customers() -> Array[CustomerDef]:
	ensure_loaded()
	var list: Array[CustomerDef] = []
	list.assign(_customers.values())
	list.sort_custom(func(a: CustomerDef, b: CustomerDef) -> bool: return String(a.id) < String(b.id))
	return list


func _load_items() -> Dictionary:
	var loaded := {}
	var file := FileAccess.open(ITEMS_FILE, FileAccess.READ)
	if not file:
		push_error("Failed to open %s" % ITEMS_FILE)
		return loaded

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("Failed to parse %s" % ITEMS_FILE)
		return loaded

	var data: Dictionary = json.data
	for id_str in data:
		var d: Dictionary = data[id_str]
		var loaded_item := ItemDef.new()
		loaded_item.id = StringName(d.get("id", id_str))
		loaded_item.display_name = d.get("display_name", "")
		loaded_item.kind = d.get("kind", 0) as ItemDef.Kind
		loaded_item.category = StringName(d.get("category", "goods"))
		loaded_item.base_price = int(d.get("base_price", 100))
		loaded_item.risk = int(d.get("risk", 10))
		loaded_item.slots = int(d.get("slots", 1))
		loaded_item.tier = int(d.get("tier", 1))
		loaded_item.min_rank = int(d.get("min_rank", 0))
		loaded_item.description = d.get("description", "")
		loaded_item.capacity_bonus = int(d.get("capacity_bonus", 0))
		loaded_item.fare_discount = float(d.get("fare_discount", 0.0))
		loaded_item.effect = StringName(d.get("effect", ""))
		loaded[loaded_item.id] = loaded_item

	return loaded
