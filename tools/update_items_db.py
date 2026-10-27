import json

NEW_ITEMS = {
    "machete": {
        "id": "machete",
        "display_name": "Machete",
        "kind": 0,
        "category": "weapons",
        "base_price": 150,
        "risk": 10,
        "slots": 1,
        "tier": 1,
        "min_rank": 0,
        "description": "Heavy stamped carbon blade. Silent and brutal.",
        "capacity_bonus": 0,
        "fare_discount": 0.0,
        "haggle_bonus": 0.0
    },
    "pistol_45": {
        "id": "pistol_45",
        "display_name": ".45 Tactical Pistol",
        "kind": 0,
        "category": "weapons",
        "base_price": 1200,
        "risk": 20,
        "slots": 1,
        "tier": 1,
        "min_rank": 0,
        "description": "Hard-hitting semi-automatic sidearm.",
        "capacity_bonus": 0,
        "fare_discount": 0.0,
        "haggle_bonus": 0.0
    },
    "ammo_45": {
        "id": "ammo_45",
        "display_name": ".45 ACP Ammo Box",
        "kind": 0,
        "category": "arms",
        "base_price": 120,
        "risk": 14,
        "slots": 1,
        "tier": 1,
        "min_rank": 0,
        "description": "Heavy caliber cartridges for .45 sidearms.",
        "capacity_bonus": 0,
        "fare_discount": 0.0,
        "haggle_bonus": 0.0
    },
    "ammo_12gauge": {
        "id": "ammo_12gauge",
        "display_name": "12-Gauge Shells",
        "kind": 0,
        "category": "arms",
        "base_price": 100,
        "risk": 15,
        "slots": 1,
        "tier": 1,
        "min_rank": 0,
        "description": "Standard tactical buckshot shells.",
        "capacity_bonus": 0,
        "fare_discount": 0.0,
        "haggle_bonus": 0.0
    },
    "crate_12gauge": {
        "id": "crate_12gauge",
        "display_name": "12-Gauge Ammo Crate",
        "kind": 0,
        "category": "arms",
        "base_price": 900,
        "risk": 25,
        "slots": 2,
        "tier": 1,
        "min_rank": 0,
        "description": "Bulk military case of shotgun shells.",
        "capacity_bonus": 0,
        "fare_discount": 0.0,
        "haggle_bonus": 0.0
    },
    "crate_762": {
        "id": "crate_762",
        "display_name": "7.62mm Ammo Crate",
        "kind": 0,
        "category": "arms",
        "base_price": 1600,
        "risk": 30,
        "slots": 2,
        "tier": 2,
        "min_rank": 1,
        "description": "Sealed spam can crate of 7.62x39mm rifle ammo.",
        "capacity_bonus": 0,
        "fare_discount": 0.0,
        "haggle_bonus": 0.0
    },
    "rifle_ar15": {
        "id": "rifle_ar15",
        "display_name": "AR-15 Carbine",
        "kind": 0,
        "category": "weapons",
        "base_price": 3200,
        "risk": 32,
        "slots": 2,
        "tier": 2,
        "min_rank": 1,
        "description": "Custom modular 5.56 assault carbine.",
        "capacity_bonus": 0,
        "fare_discount": 0.0,
        "haggle_bonus": 0.0
    },
    "crate_556": {
        "id": "crate_556",
        "display_name": "5.56mm Ammo Crate",
        "kind": 0,
        "category": "arms",
        "base_price": 1800,
        "risk": 28,
        "slots": 2,
        "tier": 2,
        "min_rank": 1,
        "description": "NATO spec surplus 5.56x45mm ammunition crate.",
        "capacity_bonus": 0,
        "fare_discount": 0.0,
        "haggle_bonus": 0.0
    },
    "ammo_300blackout": {
        "id": "ammo_300blackout",
        "display_name": ".300 Blackout Subsonic",
        "kind": 0,
        "category": "arms",
        "base_price": 450,
        "risk": 24,
        "slots": 1,
        "tier": 2,
        "min_rank": 1,
        "description": "Subsonic rounds engineered for silenced carbines.",
        "capacity_bonus": 0,
        "fare_discount": 0.0,
        "haggle_bonus": 0.0
    },
    "ammo_50bmg": {
        "id": "ammo_50bmg",
        "display_name": ".50 BMG Heavy Ammo",
        "kind": 0,
        "category": "arms",
        "base_price": 1200,
        "risk": 35,
        "slots": 1,
        "tier": 3,
        "min_rank": 2,
        "description": "Anti-materiel armor-piercing rounds.",
        "capacity_bonus": 0,
        "fare_discount": 0.0,
        "haggle_bonus": 0.0
    },
    "kevlar_vest": {
        "id": "kevlar_vest",
        "display_name": "Kevlar Body Armor",
        "kind": 1,
        "category": "military",
        "base_price": 2500,
        "risk": 15,
        "slots": 1,
        "tier": 1,
        "min_rank": 0,
        "description": "Concealable ballistic armor vest.",
        "capacity_bonus": 0,
        "fare_discount": 0.0,
        "haggle_bonus": 0.0
    },
    "night_vision": {
        "id": "night_vision",
        "display_name": "Night Vision Goggles",
        "kind": 1,
        "category": "military",
        "base_price": 6500,
        "risk": 25,
        "slots": 1,
        "tier": 2,
        "min_rank": 1,
        "description": "Military dual-tube night vision optic system.",
        "capacity_bonus": 0,
        "fare_discount": 0.0,
        "haggle_bonus": 0.0
    },
    "military_c4": {
        "id": "military_c4",
        "display_name": "Military C4 Demolition",
        "kind": 0,
        "category": "military",
        "base_price": 9500,
        "risk": 50,
        "slots": 2,
        "tier": 3,
        "min_rank": 2,
        "description": "Plastic explosive block with electronic blasting cap.",
        "capacity_bonus": 0,
        "fare_discount": 0.0,
        "haggle_bonus": 0.0
    },
    "rpg_7": {
        "id": "rpg_7",
        "display_name": "RPG-7 Launcher",
        "kind": 0,
        "category": "military",
        "base_price": 15000,
        "risk": 55,
        "slots": 4,
        "tier": 3,
        "min_rank": 3,
        "description": "Shoulder-fired anti-armor rocket launcher.",
        "capacity_bonus": 0,
        "fare_discount": 0.0,
        "haggle_bonus": 0.0
    },
    "rpg_rockets": {
        "id": "rpg_rockets",
        "display_name": "PG-7V Warheads",
        "kind": 0,
        "category": "military",
        "base_price": 4500,
        "risk": 48,
        "slots": 2,
        "tier": 3,
        "min_rank": 2,
        "description": "High-explosive shaped-charge anti-tank rockets.",
        "capacity_bonus": 0,
        "fare_discount": 0.0,
        "haggle_bonus": 0.0
    },
    "police_scanner": {
        "id": "police_scanner",
        "display_name": "Police Scanner",
        "kind": 1,
        "category": "comms",
        "base_price": 1400,
        "risk": 15,
        "slots": 1,
        "tier": 1,
        "min_rank": 0,
        "description": "Wide-band digital receiver tuned to precinct dispatch.",
        "capacity_bonus": 0,
        "fare_discount": 0.0,
        "haggle_bonus": 0.0
    },
    "card_cloner": {
        "id": "card_cloner",
        "display_name": "RFID Card Cloner",
        "kind": 1,
        "category": "tech",
        "base_price": 2200,
        "risk": 20,
        "slots": 1,
        "tier": 1,
        "min_rank": 0,
        "description": "Handheld skimmer for duplicating keycards and badges.",
        "capacity_bonus": 0,
        "fare_discount": 0.0,
        "haggle_bonus": 0.0
    },
    "chemical_vials": {
        "id": "chemical_vials",
        "display_name": "Precursor Chemical Vials",
        "kind": 0,
        "category": "biotech",
        "base_price": 850,
        "risk": 30,
        "slots": 1,
        "tier": 2,
        "min_rank": 0,
        "description": "High-grade concentrated reagents for synthetic chemistry.",
        "capacity_bonus": 0,
        "fare_discount": 0.0,
        "haggle_bonus": 0.0
    },
    "bearer_bonds": {
        "id": "bearer_bonds",
        "display_name": "Bearer Bonds",
        "kind": 0,
        "category": "finance",
        "base_price": 48000,
        "risk": 42,
        "slots": 1,
        "tier": 3,
        "min_rank": 3,
        "description": "Untraceable physical high-denomination treasury bonds.",
        "capacity_bonus": 0,
        "fare_discount": 0.0,
        "haggle_bonus": 0.0
    },
    "sealed_crate": {
        "id": "sealed_crate",
        "display_name": "Sealed Contraband Crate",
        "kind": 0,
        "category": "tool",
        "base_price": 12000,
        "risk": 35,
        "slots": 3,
        "tier": 2,
        "min_rank": 1,
        "description": "Tamper-banded cargo container awaiting drop-off.",
        "capacity_bonus": 0,
        "fare_discount": 0.0,
        "haggle_bonus": 0.0
    },
    "safehouse_lockbox": {
        "id": "safehouse_lockbox",
        "display_name": "Safehouse Lockbox",
        "kind": 1,
        "category": "tool",
        "base_price": 8500,
        "risk": 10,
        "slots": 2,
        "tier": 2,
        "min_rank": 1,
        "description": "Biometric hardened deposit box for district safehouses.",
        "capacity_bonus": 0,
        "fare_discount": 0.0,
        "haggle_bonus": 0.0
    }
}

db_path = "/root/termux/games/godot/project/data/items_db.json"

with open(db_path, "r", encoding="utf-8") as f:
    db = json.load(f)

print(f"Current items in DB: {len(db)}")

added = 0
for item_id, item_data in NEW_ITEMS.items():
    if item_id not in db:
        db[item_id] = item_data
        added += 1

print(f"Added {added} new items to DB.")
print(f"New total items in DB: {len(db)}")

# Sort alphabetically by id for clean maintenance
sorted_db = {k: db[k] for k in sorted(db.keys())}

with open(db_path, "w", encoding="utf-8") as f:
    json.dump(sorted_db, f, indent=2)

print(f"Successfully saved {len(sorted_db)} items to {db_path}.")
