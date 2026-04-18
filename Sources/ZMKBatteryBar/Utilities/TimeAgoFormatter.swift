import Foundation

enum TimeAgoFormatter {
  static func format(secondsAgo seconds: Int) -> String {
    if seconds < 60 {
      return "\(max(seconds, 0))s ago"
    } else if seconds < 3600 {
      return "\(seconds / 60)m ago"
    } else {
      return "\(seconds / 3600)h ago"
    }
  }

  static func format(from date: Date, now: Date) -> String {
    let seconds = Int(now.timeIntervalSince(date))
    return format(secondsAgo: seconds)
  }
}
