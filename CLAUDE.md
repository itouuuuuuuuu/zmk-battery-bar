# CLAUDE.md

## Language

All code, comments, UI strings, plist values, commit messages, and documentation in this project must be written in **English**. Never use Japanese or any other non-English language in source files.

## Project Overview

A macOS menu bar app that displays battery levels from ZMK split keyboards via BLE.

- **Language**: Swift 6 (`swiftLanguageMode(.v6)` — strict concurrency is enforced; UI-adjacent types are `@MainActor`)
- **UI**: AppKit (NSStatusItem + NSPanel) + SwiftUI (panel content, status bar rendering)
- **BLE**: CoreBluetooth
- **Build**: Swift Package Manager (no Xcode project)
- **Target**: macOS 14+ (Sonoma)

## Build, Test & Run

```sh
swift build              # Debug build
swift test               # Run unit tests
./scripts/build-app.sh   # Release .app bundle (universal binary, ad-hoc signed by default)
```

CI (`.github/workflows/test.yml`) runs `swift build` and `swift test` on macos-15 for every push to main and every PR. Always run `swift test` before opening a PR.

### Running for manual verification

To actually see the app (menu bar icon + panel) and exercise BLE, launch
the **`.app` bundle**, not the raw binary:

```sh
pkill -f ZMKBatteryBar            # stop any running instance first
./scripts/build-app.sh            # produces build/ZMK Battery Bar.app
open "build/ZMK Battery Bar.app"  # launch; icon appears in the menu bar
```

Do **not** rely on `swift run ZMKBatteryBar` (or running `.build/.../ZMKBatteryBar`
directly) for UI/BLE verification: the raw executable has no `Info.plist`, so
the `.accessory` status-bar icon does not reliably appear and CoreBluetooth
permission handling is unstable. The bundle ships `Resources/Info.plist` and is
code-signed, which the menu bar icon and BLE access need.

Notes:
- It is a menu bar (`.accessory`) app — there is no Dock icon or window; look
  in the menu bar (may be hidden behind the notch on MacBooks).
- The bundle reads/writes its own `UserDefaults` domain, separate from
  `swift run`, so saved keyboards may differ between the two launch methods.

## Architecture

- `Sources/ZMKBatteryBar/Main.swift` - Entry point (`.accessory` activation policy)
- `Sources/ZMKBatteryBar/App/AppDelegate.swift` - NSStatusItem, status bar panel, render timer
- `Sources/ZMKBatteryBar/BLE/`
  - `BLEManager.swift` - CoreBluetooth central: scanning, connection, reconnect, battery notifications
  - `BatteryStateComposer.swift`, `BatteryPayload.swift`, `DescriptorRoleParser.swift`, `RoleAssigner.swift`, `ReconnectBackoff.swift` - pure logic extracted from BLEManager (see Testing)
- `Sources/ZMKBatteryBar/Views/` - SwiftUI: `StatusBarView` (menu bar content), `MenuContentView` (panel), `KeyboardListView` (scan/save/manage keyboards), `BatteryIconView` (pixel-snapped battery icon)
- `Sources/ZMKBatteryBar/Models/` - `BatteryState` (@Observable), `AppSettings` (UserDefaults-backed), `KeyboardDevice` (saved keyboard + label config), `PanelNavigation`
- `Sources/ZMKBatteryBar/Utilities/` - `LaunchAtLogin` (SMAppService), `StatusBarLayout`, `TimeAgoFormatter`

### ZMK/BLE domain notes

- A ZMK split keyboard exposes **one** BLE peripheral (the central half). Its
  Battery Service carries multiple Battery Level characteristics: one for the
  central half and one per peripheral half.
- Which characteristic belongs to which half is inferred from the
  Characteristic User Description descriptor (0x2901, parsed by
  `DescriptorRoleParser`), falling back to positional inference
  (`RoleAssigner`) when descriptors are missing or unreadable.
- `BatteryState.defaultStaleThreshold` (120 s) marks readings stale after two
  missed polls.

## Testing

CoreBluetooth is not unit-testable, so BLE/UI logic that can be expressed as a
pure function lives in small standalone enums/structs (`BatteryStateComposer`,
`RoleAssigner`, `DescriptorRoleParser`, `ReconnectBackoff`, `BatteryPayload`,
`StatusBarLayout`, `BatteryIconLayout`, `TimeAgoFormatter`) with tests under
`Tests/ZMKBatteryBarTests/` mirroring the source layout. When adding logic to
`BLEManager` or views, prefer extracting it into a testable helper the same way.

`AppSettings` accepts an injected `UserDefaults` so tests can use an isolated
suite.

## Workflow

- Never commit directly to `main`; create a feature branch and open a PR.
- Commit messages use conventional prefixes (`feat:`, `fix:`, `docs:`, `chore:`).

## Release

Releases are driven by tags (`.github/workflows/release.yml`):

1. On a `release/vX.Y.Z` branch, bump `CFBundleVersion` and
   `CFBundleShortVersionString` in `Resources/Info.plist` (commit:
   `Bump version to X.Y.Z`), then merge via PR.
2. Push tag `vX.Y.Z`. The workflow builds a universal binary, signs it with the
   Developer ID certificate, notarizes it (`scripts/notarize.sh`), creates the
   GitHub Release with a zip asset, and updates the Homebrew cask at
   `itouuuuuuuuu/homebrew-tap` (`Casks/zmk-battery-bar.rb`).

`scripts/release.sh <version> [signing-identity]` performs the same steps
locally; `scripts/build-app.sh [signing-identity] [version]` builds and signs
the bundle only.
