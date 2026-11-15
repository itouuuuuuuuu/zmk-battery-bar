import Foundation
import Observation

/// Latest status from a keyboard running the zmk-host-status firmware
/// module. `isAvailable` stays false for keyboards without the module, and
/// every consumer treats that as "show batteries only".
@Observable
final class HostStatusState {
  var isAvailable: Bool = false
  var layerNames: [String] = []
  var status: HostStatus? = nil
  var buildID: String? = nil

  func reset() {
    isAvailable = false
    layerNames = []
    status = nil
    buildID = nil
  }
}
