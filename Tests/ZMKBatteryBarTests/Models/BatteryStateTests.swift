import Foundation
import Testing

@testable import ZMKBatteryBar

@Suite("BatteryState")
@MainActor
struct BatteryStateTests {
  @Test("starts with nil levels and disconnected")
  func initialState() {
    let state = BatteryState()

    #expect(state.centralLevel == nil)
    #expect(state.peripheralLevel == nil)
    #expect(state.centralConnected == false)
    #expect(state.peripheralConnected == false)
    #expect(state.lastUpdated == nil)
  }

  @Test("properties are mutable and readable")
  func mutability() {
    let state = BatteryState()
    let now = Date()

    state.centralLevel = 80
    state.peripheralLevel = 50
    state.centralConnected = true
    state.peripheralConnected = true
    state.lastUpdated = now

    #expect(state.centralLevel == 80)
    #expect(state.peripheralLevel == 50)
    #expect(state.centralConnected == true)
    #expect(state.peripheralConnected == true)
    #expect(state.lastUpdated == now)
  }
}
