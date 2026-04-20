import Foundation

struct PeripheralBatterySnapshot: Equatable {
  var level: Int?
  var connected: Bool
}

struct BatteryStateSnapshot: Equatable {
  var centralLevel: Int?
  var centralConnected: Bool
  var peripherals: [PeripheralBatterySnapshot]

  /// True iff at least one side has a (role, level) pair. Callers use this to
  /// decide whether to refresh the `lastUpdated` timestamp.
  var shouldUpdateTimestamp: Bool {
    centralConnected || peripherals.contains { $0.connected }
  }

  /// First peripheral's level — backward-compat helper for tests.
  var peripheralLevel: Int? { peripherals.first?.level }
  /// First peripheral's connected state.
  var peripheralConnected: Bool { peripherals.first?.connected ?? false }
}

enum BatteryStateComposer {
  static func compose<Key: Hashable>(
    allCharacteristics: [Key],
    roles: [Key: DeviceRole],
    levels: [Key: Int]
  ) -> BatteryStateSnapshot {
    var centralLevel: Int?
    var centralConnected = false
    var peripheralLevels: [(level: Int?, connected: Bool)] = []

    for key in allCharacteristics {
      guard let role = roles[key] else { continue }
      let level = levels[key]
      switch role {
      case .central:
        centralLevel = level
        centralConnected = level != nil
      case .peripheral:
        peripheralLevels.append((level: level, connected: level != nil))
      }
    }

    return BatteryStateSnapshot(
      centralLevel: centralLevel,
      centralConnected: centralConnected,
      peripherals: peripheralLevels.map { PeripheralBatterySnapshot(level: $0.level, connected: $0.connected) }
    )
  }
}
