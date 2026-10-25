class_name Meetings

## Street customers and bar clients can come part of the way to the player for a cut of the price. The meeting spot
## is any open district on the shortest road between the player and the client, the player's own district included,
## and is saved on the order under "meet". A few buyers use the meeting to rip the player off and pay only part of it.

const PAY_SHARE := 0.8
const SCAM_CHANCE := 0.08
const SCAM_PAY := 0.4


## Where the client would agree to meet, nearest to the player first. Empty when the player is already there.
static func spots(run: RunState, client_district: StringName) -> Array[StringName]:
	var found: Array[StringName] = []
	if client_district == run.district_id:
		return found
	var shortest: Array = []
	for path in Routes.paths(run.district_id, client_district):
		if shortest.is_empty() or path.size() < shortest.size():
			shortest = path
	found.append(run.district_id)
	for stop: StringName in shortest.slice(0, -1):
		if not Travel.is_locked(run, Content.district(stop)):
			found.append(stop)
	return found


static func agree(order: Dictionary, spot: StringName) -> void:
	order.meet = String(spot)


static func spot(order: Dictionary) -> StringName:
	return StringName(str(order.get("meet", "")))


static func is_here(run: RunState, order: Dictionary) -> bool:
	return not spot(order).is_empty() and spot(order) == run.district_id


## Decided when the order is taken, so a reload cannot change it.
static func is_scam(run: RunState, order: Dictionary) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run.price_seed, &"meeting_scam", str(order.get("id", ""))])
	return rng.randf() < SCAM_CHANCE


## The unit price the client actually pays at the meeting.
static func unit_price(run: RunState, order: Dictionary, full_price: int) -> int:
	var price := full_price * PAY_SHARE
	if is_scam(run, order):
		price *= SCAM_PAY
	return maxi(1, roundi(price))


## The offered meeting price per unit, before any scam.
static func offered_price(full_price: int) -> int:
	return maxi(1, roundi(full_price * PAY_SHARE))


## Carries a saved meeting spot over to a cleaned order, leaving the key out when there is none.
static func copy_spot(source: Dictionary, clean: Dictionary) -> void:
	var saved := str(source.get("meet", ""))
	if Content.district(StringName(saved)) != null:
		clean.meet = saved
