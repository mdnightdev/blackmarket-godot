class_name ItemsAtlas
extends RefCounted

## ItemsAtlas
## Central on-demand AtlasTexture resolver for all 100 Black Market items and street props.
## 10 columns x 10 rows (2560x2560 px master atlas, 256x256 per tile).
## Pure flat matte dark neutral slate (#111318), zero glass, zero borders.

const ATLAS_PATH := "res://assets/items/items_atlas.png"
const TILE_SIZE := 256
const COLS := 10
const ROWS := 10

const ITEM_COORDINATES := {
	&"alloy_wheels": Vector2i(0, 5),
	&"ammo_12gauge": Vector2i(7, 0),
	&"ammo_300blackout": Vector2i(5, 1),
	&"ammo_45": Vector2i(4, 0),
	&"ammo_50bmg": Vector2i(7, 1),
	&"ammo_9mm": Vector2i(2, 0),
	&"ancient_artifacts": Vector2i(2, 8),
	&"anti_materiel_rifle": Vector2i(6, 1),
	&"armored_glass": Vector2i(1, 5),
	&"assault_rifles": Vector2i(0, 1),
	&"attack_helicopter": Vector2i(7, 2),
	&"bearer_bonds": Vector2i(7, 9),
	&"biosafety_cabinet": Vector2i(6, 6),
	&"blood_diamonds": Vector2i(5, 7),
	&"burner_phones": Vector2i(1, 3),
	&"burner_sims": Vector2i(2, 3),
	&"card_cloner": Vector2i(5, 3),
	&"catalytic_converters": Vector2i(9, 4),
	&"chemical_vials": Vector2i(2, 6),
	&"chip_kits": Vector2i(0, 4),
	&"classic_car_title": Vector2i(0, 9),
	&"clone_plates": Vector2i(3, 5),
	&"combat_shotgun": Vector2i(6, 0),
	&"combat_stims": Vector2i(1, 6),
	&"counterfeit_bills": Vector2i(2, 7),
	&"couture_trunk": Vector2i(8, 8),
	&"crate_12gauge": Vector2i(8, 0),
	&"crate_556": Vector2i(3, 1),
	&"crate_762": Vector2i(1, 1),
	&"crypto_seed": Vector2i(1, 9),
	&"diamond_collection": Vector2i(6, 7),
	&"duffel_bag": Vector2i(6, 5),
	&"ecu_chips": Vector2i(7, 4),
	&"electron_microscope": Vector2i(7, 6),
	&"emerald_parure": Vector2i(8, 7),
	&"encrypted_drives": Vector2i(1, 4),
	&"encrypted_radios": Vector2i(3, 3),
	&"enriched_uranium": Vector2i(6, 2),
	&"fake_ids": Vector2i(9, 6),
	&"fighter_jet": Vector2i(8, 2),
	&"forged_papers": Vector2i(1, 7),
	&"gene_editing_kit": Vector2i(8, 6),
	&"ghost_passports": Vector2i(0, 7),
	&"ghost_pistol": Vector2i(1, 0),
	&"gold_bars": Vector2i(3, 7),
	&"gps_jammer": Vector2i(6, 3),
	&"grand_cru_cellar": Vector2i(7, 8),
	&"imperial_egg": Vector2i(4, 8),
	&"insulin_cases": Vector2i(3, 6),
	&"jewellers_loupe": Vector2i(9, 5),
	&"kevlar_vest": Vector2i(8, 1),
	&"lab_reagents": Vector2i(5, 6),
	&"machete": Vector2i(0, 0),
	&"masterpiece_painting": Vector2i(9, 7),
	&"messenger_bag": Vector2i(5, 5),
	&"micro_uzis": Vector2i(5, 0),
	&"military_c4": Vector2i(0, 2),
	&"missile_guidance": Vector2i(5, 2),
	&"modern_canvas": Vector2i(0, 8),
	&"narco_sub": Vector2i(9, 2),
	&"network_tap": Vector2i(8, 3),
	&"night_vision": Vector2i(9, 1),
	&"nuclear_warhead": Vector2i(3, 2),
	&"offshore_access": Vector2i(2, 9),
	&"old_master_sketches": Vector2i(3, 8),
	&"pink_diamond": Vector2i(7, 7),
	&"pistol_45": Vector2i(3, 0),
	&"platinum_bars": Vector2i(4, 7),
	&"pocket_scale": Vector2i(8, 5),
	&"police_scanner": Vector2i(4, 3),
	&"racehorse_papers": Vector2i(3, 9),
	&"ransomware_kit": Vector2i(3, 4),
	&"rare_sculpture": Vector2i(1, 8),
	&"rare_watches": Vector2i(5, 8),
	&"rifle_ar15": Vector2i(2, 1),
	&"rpg_7": Vector2i(1, 2),
	&"rpg_rockets": Vector2i(2, 2),
	&"safehouse_lockbox": Vector2i(9, 9),
	&"scooter": Vector2i(4, 5),
	&"sealed_crate": Vector2i(8, 9),
	&"server_blade": Vector2i(4, 4),
	&"server_rack": Vector2i(5, 4),
	&"shell_company": Vector2i(6, 9),
	&"signal_interceptor": Vector2i(7, 3),
	&"silenced_smg": Vector2i(9, 0),
	&"smuggler_van": Vector2i(7, 5),
	&"sniper_rifle": Vector2i(4, 1),
	&"sports_car_engine": Vector2i(2, 5),
	&"stealth_drone": Vector2i(0, 3),
	&"storage_array": Vector2i(6, 4),
	&"street_meds": Vector2i(0, 6),
	&"superyacht_papers": Vector2i(4, 9),
	&"swiss_ledgers": Vector2i(9, 8),
	&"treasury_bonds": Vector2i(5, 9),
	&"turbo_kits": Vector2i(8, 4),
	&"vaccine_cooler": Vector2i(4, 6),
	&"vault_keys": Vector2i(9, 3),
	&"vintage_watches": Vector2i(6, 8),
	&"warhead_trigger": Vector2i(4, 2),
	&"zero_day_drive": Vector2i(2, 4),
	&"ak47": Vector2i(0, 1),
	&"burner_phone": Vector2i(1, 3),
	&"catalytic_converter": Vector2i(9, 4),
	&"emerald_necklace": Vector2i(8, 7),
	&"encrypted_drive": Vector2i(1, 4),
	&"fake_cash": Vector2i(2, 7),
	&"micro_uzi": Vector2i(5, 0),
	&"rims": Vector2i(0, 5),
	&"signal_jammer": Vector2i(6, 3),
	&"street_scooter": Vector2i(4, 5),
	&"swiss_ledger": Vector2i(9, 8),
	&"tuned_ecu": Vector2i(7, 4),
	&"turbo_kit": Vector2i(8, 4),
	&"uncut_diamonds": Vector2i(5, 7),
	&"vials": Vector2i(2, 6),
}

