import Foundation

enum ReconnectBackoff {
  static func nextDelay(current: TimeInterval, cap: TimeInterval) -> TimeInterval {
    min(current * 2, cap)
  }

  /// Delay to wait after `failureCount` consecutive failures: `initial` for
  /// the first failure, doubling per additional failure, capped at `cap`.
  static func delay(
    forConsecutiveFailures failureCount: Int,
    initial: TimeInterval,
    cap: TimeInterval
  ) -> TimeInterval {
    guard failureCount > 1 else { return initial }
    var delay = initial
    for _ in 1..<failureCount {
      delay = nextDelay(current: delay, cap: cap)
    }
    return delay
  }
}
