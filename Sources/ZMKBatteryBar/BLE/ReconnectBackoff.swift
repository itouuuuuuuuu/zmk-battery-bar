import Foundation

enum ReconnectBackoff {
  static func nextDelay(current: TimeInterval, cap: TimeInterval) -> TimeInterval {
    min(current * 2, cap)
  }
}
