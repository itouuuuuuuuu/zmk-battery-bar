# zmk-battery-bar

A macOS menu bar app that displays battery levels from ZMK split keyboards via BLE.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)

## Features

- **Two-line status bar display** — Shows Central (C) and Peripheral (P) battery levels with custom-drawn battery icons
- **BLE Battery Service** — Reads battery levels via standard BLE Battery Service (0x180F) with notification subscription
- **Auto Central/Peripheral detection** — Uses BLE descriptor (User Description) to identify each half of the split keyboard
- **Multiple keyboard support** — Register and switch between multiple ZMK keyboards
- **Auto-reconnect** — Automatically reconnects with exponential backoff when the keyboard disconnects
- **Launch at Login** — Optional auto-start via SMAppService

## Requirements

- macOS 14 (Sonoma) or later
- A ZMK-powered split keyboard with BLE Battery Service enabled

## Build & Run

```sh
# Debug build and run
swift build
swift run ZMKBatteryBar

# Release .app bundle
./scripts/build-app.sh
# Output: build/ZMK Battery Bar.app
```

## Install

```sh
./scripts/build-app.sh
cp -r "build/ZMK Battery Bar.app" /Applications/
```

## Usage

1. Launch ZMK Battery Bar — it appears in the menu bar with `C` and `P` battery levels
2. Click the status bar item to open the popover
3. If no keyboard is connected, click **Add Keyboard...** to scan for BLE devices
4. Select your ZMK keyboard from the discovered devices list
5. Battery levels update automatically via BLE notifications

## Architecture

| Directory | Description |
|---|---|
| `Sources/.../App/` | Entry point, AppDelegate, NSStatusItem, NSPanel popover |
| `Sources/.../BLE/` | CoreBluetooth manager, device discovery, battery reading |
| `Sources/.../Views/` | SwiftUI views (status bar, popover, keyboard list) |
| `Sources/.../Models/` | BatteryState (@Observable), AppSettings (UserDefaults), KeyboardDevice |
| `Sources/.../Utilities/` | Launch at login (SMAppService wrapper) |

## How It Works

1. On launch, the app connects to the previously saved keyboard via `retrievePeripherals(withIdentifiers:)`
2. It discovers the BLE Battery Service (0x180F) and Battery Level Characteristic (0x2A19)
3. Descriptor `0x2901` (User Description) is read to determine Central vs Peripheral
4. Battery level notifications are subscribed to for real-time updates, with 60-second polling as fallback
5. The status bar icon is rendered as an `NSImage` using SwiftUI `ImageRenderer`

## License

MIT
