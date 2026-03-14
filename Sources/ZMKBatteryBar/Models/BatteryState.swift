import Foundation
import Observation

@Observable
final class BatteryState {
  var centralLevel: Int? = nil
  var peripheralLevel: Int? = nil
  var centralConnected: Bool = false
  var peripheralConnected: Bool = false
  var lastUpdated: Date? = nil

}