static var _atlas_texture: Texture2D
static var _cached_textures: Dictionary = {}


static func get_atlas_texture() -> Texture2D:
	if _atlas_texture != null:
		return _atlas_texture

	var global_path := ProjectSettings.globalize_path(ATLAS_PATH)
	if FileAccess.file_exists(global_path):
		var img := Image.load_from_file(global_path)
		if img != null:
			_atlas_texture = ImageTexture.create_from_image(img)

	if _atlas_texture == null and ResourceLoader.exists(ATLAS_PATH):
		_atlas_texture = load(ATLAS_PATH)

	return _atlas_texture


static func has_item(item_id: StringName) -> bool:
	return ITEM_COORDINATES.has(item_id)


static func get_coordinates(item_id: StringName) -> Vector2i:
	return ITEM_COORDINATES.get(item_id, Vector2i(0, 0))


static func get_region(item_id: StringName) -> Rect2:
	var coords: Vector2i = get_coordinates(item_id)
	return Rect2(coords.x * TILE_SIZE, coords.y * TILE_SIZE, TILE_SIZE, TILE_SIZE)


static func get_icon(item_id: StringName) -> AtlasTexture:
	if _cached_textures.has(item_id):
		return _cached_textures[item_id]

	var coords: Vector2i = get_coordinates(item_id)
	var atlas_tex := AtlasTexture.new()
	atlas_tex.atlas = get_atlas_texture()
	atlas_tex.region = Rect2(coords.x * TILE_SIZE, coords.y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
	_cached_textures[item_id] = atlas_tex
	return atlas_tex
