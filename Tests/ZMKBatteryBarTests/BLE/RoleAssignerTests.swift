import Foundation
import Testing

@testable import ZMKBatteryBar

@Suite("RoleAssigner")
struct RoleAssignerTests {
  // Use UUIDs as generic Hashable keys — the production code runs with
  // CBCharacteristic object identity, but the algorithm itself is key-agnostic.
  private let a = UUID()
  private let b = UUID()
  private let c = UUID()

  // MARK: - remainingRole

  @Test("already-assigned role is returned unchanged")
  func remainingPreservesExisting() {
    let role = RoleAssigner.remainingRole(
      target: a,
      allCharacteristics: [a, b],
      roles: [a: .peripheral]
    )
    #expect(role == .peripheral)
  }

  @Test("single characteristic maps to central")
  func remainingSingletonCentral() {
    let role = RoleAssigner.remainingRole(
      target: a,
      allCharacteristics: [a],
      roles: [:]
    )
    #expect(role == .central)
  }

  @Test("sibling central infers peripheral")
  func remainingInfersPeripheralFromSibling() {
    let role = RoleAssigner.remainingRole(
      target: a,
      allCharacteristics: [a, b],
      roles: [b: .central]
    )
    #expect(role == .peripheral)
  }

  @Test("sibling peripheral infers central")
  func remainingInfersCentralFromSibling() {
    let role = RoleAssigner.remainingRole(
      target: a,
      allCharacteristics: [a, b],
      roles: [b: .peripheral]
    )
    #expect(role == .central)
  }

  @Test("two characteristics with unresolved sibling → nil")
  func remainingNilWhenSiblingUnknown() {
    let role = RoleAssigner.remainingRole(
      target: a,
      allCharacteristics: [a, b],
      roles: [:]
    )
    #expect(role == nil)
  }

  @Test("three characteristics, one unresolved with known central → infers peripheral")
  func remainingInfersPeripheralFromCentralInThree() {
    let role = RoleAssigner.remainingRole(
      target: a,
      allCharacteristics: [a, b, c],
      roles: [b: .central, c: .peripheral]
    )
    #expect(role == .peripheral)
  }

  @Test("three characteristics, one unresolved with no central → infers central")
  func remainingInfersCentralInThreeNoCentral() {
    let role = RoleAssigner.remainingRole(
      target: a,
      allCharacteristics: [a, b, c],
      roles: [b: .peripheral, c: .peripheral]
    )
    #expect(role == .central)
  }

  @Test("three characteristics, two unresolved → nil")
  func remainingNilWhenTwoUnresolved() {
    let role = RoleAssigner.remainingRole(
      target: a,
      allCharacteristics: [a, b, c],
      roles: [b: .central]
    )
    #expect(role == nil)
  }

  @Test("target not in array → nil")
  func remainingNilWhenTargetNotListed() {
    let role = RoleAssigner.remainingRole(
      target: c,
      allCharacteristics: [a, b],
      roles: [a: .central]
    )
    #expect(role == nil)
  }

  // MARK: - roleByIndex

  @Test("first index → central, others → peripheral")
  func roleByIndexAssigns() {
    #expect(
      RoleAssigner.roleByIndex(target: a, allCharacteristics: [a, b], roles: [:]) == .central
    )
    #expect(
      RoleAssigner.roleByIndex(target: b, allCharacteristics: [a, b], roles: [:]) == .peripheral
    )
  }

  @Test("already-assigned target yields nil")
  func roleByIndexSkipsAssigned() {
    #expect(
      RoleAssigner.roleByIndex(
        target: a,
        allCharacteristics: [a, b],
        roles: [a: .peripheral]
      ) == nil
    )
  }

  @Test("target outside array yields nil")
  func roleByIndexNilWhenMissing() {
    #expect(
      RoleAssigner.roleByIndex(target: c, allCharacteristics: [a, b], roles: [:]) == nil
    )
  }

  // MARK: - assignFallbackRoles

  @Test("no unresolved → unchanged")
  func fallbackNoop() {
    let updated = RoleAssigner.assignFallbackRoles(
      allCharacteristics: [a, b],
      roles: [a: .central, b: .peripheral],
      terminallyFailed: []
    )
    #expect(updated == [a: .central, b: .peripheral])
  }

  @Test("single unresolved with known sibling → filled in")
  func fallbackSingleUnresolvedFills() {
    let updated = RoleAssigner.assignFallbackRoles(
      allCharacteristics: [a, b],
      roles: [a: .central],
      terminallyFailed: []
    )
    #expect(updated == [a: .central, b: .peripheral])
  }

  @Test("single unresolved, sole characteristic → central")
  func fallbackSingleSoleCharacteristic() {
    let updated = RoleAssigner.assignFallbackRoles(
      allCharacteristics: [a],
      roles: [:],
      terminallyFailed: []
    )
    #expect(updated == [a: .central])
  }

  @Test("two unresolved without terminal failures → left unchanged")
  func fallbackWithoutTerminalFailuresKeepsUnresolved() {
    let updated = RoleAssigner.assignFallbackRoles(
      allCharacteristics: [a, b],
      roles: [:],
      terminallyFailed: []
    )
    #expect(updated.isEmpty)
  }

  @Test("two unresolved, all terminally failed → index fallback applied")
  func fallbackIndexFallbackWhenAllFailed() {
    let updated = RoleAssigner.assignFallbackRoles(
      allCharacteristics: [a, b],
      roles: [:],
      terminallyFailed: [a, b]
    )
    #expect(updated == [a: .central, b: .peripheral])
  }

  @Test("only some terminally failed → no fallback assignment")
  func fallbackPartialFailureSkips() {
    let updated = RoleAssigner.assignFallbackRoles(
      allCharacteristics: [a, b],
      roles: [:],
      terminallyFailed: [a]
    )
    #expect(updated.isEmpty)
  }
}
