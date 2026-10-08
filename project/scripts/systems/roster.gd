class_name Roster

## Who is where is derived from the run seed and the phase stamp, so it needs no saving
## and the same phase always shows the same people.


## Travelling dealers pick one district per day and only show up in their working phases.
## Returns an empty id while a travelling dealer is off duty.
static func dealer_location(run: RunState, dealer: DealerDef, phase_stamp: int) -> StringName:
	if dealer.is_resident():
		return dealer.district_id
	if not dealer.works_in(phase_stamp % RunState.Phase.size()):
		return &""
	var day_index := floori(float(phase_stamp) / RunState.Phase.size())
	return _pick(run, dealer.route, [&"roster", day_index, dealer.id], false)


## Characters with a route pick a new district every phase. Police favour districts with more heat.
static func character_location(run: RunState, character: CharacterDef, phase_stamp: int) -> StringName:
	if character.role == CharacterDef.Role.RIVAL and Gangs.is_gone(run, Gangs.for_boss(character.id)):
		return &""
	if character.route.is_empty():
		return character.district_id
	var police := character.role == CharacterDef.Role.POLICE
	return _pick(run, character.route, [&"roster", phase_stamp, character.id], police)


## Residents first, then travelling dealers, each group in catalog order.
static func dealers_at(run: RunState, district_id: StringName, phase_stamp: int) -> Array[DealerDef]:
	var residents: Array[DealerDef] = []
	var visitors: Array[DealerDef] = []
	for dealer in Content.dealers():
		if dealer_location(run, dealer, phase_stamp) != district_id:
			continue
		if dealer.is_resident():
			residents.append(dealer)
		else:
			visitors.append(dealer)
	return residents + visitors


static func characters_at(run: RunState, district_id: StringName, phase_stamp: int) -> Array[CharacterDef]:
	var present: Array[CharacterDef] = []
	for character in Content.characters():
		if character_location(run, character, phase_stamp) == district_id:
			present.append(character)
	return present


## The officer with the highest stop multiplier in the district, or null when no police are around.
static func strongest_patrol(run: RunState, district_id: StringName, phase_stamp: int) -> CharacterDef:
	var strongest: CharacterDef = null
	for character in characters_at(run, district_id, phase_stamp):
		if character.role == CharacterDef.Role.POLICE and (strongest == null or character.stop_multiplier > strongest.stop_multiplier):
			strongest = character
	return strongest


static func patrol_multiplier(run: RunState, district_id: StringName, phase_stamp: int) -> float:
	var patrol := strongest_patrol(run, district_id, phase_stamp)
	return patrol.stop_multiplier if patrol != null else 1.0


static func _pick(run: RunState, districts: Array[StringName], seed_parts: Array, weight_by_heat: bool) -> StringName:
	var weights: Array[float] = []
	var total := 0.0
	for district_id in districts:
		var weight := 1.0
		if weight_by_heat:
			var district := Content.district(district_id)
			weight = district.heat_multiplier if district != null else 1.0
		weights.append(weight)
		total += weight
	var target := Market.roll(run, seed_parts, 0.0, total)
	for index in districts.size():
		target -= weights[index]
		if target < 0.0:
			return districts[index]
	return districts[-1]
