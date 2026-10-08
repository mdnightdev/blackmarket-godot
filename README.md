# BLACK MARKET

An offline street-trading game for Android, built with Godot 4.3.

Pick a character, start out owing the Shark $100,000 and work six districts of a divided city. Run his errands, broker deals for street customers, keep the heat down and make the weekly payment. Once the debt is cleared, build a crew, take turf from Vex and run the city.

Current version: **0.16.0**. See [CHANGELOG.md](CHANGELOG.md).

## Features

- **Trading:** contraband across six districts (The Slums, Old Market, The Docks, Warehouse Row, Downtown, North Port), with prices that shift by district, time of day and street events. Haggle with dealers, buy price intel and grow your bag.
- **Heat and police:** every deal draws attention. Police stops, shakedowns and raids get worse as heat climbs.
- **The debt:** you owe the Shark $100,000 and pay a weekly minimum. Miss a week and his enforcers come calling. Miss three in a row and the run is over.
- **Phone offers:** the Shark's errands and customer orders slide in as banners. Accept, and the game offers the trip to the job.
- **Customers:** street customers order goods by phone. Sell from your bag or broker the deal, with a quote list that shows where to buy, the fares and your profit.
- **Jobs:** bar orders, family favours, smuggling crates, hijacks and daily tasks, all tracked on the Jobs page with deadline reminders.
- **Venues:** bar, casino, docks and fixer, spread across the districts.
- **Turf:** hold a district to open your safehouse and cash box. Level up held districts, and deal with Vex's gates and hunts.
- **Career:** after the loan is paid, earn street cred ranks and unlock crew, heists, businesses, skills and family trust.
- **Characters:** six playable characters (Kade, Mira, Jin, Sasha, Tariq, Yuna), each with a portrait and talk animation.
- **Fully offline:** no accounts, no network, saves stored on the device.

## Beta testing

1. Open the [Releases](https://github.com/mdnightdev/blackmarket-godot/releases) page and download the APK from the newest release. Test builds are marked Pre-release.
2. On the phone, allow installs from your browser or file manager when Android asks, then open the APK.
3. To update, install the newer APK over the old one. Saves are kept.

Report bugs with the version from the title screen, what you did and what happened.

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

## Releases

Pushing a version tag builds a signed APK on GitHub Actions and publishes it as a GitHub release (`.github/workflows/release.yml`). The workflow runs the unit tests first and stops if the tag does not match `version/name` in `export_presets.cfg`.

One-time setup, under Settings, Secrets and variables, Actions:

- `ANDROID_KEYSTORE_BASE64`: the release keystore, encoded with `base64 -w0 release.keystore`
- `ANDROID_KEYSTORE_ALIAS`: the key alias
- `ANDROID_KEYSTORE_PASSWORD`: the keystore password

To cut a release:

1. Bump `version/code` and `version/name` in `project/export_presets.cfg` and `config/version` in `project/project.godot`.
2. Add a section for the version to `CHANGELOG.md`. Its text becomes the release notes.
3. Commit, then tag and push:

```bash
git tag v0.16.0
git push origin main v0.16.0
```

Tags with a suffix, such as `v0.16.0-beta.1`, are published as pre-releases for testers.

## License

Proprietary. Copyright (c) 2026 mdnightdev. All rights reserved. See [LICENSE](LICENSE).
