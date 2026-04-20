import Foundation
import Observation

struct PeripheralBattery: Identifiable, Equatable {
  let index: Int
  var level: Int?
  var connected: Bool

  var id: Int { index }
}

@Observable
final class BatteryState {
  var centralLevel: Int? = nil
  var centralConnected: Bool = false
  var peripherals: [PeripheralBattery] = []
  var lastUpdated: Date? = nil

  /// First peripheral's level — used by StatusBarView for backward compat.
  var peripheralLevel: Int? { peripherals.first?.level }
  /// First peripheral's connected state.
  var peripheralConnected: Bool { peripherals.first?.connected ?? false }

  func reset() {
    centralLevel = nil
    centralConnected = false
    peripherals = []
    lastUpdated = nil
  }
}
