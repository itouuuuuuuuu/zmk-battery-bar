import Foundation
import Testing

@testable import ZMKBatteryBar

@Suite("LayerDisplayResolver")
struct LayerDisplayResolverTests {
  private static let names = ["Base", "Graphite", "Nav", "Media", "System", "Mouse", "NumPad"]
  private static func bits(_ indices: Int...) -> UInt32 {
    indices.reduce(0) { $0 | (UInt32(1) << UInt32($1)) }
  }

  @Test("base only shows the base layer, unlocked")
  func baseOnly() throws {
    let d = try #require(LayerDisplayResolver.resolve(
      names: Self.names, activeLayers: Self.bits(0), lockedLayers: 0, hidden: []))
    #expect(d.current == "Base")
    #expect(!d.currentLocked)
    #expect(d.badges.isEmpty)
  }

  @Test("toggled alternate alpha layer shows as current and locked")
  func graphiteLocked() throws {
    let d = try #require(LayerDisplayResolver.resolve(
      names: Self.names, activeLayers: Self.bits(0, 1), lockedLayers: Self.bits(1), hidden: []))
    #expect(d.current == "Graphite")
    #expect(d.currentLocked)
    #expect(d.badges.isEmpty)
  }

  @Test("momentary layer on top of a locked one: locked one becomes a badge")
  func navOverGraphite() throws {
    let d = try #require(LayerDisplayResolver.resolve(
      names: Self.names, activeLayers: Self.bits(0, 1, 2), lockedLayers: Self.bits(1), hidden: []))
    #expect(d.current == "Nav")
    #expect(!d.currentLocked)
    #expect(d.badges == ["Graphite"])
  }

  @Test("hidden layers are skipped, case-insensitively")
  func hiddenMouse() throws {
    let d = try #require(LayerDisplayResolver.resolve(
      names: Self.names, activeLayers: Self.bits(0, 5), lockedLayers: Self.bits(5), hidden: ["mouse"]))
    #expect(d.current == "Base")
    #expect(d.badges.isEmpty)
  }

  @Test("index 0 is always underneath even if reported clear")
  func baseImplicit() throws {
    let d = try #require(LayerDisplayResolver.resolve(
      names: Self.names, activeLayers: 0, lockedLayers: 0, hidden: []))
    #expect(d.current == "Base")
  }

  @Test("no names means nothing to show")
  func noNames() {
    #expect(LayerDisplayResolver.resolve(names: [], activeLayers: 1, lockedLayers: 0, hidden: []) == nil)
  }
}
