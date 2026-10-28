import json, os
from PIL import Image

folder = '/root/termux/games/godot/project/assets/items/props_54'

slots = [
    # Row 0: Street Guns, Ammo & Blades (10)
    ('machete', 'machete.jpg'),
    ('ghost_pistol', 'ghost_pistol.jpg'),
    ('ammo_9mm', 'ammo_9mm.jpg'),
    ('pistol_45', 'pistol_45.jpg'),
    ('ammo_45', 'ammo_45.jpg'),
    ('micro_uzis', 'micro_uzi.jpg'),
    ('combat_shotgun', 'combat_shotgun.jpg'),
    ('ammo_12gauge', 'ammo_12gauge.jpg'),
    ('crate_12gauge', 'crate_12gauge.jpg'),
    ('silenced_smg', 'silenced_smg.jpg'),

    # Row 1: Syndicate Rifles & Defense (10)
    ('assault_rifles', 'ak47.jpg'),
    ('crate_762', 'crate_762.jpg'),
    ('rifle_ar15', 'rifle_ar15.jpg'),
    ('crate_556', 'crate_556.jpg'),
    ('sniper_rifle', 'sniper_rifle.jpg'),
    ('ammo_300blackout', 'ammo_300blackout.jpg'),
    ('anti_materiel_rifle', 'anti_materiel_rifle.jpg'),
    ('ammo_50bmg', 'ammo_50bmg.jpg'),
    ('kevlar_vest', 'kevlar_vest.jpg'),
    ('night_vision', 'night_vision.jpg'),

    # Row 2: Military Spec-Ops Ordnance (10)
    ('military_c4', 'military_c4.jpg'),
    ('rpg_7', 'rpg_7.jpg'),
    ('rpg_rockets', 'rpg_rockets.jpg'),
    ('nuclear_warhead', 'nuclear_warhead.jpg'),
    ('warhead_trigger', 'warhead_trigger.jpg'),
    ('missile_guidance', 'missile_guidance.jpg'),
    ('enriched_uranium', 'enriched_uranium.jpg'),
    ('attack_helicopter', 'attack_helicopter.jpg'),
    ('fighter_jet', 'fighter_jet.jpg'),
    ('narco_sub', 'narco_sub.jpg'),

    # Row 3: Infiltration, Comms & Tech Hardware (10)
    ('stealth_drone', 'stealth_drone.jpg'),
    ('burner_phones', 'burner_phone.jpg'),
    ('burner_sims', 'burner_sims.jpg'),
    ('encrypted_radios', 'encrypted_radios.jpg'),
    ('police_scanner', 'police_scanner.jpg'),
    ('card_cloner', 'card_cloner.jpg'),
    ('gps_jammer', 'signal_jammer.jpg'),
    ('signal_interceptor', 'signal_interceptor.jpg'),
    ('network_tap', 'network_tap.jpg'),
    ('vault_keys', 'vault_keys.jpg'),

    # Row 4: Cyber, Storage & Hardware Exploits (10)
    ('chip_kits', 'chip_kits.jpg'),
    ('encrypted_drives', 'encrypted_drive.jpg'),
    ('zero_day_drive', 'zero_day_drive.jpg'),
    ('ransomware_kit', 'ransomware_kit.jpg'),
    ('server_blade', 'server_blade.jpg'),
    ('server_rack', 'server_rack.jpg'),
    ('storage_array', 'storage_array.jpg'),
    ('ecu_chips', 'tuned_ecu.jpg'),
    ('turbo_kits', 'turbo_kit.jpg'),
    ('catalytic_converters', 'catalytic_converter.jpg'),

    # Row 5: Vehicles, Auto Parts & Transport (10)
    ('alloy_wheels', 'rims.jpg'),
    ('armored_glass', 'armored_glass.jpg'),
    ('sports_car_engine', 'sports_car_engine.jpg'),
    ('clone_plates', 'clone_plates.jpg'),
    ('scooter', 'scooter.jpg'),
    ('messenger_bag', 'messenger_bag.jpg'),
    ('duffel_bag', 'duffel_bag.jpg'),
    ('smuggler_van', 'smuggler_van.jpg'),
    ('pocket_scale', 'pocket_scale.jpg'),
    ('jewellers_loupe', 'jewellers_loupe.jpg'),

    # Row 6: Meds, Pharma & Bio-Tech (10)
    ('street_meds', 'street_meds.jpg'),
    ('combat_stims', 'combat_stims.jpg'),
    ('chemical_vials', 'chemical_vials.jpg'),
    ('insulin_cases', 'insulin_cases.jpg'),
    ('vaccine_cooler', 'vaccine_cooler.jpg'),
    ('lab_reagents', 'lab_reagents.jpg'),
    ('biosafety_cabinet', 'biosafety_cabinet.jpg'),
    ('electron_microscope', 'electron_microscope.jpg'),
    ('gene_editing_kit', 'gene_editing_kit.jpg'),
    ('fake_ids', 'fake_ids.jpg'),

    # Row 7: Passports, Currency, Gold & Gems (10)
    ('ghost_passports', 'ghost_passports.jpg'),
    ('forged_papers', 'forged_papers.jpg'),
    ('counterfeit_bills', 'fake_cash.jpg'),
    ('gold_bars', 'gold_bars.jpg'),
    ('platinum_bars', 'platinum_bars.jpg'),
    ('blood_diamonds', 'uncut_diamonds.jpg'),
    ('diamond_collection', 'diamond_collection.jpg'),
    ('pink_diamond', 'pink_diamond.jpg'),
    ('emerald_parure', 'emerald_necklace.jpg'),
    ('masterpiece_painting', 'masterpiece_painting.jpg'),

    # Row 8: Fine Art, Luxury & Timepieces (10)
    ('modern_canvas', 'modern_canvas.jpg'),
    ('rare_sculpture', 'rare_sculpture.jpg'),
    ('ancient_artifacts', 'ancient_artifacts.jpg'),
    ('old_master_sketches', 'old_master_sketches.jpg'),
    ('imperial_egg', 'imperial_egg.jpg'),
    ('rare_watches', 'rare_watches.jpg'),
    ('vintage_watches', 'vintage_watches.jpg'),
    ('grand_cru_cellar', 'grand_cru_cellar.jpg'),
    ('couture_trunk', 'couture_trunk.jpg'),
    ('swiss_ledgers', 'swiss_ledger.jpg'),

    # Row 9: High Finance, Deeds & Titles (10)
    ('classic_car_title', 'classic_car_title.jpg'),
    ('crypto_seed', 'crypto_seed.jpg'),
    ('offshore_access', 'offshore_access.jpg'),
    ('racehorse_papers', 'racehorse_papers.jpg'),
    ('superyacht_papers', 'superyacht_papers.jpg'),
    ('treasury_bonds', 'treasury_bonds.jpg'),
    ('shell_company', 'shell_company.jpg'),
    ('bearer_bonds', 'bearer_bonds.jpg'),
    ('sealed_crate', 'sealed_crate.jpg'),
    ('safehouse_lockbox', 'safehouse_lockbox.jpg')
]

