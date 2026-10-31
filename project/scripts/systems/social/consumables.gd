class_name Consumables

## Operational single-use consumables. Burned directly from safehouse stash or carried bag.

const AMMO_9MM: StringName = &"ammo_9mm"
const COMBAT_STIMS: StringName = &"combat_stims"
const STREET_MEDS: StringName = &"street_meds"
const FAKE_IDS: StringName = &"fake_ids"
const BURNER_SIMS: StringName = &"burner_sims"
const CLONE_PLATES: StringName = &"clone_plates"
const ZERO_DAY_DRIVE: StringName = &"zero_day_drive"
const NETWORK_TAP: StringName = &"network_tap"
const RANSOMWARE_KIT: StringName = &"ransomware_kit"
const SNIPER_RIFLE: StringName = &"sniper_rifle"

const CORE_ITEMS: Array[StringName] = [
	AMMO_9MM,
	COMBAT_STIMS,
	STREET_MEDS,
	FAKE_IDS,
	BURNER_SIMS,
	CLONE_PLATES,
	ZERO_DAY_DRIVE,
	NETWORK_TAP,
	RANSOMWARE_KIT,
	SNIPER_RIFLE,
]

const STREET_MEDS_HEAL := 500
const BURNER_HEAT_DROP := 4
const ZERO_DAY_HEAT_DROP := 25
const RANSOMWARE_DAYS := 3


static func count(run: RunState, item_id: StringName) -> int:
	return Inventory.count(run, item_id) + Inventory.stashed(run, item_id)


static func has(run: RunState, item_id: StringName) -> bool:
	return count(run, item_id) > 0


static func burn(run: RunState, item_id: StringName) -> bool:
	if Inventory.count(run, item_id) > 0:
		Inventory.discard(run, item_id, 1)
		return true
	if Inventory.stashed(run, item_id) > 0:
		var left := int(run.stash[item_id]) - 1
		if left <= 0:
			run.stash.erase(item_id)
		else:
			run.stash[item_id] = left
		return true
	return false


static func can_use(run: RunState, item_id: StringName, _context: Dictionary = {}) -> bool:
	if not has(run, item_id):
		return false
	match item_id:
		STREET_MEDS:
			return Army.wounded(run) > 0
		ZERO_DAY_DRIVE:
			return run.heat > 0
		_:
			return true


static func use(run: RunState, item_id: StringName, context: Dictionary = {}) -> Dictionary:
	if not can_use(run, item_id, context):
		return { "ok": false, "message": "Cannot use %s right now." % item_name(item_id) }
	if not burn(run, item_id):
		return { "ok": false, "message": "Not enough %s." % item_name(item_id) }

	DailyTasks.record_use_consumable(run)

	match item_id:
		AMMO_9MM:
			return { "ok": true, "message": "9mm ammunition ready for suppressive fire." }
		COMBAT_STIMS:
			return { "ok": true, "message": "Combat stims ready for squad rally." }
		STREET_MEDS:
			var healed := heal_wounded(run, STREET_MEDS_HEAL)
			return { "ok": true, "message": "%s wounded men treated and returned to service." % Format.count(healed) }
		FAKE_IDS:
			run.fake_id_active = true
			return { "ok": true, "message": "Fake identification primed for next police stop." }
		BURNER_SIMS:
			Heat.add(run, -BURNER_HEAT_DROP)
			return { "ok": true, "message": "Burner SIM tossed. Line went cold (-%d heat)." % BURNER_HEAT_DROP }
		CLONE_PLATES:
			run.clone_plates_active = true
			return { "ok": true, "message": "Clone plates mounted. Vehicle transit shielded from camera tracking." }
		ZERO_DAY_DRIVE:
			Heat.add(run, -ZERO_DAY_HEAT_DROP)
			return { "ok": true, "message": "Surveillance database wiped (-%d heat)." % ZERO_DAY_HEAT_DROP }
		NETWORK_TAP:
			_scout_all_rivals(run)
			return { "ok": true, "message": "Network tap deployed. All rival corners and defenses uncovered." }
		RANSOMWARE_KIT:
			var target_gang := StringName(str(context.get("gang_id", "")))
			_freeze_rivals(run, target_gang)
			return { "ok": true, "message": "Ransomware injected. Rival recruitment frozen for %d days." % RANSOMWARE_DAYS }
		SNIPER_RIFLE:
			run.sniper_active = true
			return { "ok": true, "message": "Sniper Overwatch established. Enemy stronghold defense cancelled." }

	return { "ok": true, "message": "Consumed %s." % item_name(item_id) }


static func heal_wounded(run: RunState, max_heal: int) -> int:
	var healed := 0
	for tier in Army.DEPLOY_ORDER:
		var available := Army.count(run, tier, Army.State.WOUNDED)
		var take := mini(available, max_heal - healed)
		if take > 0:
			Army.move(run, tier, Army.State.WOUNDED, Army.State.ACTIVE, take)
			healed += take
		if healed >= max_heal:
			break
	return healed


static func item_name(item_id: StringName) -> String:
	var item := Content.item(item_id)
	return item.display_name if item != null else String(item_id).capitalize()


static func describe_effect(item_id: StringName) -> String:
	match item_id:
		AMMO_9MM:
			return "Powers Suppressive Fire in combat (-15% enemy power)."
		COMBAT_STIMS:
			return "Powers Squad Rally in combat (halves friendly casualties)."
		STREET_MEDS:
			return "Immediately heals up to %s wounded men in the clinic for free." % Format.count(STREET_MEDS_HEAL)
		FAKE_IDS:
			return "Guarantees safe passage during police roadblock inspections."
		BURNER_SIMS:
			return "Tosses burner line immediately (-%d heat)." % BURNER_HEAT_DROP
		CLONE_PLATES:
			return "Shields smuggling crate runs and travel from camera tracking."
		ZERO_DAY_DRIVE:
			return "Wipes police surveillance logs clean (-%d heat)." % ZERO_DAY_HEAT_DROP
		NETWORK_TAP:
			return "Remotely taps and scouts all rival corners with 100% accuracy."
		RANSOMWARE_KIT:
			return "Locks rival gang communication. Freezes their recruitment for %d days." % RANSOMWARE_DAYS
		SNIPER_RIFLE:
			return "Removes rival boss 1.5x stronghold advantage during corner assault."
	return ""


static func _scout_all_rivals(run: RunState) -> void:
	for gang in Gangs.confronting(run):
		for corner in Rivals.corners(run, gang):
			var men := War.defenders(run, corner)
			run.scouted[String(corner.id)] = {
				"low": men,
				"high": men,
				"gear": Rivals.gear(run, gang),
				"day": run.day,
				"seen": false,
			}
	DailyTasks.record_scout(run)


static func _freeze_rivals(run: RunState, target_gang: StringName) -> void:
	if not target_gang.is_empty():
		run.rival_ransomware[target_gang] = run.day + RANSOMWARE_DAYS
	else:
		for gang in Gangs.confronting(run):
			run.rival_ransomware[gang.id] = run.day + RANSOMWARE_DAYS
