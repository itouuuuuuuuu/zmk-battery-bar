import Foundation
import Testing

@testable import ZMKBatteryBar

@Suite("BatteryPayload")
struct BatteryPayloadTests {
  @Test("nil input returns nil")
  func nilInput() {
    #expect(BatteryPayload.parseLevel(from: nil) == nil)
  }

  @Test("empty data returns nil")
  func emptyData() {
    #expect(BatteryPayload.parseLevel(from: Data()) == nil)
  }

  @Test(
    "first byte is the level (0..=100)",
    arguments: [
      (Data([0x00]), 0),
      (Data([0x01]), 1),
      (Data([0x32]), 50),
      (Data([0x64]), 100),
    ]
  )
  func firstByteLevel(data: Data, expected: Int) {
    #expect(BatteryPayload.parseLevel(from: data) == expected)
  }

  @Test("multi-byte payloads use the first byte only")
  func multiByteUsesFirst() {
    #expect(BatteryPayload.parseLevel(from: Data([0x2A, 0xFF, 0x00])) == 42)
  }

  @Test("byte > 100 is returned as-is (existing behavior)")
  func preservesExistingBehaviorForOutOfRange() {
    #expect(BatteryPayload.parseLevel(from: Data([0xFF])) == 255)
  }
}
