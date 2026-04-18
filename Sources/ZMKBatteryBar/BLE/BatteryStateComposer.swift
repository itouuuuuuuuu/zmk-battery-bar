import Foundation

struct BatteryStateSnapshot: Equatable {
  var centralLevel: Int?
  var peripheralLevel: Int?
  var centralConnected: Bool
  var peripheralConnected: Bool

  /// True iff at least one side has a (role, level) pair. Callers use this to
  /// decide whether to refresh the `lastUpdated` timestamp.
  var shouldUpdateTimestamp: Bool {
    centralConnected || peripheralConnected
  }
}

enum BatteryStateComposer {
  static func compose<Key: Hashable>(
    allCharacteristics: [Key],
    roles: [Key: DeviceRole],
    levels: [Key: Int]
  ) -> BatteryStateSnapshot {
    var central: Int?
    var peripheral: Int?
    var centralConnected = false
    var peripheralConnected = false

    for key in allCharacteristics {
      guard let role = roles[key], let level = levels[key] else { continue }
      switch role {
      case .central:
        central = level
        centralConnected = true
      case .peripheral:
        peripheral = level
        peripheralConnected = true
      }
    }

    return BatteryStateSnapshot(
      centralLevel: central,
      peripheralLevel: peripheral,
      centralConnected: centralConnected,
      peripheralConnected: peripheralConnected
    )
  }
}
