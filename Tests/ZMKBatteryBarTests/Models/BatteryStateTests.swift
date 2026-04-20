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
    #expect(state.peripherals.isEmpty)
    #expect(state.lastUpdated == nil)
  }

  @Test("properties are mutable and readable")
  func mutability() {
    let state = BatteryState()
    let now = Date()

    state.centralLevel = 80
    state.centralConnected = true
    state.peripherals = [
      PeripheralBattery(index: 0, level: 50, connected: true),
      PeripheralBattery(index: 1, level: 30, connected: true),
    ]
    state.lastUpdated = now

    #expect(state.centralLevel == 80)
    #expect(state.peripheralLevel == 50)
    #expect(state.centralConnected == true)
    #expect(state.peripheralConnected == true)
    #expect(state.peripherals.count == 2)
    #expect(state.peripherals[1].level == 30)
    #expect(state.lastUpdated == now)
  }

  @Test("computed peripheralLevel returns first peripheral")
  func computedPeripheralLevel() {
    let state = BatteryState()
    state.peripherals = [
      PeripheralBattery(index: 0, level: 60, connected: true),
      PeripheralBattery(index: 1, level: 40, connected: true),
    ]
    #expect(state.peripheralLevel == 60)
    #expect(state.peripheralConnected == true)
  }

  @Test("computed peripheralLevel is nil when no peripherals")
  func computedPeripheralLevelEmpty() {
    let state = BatteryState()
    #expect(state.peripheralLevel == nil)
    #expect(state.peripheralConnected == false)
  }

  @Test("reset clears all state")
  func resetClearsState() {
    let state = BatteryState()
    state.centralLevel = 80
    state.centralConnected = true
    state.peripherals = [PeripheralBattery(index: 0, level: 50, connected: true)]
    state.lastUpdated = Date()

    state.reset()

    #expect(state.centralLevel == nil)
    #expect(state.centralConnected == false)
    #expect(state.peripherals.isEmpty)
    #expect(state.lastUpdated == nil)
  }

  @Test("isStale is true when lastUpdated is nil")
  func staleWhenNeverUpdated() {
    let state = BatteryState()
    #expect(state.isStale() == true)
  }

  @Test("isStale is false within threshold window")
  func freshWithinThreshold() {
    let state = BatteryState()
    let now = Date()
    state.lastUpdated = now.addingTimeInterval(-30)

    #expect(state.isStale(now: now, threshold: 120) == false)
  }

  @Test("isStale is true past threshold window")
  func staleBeyondThreshold() {
    let state = BatteryState()
    let now = Date()
    state.lastUpdated = now.addingTimeInterval(-180)

    #expect(state.isStale(now: now, threshold: 120) == true)
  }

  @Test("isStale uses default threshold")
  func staleUsesDefaultThreshold() {
    let state = BatteryState()
    let now = Date()
    state.lastUpdated = now.addingTimeInterval(-(BatteryState.defaultStaleThreshold + 1))

    #expect(state.isStale(now: now) == true)
  }
}
