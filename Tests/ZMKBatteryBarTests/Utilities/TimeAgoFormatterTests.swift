import Foundation
import Testing

@testable import ZMKBatteryBar

@Suite("TimeAgoFormatter")
struct TimeAgoFormatterTests {
  @Test(
    "bucket boundaries",
    arguments: [
      (-5, "0s ago"),
      (0, "0s ago"),
      (1, "1s ago"),
      (59, "59s ago"),
      (60, "1m ago"),
      (119, "1m ago"),
      (120, "2m ago"),
      (3599, "59m ago"),
      (3600, "1h ago"),
      (7199, "1h ago"),
      (7200, "2h ago"),
      (86399, "23h ago"),
      (86400, "24h ago"),
    ]
  )
  func boundaries(seconds: Int, expected: String) {
    #expect(TimeAgoFormatter.format(secondsAgo: seconds) == expected)
  }

  @Test("format(from:now:) delegates to seconds formatter")
  func fromDateBridge() {
    let now = Date(timeIntervalSince1970: 1_000_000)
    let past = now.addingTimeInterval(-150)

    #expect(TimeAgoFormatter.format(from: past, now: now) == "2m ago")
  }
}
