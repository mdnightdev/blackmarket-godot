import os
import json
import collections
from PIL import Image, ImageDraw

def strip_bg(im: Image.Image, tolerance: float = 24.0) -> Image.Image:
    im = im.convert("RGB")
    w, h = im.size
    pixels = im.load()

    # 1. Establish background reference from outer perimeter
    border_samples = []
    step_x = max(1, w // 40)
    step_y = max(1, h // 40)
    for x in range(0, w, step_x):
        border_samples.append(pixels[x, 0])
        border_samples.append(pixels[x, h - 1])
    for y in range(0, h, step_y):
        border_samples.append(pixels[0, y])
        border_samples.append(pixels[w - 1, y])

    bg_r = sum(c[0] for c in border_samples) // len(border_samples)
    bg_g = sum(c[1] for c in border_samples) // len(border_samples)
    bg_b = sum(c[2] for c in border_samples) // len(border_samples)
    bg_ref = (bg_r, bg_g, bg_b)

    # 2. BFS floodfill from outer borders inward
    mask = bytearray(w * h)
    queue = collections.deque()

    for x in range(w):
        for y in (0, h - 1):
            c = pixels[x, y]
            dist = ((c[0] - bg_ref[0])**2 + (c[1] - bg_ref[1])**2 + (c[2] - bg_ref[2])**2) ** 0.5
            if dist <= tolerance + 10.0:
                mask[y * w + x] = 1
                queue.append((x, y))
            else:
                mask[y * w + x] = 2

    for y in range(h):
        for x in (0, w - 1):
            if mask[y * w + x] == 0:
                c = pixels[x, y]
                dist = ((c[0] - bg_ref[0])**2 + (c[1] - bg_ref[1])**2 + (c[2] - bg_ref[2])**2) ** 0.5
                if dist <= tolerance + 10.0:
                    mask[y * w + x] = 1
                    queue.append((x, y))
                else:
                    mask[y * w + x] = 2

    while queue:
        cx, cy = queue.popleft()
        for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
            if 0 <= nx < w and 0 <= ny < h and mask[ny * w + nx] == 0:
                c = pixels[nx, ny]
                dist = ((c[0] - bg_ref[0])**2 + (c[1] - bg_ref[1])**2 + (c[2] - bg_ref[2])**2) ** 0.5
                if dist <= tolerance:
                    mask[ny * w + nx] = 1
                    queue.append((nx, ny))
                else:
                    mask[ny * w + nx] = 2

    # 3. Create RGBA with soft 1px anti-aliased edge
    rgba = im.convert("RGBA")
    rgba_pixels = rgba.load()

    for y in range(h):
        for x in range(w):
            if mask[y * w + x] == 1:
                rgba_pixels[x, y] = (0, 0, 0, 0)
            elif mask[y * w + x] == 2:
                c = pixels[x, y]
                dist = ((c[0] - bg_ref[0])**2 + (c[1] - bg_ref[1])**2 + (c[2] - bg_ref[2])**2) ** 0.5
                if dist < tolerance + 10.0:
                    factor = max(0.0, min(1.0, (dist - tolerance) / 10.0))
                    alpha = int(255 * factor)
                    rgba_pixels[x, y] = (c[0], c[1], c[2], alpha)

    return rgba

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

if __name__ == "__main__":
    src_dir = "/root/termux/games/godot/project/assets/items/props_54"
    trans_dir = "/root/termux/games/godot/project/assets/items/props_transparent"
    os.makedirs(trans_dir, exist_ok=True)

    print(f"1. Stripping backgrounds for {len(slots)} props...")
    processed = 0
    for item_id, filename in slots:
        src = os.path.join(src_dir, filename)
        trans_file = os.path.splitext(filename)[0] + ".png"
        trans_path = os.path.join(trans_dir, trans_file)

        if not os.path.exists(trans_path):
            if os.path.exists(src):
                im = Image.open(src)
                stripped = strip_bg(im)
                stripped.save(trans_path, "PNG")
                processed += 1
                if processed % 10 == 0:
                    print(f"  Processed {processed}/{len(slots)} items...")
            else:
                print(f"  Warning: source {src} not found!")

    print("All transparent props ready. Baking 100-tile master atlas with square frames...")

    COLS = 10
    ROWS = 10
    TILE = 128

    # Canvas: pure matte dark slate (#111318)
    atlas = Image.new("RGBA", (COLS * TILE, ROWS * TILE), color=(17, 19, 24, 255))
    draw = ImageDraw.Draw(atlas)

    FRAME_COLOR = (46, 53, 66, 255)  # Crisp 1px square border (#2e3542)

    for idx, (item_id, filename) in enumerate(slots):
        col = idx % COLS
        row = idx // COLS
        x0 = col * TILE
        y0 = row * TILE
        x1 = x0 + TILE - 1
        y1 = y0 + TILE - 1

        # 1. Draw sharp square frame border (zero rounded corners)
        draw.rectangle([x0, y0, x1, y1], outline=FRAME_COLOR, width=1)

        # 2. Paste the transparent prop inside the slot with slight inset
        trans_file = os.path.splitext(filename)[0] + ".png"
        trans_path = os.path.join(trans_dir, trans_file)

        if os.path.exists(trans_path):
            prop_img = Image.open(trans_path).convert("RGBA")
            # Inset by 6px inside the frame
            INNER = TILE - 12
            resized_prop = prop_img.resize((INNER, INNER), Image.Resampling.LANCZOS)
            atlas.paste(resized_prop, (x0 + 6, y0 + 6), resized_prop)

    # Save Standard Atlas
    atlas_proj = "/root/termux/games/godot/project/assets/items/items_atlas.png"
    atlas.save(atlas_proj, "PNG")
    print(f"Saved standard atlas: {atlas_proj}")

    # Copy to device download
    dl_dir = "/storage/emulated/0/Download/black_market_props"
    os.makedirs(dl_dir, exist_ok=True)
    atlas.save(os.path.join(dl_dir, "black_market_atlas_100.png"), "PNG")
    atlas.save("/storage/emulated/0/Download/black_market_atlas_100.png", "PNG")
    print("Saved device atlas: /storage/emulated/0/Download/black_market_atlas_100.png")

    # HD Atlas (512x512 per tile)
    HD_TILE = 512
    hd_atlas = Image.new("RGBA", (COLS * HD_TILE, ROWS * HD_TILE), color=(17, 19, 24, 255))
    hd_draw = ImageDraw.Draw(hd_atlas)

    for idx, (item_id, filename) in enumerate(slots):
        col = idx % COLS
        row = idx // COLS
        x0 = col * HD_TILE
        y0 = row * HD_TILE
        x1 = x0 + HD_TILE - 1
        y1 = y0 + HD_TILE - 1

        hd_draw.rectangle([x0, y0, x1, y1], outline=FRAME_COLOR, width=2)

        trans_file = os.path.splitext(filename)[0] + ".png"
        trans_path = os.path.join(trans_dir, trans_file)

        if os.path.exists(trans_path):
            prop_img = Image.open(trans_path).convert("RGBA")
            INNER_HD = HD_TILE - 24
            resized_prop = prop_img.resize((INNER_HD, INNER_HD), Image.Resampling.LANCZOS)
            hd_atlas.paste(resized_prop, (x0 + 12, y0 + 12), resized_prop)

    hd_atlas.save(os.path.join(dl_dir, "black_market_atlas_100_hd.png"), "PNG")
    hd_atlas.save("/storage/emulated/0/Download/black_market_atlas_100_hd.png", "PNG")
    print("Saved HD atlas: /storage/emulated/0/Download/black_market_atlas_100_hd.png")
