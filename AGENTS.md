# AGENTS.md

Shared instructions for all AI coding agents working on this repository
(Claude Code, Codex, etc.). `CLAUDE.md` imports this file and adds
Claude-specific instructions on top.

## Language

All code, comments, UI strings, plist values, commit messages, and
documentation in this project must be written in **English**. Never use
Japanese or any other non-English language in the repository's files.

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
- Battery levels are fundamentally **push-based** (notifications); the 60 s poll
  is only a safety net. Read `.claude/rules/ble-domain-knowledge.md` before
  changing anything about polling, staleness, role detection, or how missing
  battery data is handled.

## Testing

CoreBluetooth is not unit-testable, so BLE/UI logic that can be expressed as a
pure function lives in small standalone enums/structs (`BatteryStateComposer`,
`RoleAssigner`, `DescriptorRoleParser`, `ReconnectBackoff`, `BatteryPayload`,
`StatusBarLayout`, `BatteryIconLayout`, `TimeAgoFormatter`) with tests under
`Tests/ZMKBatteryBarTests/` mirroring the source layout. When adding logic to
`BLEManager` or views, prefer extracting it into a testable helper the same way.

`AppSettings` accepts an injected `UserDefaults` so tests can use an isolated
suite.

### BLE state-machine invariants

When touching `BLEManager`, keep these in mind — every one of them has already
been the subject of a real bug:

- **Reconnect backoff is reset on transport-level success** (`didConnect`), and
  on the explicit user actions `connect(peripheral:)` and `disconnect()`. Never
  make the reset depend on discovery completing: a keyboard that connects and
  then deep-sleeps before discovery finishes would ratchet the delay to the
  300 s cap forever, and a user connecting to a *new* keyboard would inherit the
  previous keyboard's inflated delay.
- **Discovery failure has its own counter** (`discoveryFailureStreak`) feeding
  `ReconnectBackoff.delay(forConsecutiveFailures:initial:cap:)`, kept separate
  from the transport-level delay.
- **Judge discovery outcomes per connection, not per service.** A peripheral can
  expose more than one Battery Service instance. Wait for all
  characteristic-discovery callbacks (`pendingCharacteristicDiscoveries`) and
  tear the connection down only when *no* characteristic was found at all.
- **Session reset state lives in one place.** The
  `stopPollingTimer` / `resetCharacteristicState` / `batteryState.reset` triple
  must not be duplicated across recovery paths — duplicating it caused both
  double `@Observable` invalidation and drift between paths.
- Log discovery errors **before** any identity guard, otherwise errors for
  superseded peripherals are silently swallowed — exactly the flakiness class
  these code paths exist to diagnose.

## Workflow

- Never commit directly to `main`; create a feature branch and open a PR.
- Commit messages use conventional prefixes (`feat:`, `fix:`, `docs:`, `chore:`).
- Run `swift test` before pushing. The full suite is fast (~90 tests).
- Do not merge a PR unless explicitly asked to.
- After a merge: `git checkout main && git pull`, and delete the merged branch.
- Cross-check non-trivial review findings with a second agent before acting on
  them — see `.claude/rules/review-and-release.md`.

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

## Detailed rules

Read the relevant file before doing that kind of work:

- `.claude/rules/ble-domain-knowledge.md` — ZMK firmware and BLE facts the
  implementation depends on (push vs. poll semantics, split proxying, GATT
  caching, causes of a legitimate 0% reading).
- `.claude/rules/review-and-release.md` — the review / cross-check / fix /
  release loop this project uses.
