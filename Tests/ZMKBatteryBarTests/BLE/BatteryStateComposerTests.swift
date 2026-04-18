import Foundation
import Testing

@testable import ZMKBatteryBar

@Suite("BatteryStateComposer")
struct BatteryStateComposerTests {
  private let a = UUID()
  private let b = UUID()

  @Test("empty inputs → all nil / disconnected")
  func emptyInputs() {
    let snapshot = BatteryStateComposer.compose(
      allCharacteristics: [UUID](),
      roles: [UUID: DeviceRole](),
      levels: [UUID: Int]()
    )
    #expect(snapshot.centralLevel == nil)
    #expect(snapshot.peripheralLevel == nil)
    #expect(snapshot.centralConnected == false)
    #expect(snapshot.peripheralConnected == false)
    #expect(snapshot.shouldUpdateTimestamp == false)
  }

  @Test("role without level is skipped")
  func roleWithoutLevel() {
    let snapshot = BatteryStateComposer.compose(
      allCharacteristics: [a],
      roles: [a: .central],
      levels: [:]
    )
    #expect(snapshot.centralLevel == nil)
    #expect(snapshot.centralConnected == false)
    #expect(snapshot.shouldUpdateTimestamp == false)
  }

  @Test("level without role is skipped")
  func levelWithoutRole() {
    let snapshot = BatteryStateComposer.compose(
      allCharacteristics: [a],
      roles: [:],
      levels: [a: 80]
    )
    #expect(snapshot.centralLevel == nil)
    #expect(snapshot.peripheralLevel == nil)
    #expect(snapshot.shouldUpdateTimestamp == false)
  }

  @Test("central only → central populated, peripheral nil")
  func centralOnly() {
    let snapshot = BatteryStateComposer.compose(
      allCharacteristics: [a],
      roles: [a: .central],
      levels: [a: 75]
    )
    #expect(snapshot.centralLevel == 75)
    #expect(snapshot.peripheralLevel == nil)
    #expect(snapshot.centralConnected == true)
    #expect(snapshot.peripheralConnected == false)
    #expect(snapshot.shouldUpdateTimestamp == true)
  }

  @Test("peripheral only → peripheral populated")
  func peripheralOnly() {
    let snapshot = BatteryStateComposer.compose(
      allCharacteristics: [a],
      roles: [a: .peripheral],
      levels: [a: 60]
    )
    #expect(snapshot.peripheralLevel == 60)
    #expect(snapshot.centralLevel == nil)
    #expect(snapshot.peripheralConnected == true)
    #expect(snapshot.shouldUpdateTimestamp == true)
  }

  @Test("both sides populated")
  func bothSides() {
    let snapshot = BatteryStateComposer.compose(
      allCharacteristics: [a, b],
      roles: [a: .central, b: .peripheral],
      levels: [a: 80, b: 40]
    )
    #expect(snapshot.centralLevel == 80)
    #expect(snapshot.peripheralLevel == 40)
    #expect(snapshot.centralConnected == true)
    #expect(snapshot.peripheralConnected == true)
    #expect(snapshot.shouldUpdateTimestamp == true)
  }

  @Test("only characteristics listed in allCharacteristics are considered")
  func ignoresOrphanKeys() {
    let orphan = UUID()
    let snapshot = BatteryStateComposer.compose(
      allCharacteristics: [a],
      roles: [a: .central, orphan: .peripheral],
      levels: [a: 50, orphan: 10]
    )
    #expect(snapshot.centralLevel == 50)
    #expect(snapshot.peripheralLevel == nil)
    #expect(snapshot.peripheralConnected == false)
  }
}