COLS = 10
ROWS = 10

# 1. Standard Atlas (128x128 tiles -> 1280x1280 px)
TILE = 128
atlas = Image.new('RGB', (COLS * TILE, ROWS * TILE), color=(17, 19, 24))

mapping = {
    'atlas_path': 'res://assets/items/items_atlas.png',
    'cols': COLS,
    'rows': ROWS,
    'tile_size': TILE,
    'width': COLS * TILE,
    'height': ROWS * TILE,
    'total_slots': len(slots),
    'items': {}
}

for idx, (item_id, filename) in enumerate(slots):
    col = idx % COLS
    row = idx // COLS
    p_path = os.path.join(folder, filename)
    img = Image.open(p_path).convert('RGB').resize((TILE, TILE), Image.Resampling.LANCZOS)
    atlas.paste(img, (col * TILE, row * TILE))

    mapping['items'][item_id] = {
        'col': col,
        'row': row,
        'x': col * TILE,
        'y': row * TILE,
        'w': TILE,
        'h': TILE,
        'u': round(col / float(COLS), 4),
        'v': round(row / float(ROWS), 4),
        'uw': round(1.0 / COLS, 4),
        'vh': round(1.0 / ROWS, 4)
    }

# Save Standard Atlas
atlas_proj = '/root/termux/games/godot/project/assets/items/items_atlas.png'
atlas.save(atlas_proj, 'PNG')

dl_dir = '/storage/emulated/0/Download/black_market_props'
atlas.save(os.path.join(dl_dir, 'black_market_atlas_100.png'), 'PNG')
atlas.save('/storage/emulated/0/Download/black_market_atlas_100.png', 'PNG')
atlas.save('/root/.gemini/antigravity-cli/brain/51186342-f881-4775-b03b-d29ae1b11b52/black_market_atlas_100.png', 'PNG')
print('Saved clean Standard 100-tile atlas (2560x2560):', atlas_proj)

# 2. HD Atlas (512x512 tiles -> 5120x5120 px)
HD_TILE = 512
hd_atlas = Image.new('RGB', (COLS * HD_TILE, ROWS * HD_TILE), color=(17, 19, 24))

for idx, (item_id, filename) in enumerate(slots):
    col = idx % COLS
    row = idx // COLS
    p_path = os.path.join(folder, filename)
    img = Image.open(p_path).convert('RGB').resize((HD_TILE, HD_TILE), Image.Resampling.LANCZOS)
    hd_atlas.paste(img, (col * HD_TILE, row * HD_TILE))

hd_atlas.save(os.path.join(dl_dir, 'black_market_atlas_100_hd.png'), 'PNG')
hd_atlas.save('/storage/emulated/0/Download/black_market_atlas_100_hd.png', 'PNG')
print('Saved clean HD 100-tile atlas (5120x5120)')

# Save mapping json
json_proj = '/root/termux/games/godot/project/assets/items/items_atlas_mapping.json'
with open(json_proj, 'w') as f:
    json.dump(mapping, f, indent=2)

with open(os.path.join(dl_dir, 'items_atlas_mapping.json'), 'w') as f:
    json.dump(mapping, f, indent=2)

print('Saved items_atlas_mapping.json')
