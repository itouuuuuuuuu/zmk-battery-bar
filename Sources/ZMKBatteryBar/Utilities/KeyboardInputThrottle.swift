import Foundation

/// Rate-limits HID input reports per source device. Consecutive presses from
/// the *same* keyboard are collapsed to one report per `minimumInterval`, but
/// a press from a *different* keyboard is always reported immediately: that
/// first press is exactly the event the auto-switch feature exists to catch,
/// so it must never be swallowed by a throttle window opened by another
/// device.
struct KeyboardInputThrottle {
  let minimumInterval: TimeInterval
  private var lastProductName: String?
  private var lastReported = Date.distantPast

  init(minimumInterval: TimeInterval = 0.5) {
    self.minimumInterval = minimumInterval
  }

  /// Returns true when the input from `productName` at `now` should be
  /// forwarded, and records it as the latest report if so.
  mutating func shouldReport(productName: String, at now: Date = Date()) -> Bool {
    if productName == lastProductName,
       now.timeIntervalSince(lastReported) < minimumInterval {
      return false
    }
    lastProductName = productName
    lastReported = now
    return true
  }
}
