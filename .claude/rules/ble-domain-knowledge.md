# ZMK BLE domain knowledge

Firmware- and protocol-level facts this app's implementation depends on.
Verified in past investigations; correct them if new evidence appears.

## Battery data flow

- Battery levels are **push-based**: the app subscribes to notifications on the
  Battery Level characteristics and the firmware pushes updates when the level
  changes. The 60 s read poll is only a safety net for missed notifications and
  for stale-reading detection (`BatteryState.defaultStaleThreshold`, 120 s).
  Consequence: never treat the poll as the primary data path, and do not remove
  it without replacing stale detection.
- A read returns a **cached** value; it does not trigger a measurement. ZMK
  samples on its own schedule (`CONFIG_ZMK_BATTERY_REPORT_INTERVAL`, default
  60 s) and **only while the keyboard is in the ACTIVE state** — the timer stops
  in IDLE/SLEEP. So a level can legitimately stay unchanged for a long time
  while the keyboard is idle; that is not a bug in this app.
- Depending on the configured sensor, ZMK reports either a voltage-divider
  reading or a fuel-gauge State of Charge. Code and comments should say
  "battery level from the battery sensor", not "battery voltage".
- On a split keyboard, the peripheral half's level is relayed to the central
  half over the split link (`central_bas_proxy.c`:
  `zmk_split_central_get_peripheral_battery_level()` returns the held value).
  A read never reaches or wakes the peripheral half — a peripheral value can be
  arbitrarily stale relative to the central one.
- The app does not open its own BLE link; it shares the connection macOS
  already maintains for HID. Polling adds only a few short ATT transactions per
  minute on top of that. ZMK sets `BT_PERIPHERAL_PREF_LATENCY=30`, so an idle
  peripheral skips up to 30 connection events and a read forces it to service
  one — the incremental cost is small but not zero, and it is relatively larger
  on small-cell, mostly-idle builds. Any power claim beyond that would need real
  measurement.

## Why the app can legitimately read 0% or nothing

These are firmware/host-side causes, not app bugs. Do not add workarounds for
them in `BLEManager`.

- Split battery config changes (`CONFIG_ZMK_SPLIT_BLE_CENTRAL_BATTERY_LEVEL_PROXY`
  / `..._FETCHING`) alter the GATT layout, so both halves need the new firmware
  and the split pairing needs resetting.
- **macOS caches the GATT DB.** After any firmware change that alters the GATT
  layout, the old layout can persist until the keyboard is removed in System
  Settings → Bluetooth and re-paired. This matters for manual verification: a
  characteristic set that "should" have changed may not have.
- `nice_nano` vs `nice_nano_v2` measure the battery differently, so a v2 board
  built for the v1 target reports 0% permanently.
- A keyboard keeps running well below a reported 0%, so 0% is not necessarily a
  wrong reading.
