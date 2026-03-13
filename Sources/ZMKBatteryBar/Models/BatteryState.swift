import Foundation
import Observation

@Observable
final class BatteryState {
  var centralLevel: Int? = nil
  var peripheralLevel: Int? = nil
  var centralConnected: Bool = false
  var peripheralConnected: Bool = false
  var lastUpdated: Date? = nil

  var timeSinceUpdate: String? {
    guard let lastUpdated else { return nil }
    let elapsed = Date().timeIntervalSince(lastUpdated)
    let seconds = Int(elapsed)

    if seconds < 60 {
      return "\(seconds)s ago"
    } else if seconds < 3600 {
      let minutes = seconds / 60
      return "\(minutes)m ago"
    } else {
      let hours = seconds / 3600
      return "\(hours)h ago"
    }
  }
}
