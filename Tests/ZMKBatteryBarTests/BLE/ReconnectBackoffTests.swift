import Foundation
import Testing

@testable import ZMKBatteryBar

@Suite("ReconnectBackoff")
struct ReconnectBackoffTests {
  @Test("doubles until cap")
  func doublesThenCaps() {
    let cap: TimeInterval = 300
    var delay: TimeInterval = 5

    let expectedSeries: [TimeInterval] = [10, 20, 40, 80, 160, 300, 300]
    for expected in expectedSeries {
      delay = ReconnectBackoff.nextDelay(current: delay, cap: cap)
      #expect(delay == expected)
    }
  }

  @Test("caps immediately when next double exceeds cap")
  func capsAtBoundary() {
    #expect(ReconnectBackoff.nextDelay(current: 200, cap: 300) == 300)
    #expect(ReconnectBackoff.nextDelay(current: 150, cap: 300) == 300)
  }

  @Test("never exceeds the cap")
  func neverExceedsCap() {
    #expect(ReconnectBackoff.nextDelay(current: 10_000, cap: 300) == 300)
  }
}
