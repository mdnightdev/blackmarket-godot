# BLACK MARKET

An offline street-trading game for Android, built with Godot 4.3.

Pick a character, borrow from the Shark, and work six districts of a divided city. Buy low, sell high, keep the heat down and pay off the debt before it buries you. Once the loan is cleared, build a crew, take turf from Vex and run the city.

Current version: **0.14.0**

## Features

- **Trading:** contraband across six districts (The Slums, Old Market, The Docks, Warehouse Row, Downtown, North Port), with prices that shift by district, time of day and street events. Haggle with dealers, buy price intel and grow your bag.
- **Heat and police:** every deal draws attention. Police stops, shakedowns and raids get worse as heat climbs.
- **The loan:** the Shark's debt grows with interest. Miss payments and his enforcers come calling.
- **Jobs:** bar orders, family favours, smuggling crates, hijacks and daily tasks, all tracked on the Jobs page with deadline reminders.
- **Venues:** bar, casino, docks and fixer, spread across the districts.
- **Turf:** hold a district to open your safehouse and cash box. Level up held districts, and deal with Vex's gates and hunts.
- **Career:** after the loan is paid, earn street cred ranks and unlock crew, heists, businesses, skills and family trust.
- **Characters:** six playable characters (Kade, Mira, Jin, Sasha, Tariq, Yuna), each with a portrait and talk animation.
- **Fully offline:** no accounts, no network, saves stored on the device.

## Project layout

```
project/
  data/        Game content as .tres resources (districts, items, dealers, families, crew, heists, businesses, players)
  scripts/
    core/      Autoloads: GameState, Content, SceneRouter, GameOverlay, AudioService, Settings
    defs/      Resource definitions for the data files
    systems/   Game rules as static modules (market, trade, heat, loan, turf, vex, crew, heists, ...)
  ui/          Screens, sheets, components and shaders
  assets/      Art, icons, fonts and audio
  tests/unit/  GUT unit tests
tools/         Screenshot capture, balance bot and asset helper scripts
```

## Requirements

- Godot 4.3 stable (GL Compatibility renderer)
- Android SDK build-tools (`apksigner`, `aapt2`) for exporting
- A release keystore

## Running

Open the `project/` folder in Godot 4.3 and press Play. The game targets 720x1280 portrait.

## Tests

From `project/`:

```bash
godot --headless -s addons/gut/gut_cmdln.gd
```

## Exporting the Android APK

Keystore credentials are passed through environment variables at export time. Never write them into `export_presets.cfg`.

From `project/`:

```bash
GODOT_ANDROID_KEYSTORE_RELEASE_PATH="/path/to/release.keystore" \
GODOT_ANDROID_KEYSTORE_RELEASE_USER="<alias>" \
GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="<password>" \
godot --headless --export-release "Android" ../build/blackmarket.apk
```

Verify the signature with:

```bash
apksigner verify ../build/blackmarket.apk
```

## License

Proprietary. Copyright (c) 2026 mdnightdev. All rights reserved. See [LICENSE](LICENSE).
