import Foundation
import Testing

@testable import ZMKBatteryBar

@Suite("KeyboardInputThrottle")
struct KeyboardInputThrottleTests {
  private let t0 = Date(timeIntervalSinceReferenceDate: 1_000)

  /// `#expect` cannot wrap a mutating call directly, so evaluate it first.
  private func report(
    _ throttle: inout KeyboardInputThrottle, _ name: String, after offset: TimeInterval
  ) -> Bool {
    throttle.shouldReport(productName: name, at: t0.addingTimeInterval(offset))
  }

  @Test("first input is always reported")
  func firstInputReported() {
    var throttle = KeyboardInputThrottle(minimumInterval: 0.5)
    #expect(report(&throttle, "Corne", after: 0))
  }

  @Test("repeated input from the same device inside the window is dropped")
  func sameDeviceThrottled() {
    var throttle = KeyboardInputThrottle(minimumInterval: 0.5)
    #expect(report(&throttle, "Corne", after: 0))
    #expect(!report(&throttle, "Corne", after: 0.1))
    #expect(!report(&throttle, "Corne", after: 0.49))
  }

  @Test("same device is reported again once the window has passed")
  func sameDeviceAfterWindow() {
    var throttle = KeyboardInputThrottle(minimumInterval: 0.5)
    #expect(report(&throttle, "Corne", after: 0))
    #expect(report(&throttle, "Corne", after: 0.5))
  }

  @Test("a different device is reported immediately even inside the window")
  func differentDeviceNotThrottled() {
    var throttle = KeyboardInputThrottle(minimumInterval: 0.5)
    #expect(report(&throttle, "Corne", after: 0))
    #expect(report(&throttle, "Sofle", after: 0.01))
  }

  @Test("switching back to the previous device is reported immediately")
  func switchBackNotThrottled() {
    var throttle = KeyboardInputThrottle(minimumInterval: 0.5)
    #expect(report(&throttle, "Corne", after: 0))
    #expect(report(&throttle, "Sofle", after: 0.01))
    #expect(report(&throttle, "Corne", after: 0.02))
  }

  @Test("dropped input does not extend the window")
  func droppedInputDoesNotExtendWindow() {
    var throttle = KeyboardInputThrottle(minimumInterval: 0.5)
    #expect(report(&throttle, "Corne", after: 0))
    #expect(!report(&throttle, "Corne", after: 0.4))
    // 0.5 s after the *reported* press, not after the dropped one.
    #expect(report(&throttle, "Corne", after: 0.5))
  }
}
