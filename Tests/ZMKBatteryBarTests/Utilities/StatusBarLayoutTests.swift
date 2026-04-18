import Testing

@testable import ZMKBatteryBar

@Suite("StatusBarLayout")
struct StatusBarLayoutTests {
  @Test(
    "digitCount across ranges",
    arguments: [
      (Int?.none, 2),
      (.some(0), 1),
      (.some(1), 1),
      (.some(9), 1),
      (.some(10), 2),
      (.some(99), 2),
      (.some(100), 3),
    ]
  )
  func digitCountCases(level: Int?, expected: Int) {
    #expect(StatusBarLayout.digitCount(for: level) == expected)
  }
}
