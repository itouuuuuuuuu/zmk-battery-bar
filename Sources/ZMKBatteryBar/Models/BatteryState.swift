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
  /// Default freshness window. Set to twice the BLE polling interval so a
  /// single missed poll does not trigger stale display.
  static let defaultStaleThreshold: TimeInterval = 120

  var centralLevel: Int? = nil
  var centralConnected: Bool = false
  var peripherals: [PeripheralBattery] = []
  var lastUpdated: Date? = nil

  /// First peripheral's level — used by StatusBarView for backward compat.
  var peripheralLevel: Int? { peripherals.first?.level }
  /// First peripheral's connected state.
  var peripheralConnected: Bool { peripherals.first?.connected ?? false }

  /// Returns true when the most recent successful battery read is older than
  /// `threshold`, or when no read has happened yet. Callers use this to fall
  /// back to a `--` display when CoreBluetooth has not surfaced a disconnect
  /// but the keyboard has stopped responding (out of range, powered off, etc.).
  func isStale(now: Date = Date(), threshold: TimeInterval = defaultStaleThreshold) -> Bool {
    guard let lastUpdated else { return true }
    return now.timeIntervalSince(lastUpdated) > threshold
  }

  func reset() {
    centralLevel = nil
    centralConnected = false
    peripherals = []
    lastUpdated = nil
  }
}
