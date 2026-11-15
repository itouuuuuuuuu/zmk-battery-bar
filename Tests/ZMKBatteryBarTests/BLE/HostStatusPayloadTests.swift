import Foundation
import Testing

@testable import ZMKBatteryBar

@Suite("HostStatusPayload")
struct HostStatusPayloadTests {
  // version 1, flags 1, active 0b1000011 (layers 0,1,6), locked 0b10 (layer 1),
  // 1 of 1 peripheral connected.
  private static let v1 = Data([
    0x01, 0x01,
    0x43, 0x00, 0x00, 0x00,
    0x02, 0x00, 0x00, 0x00,
    0x01, 0x01,
  ])

  @Test("parses a v1 status payload")
  func parsesV1() throws {
    let status = try #require(HostStatusPayload.parseStatus(from: Self.v1))
    #expect(status.activeLayers == 0x43)
    #expect(status.lockedLayers == 0x02)
    #expect(status.peripheralsConnected == 1)
    #expect(status.peripheralsExpected == 1)
    #expect(status.splitLinkUp)
  }

  @Test("rejects short payloads and version 0")
  func rejectsInvalid() {
    #expect(HostStatusPayload.parseStatus(from: nil) == nil)
    #expect(HostStatusPayload.parseStatus(from: Data([0x01, 0x00])) == nil)
    var v0 = Self.v1
    v0[0] = 0x00
    #expect(HostStatusPayload.parseStatus(from: v0) == nil)
  }

  @Test("accepts longer payloads from newer firmware")
  func forwardCompatible() {
    var v2 = Self.v1
    v2[0] = 0x02
    v2.append(contentsOf: [0xAA, 0xBB])
    #expect(HostStatusPayload.parseStatus(from: v2)?.activeLayers == 0x43)
  }

  @Test("split link down when fewer halves are connected than expected")
  func splitLinkDown() {
    let status = HostStatus(activeLayers: 1, lockedLayers: 0, peripheralsConnected: 0, peripheralsExpected: 1)
    #expect(!status.splitLinkUp)
    let unibody = HostStatus(activeLayers: 1, lockedLayers: 0, peripheralsConnected: 0, peripheralsExpected: 0)
    #expect(unibody.splitLinkUp)
  }

  @Test("layer names split on newlines, keeping order")
  func layerNames() {
    let data = Data("Base\nGraphite\nNav/Num".utf8)
    #expect(HostStatusPayload.parseLayerNames(from: data) == ["Base", "Graphite", "Nav/Num"])
    #expect(HostStatusPayload.parseLayerNames(from: Data()) == nil)
  }

  @Test("build id is trimmed and empty is nil")
  func buildID() {
    #expect(HostStatusPayload.parseBuildID(from: Data("a366469\0".utf8)) == "a366469")
    #expect(HostStatusPayload.parseBuildID(from: Data("  ".utf8)) == nil)
  }
}
