import Testing

@testable import ZMKBatteryBar

@Suite("BatteryIconLayout")
struct BatteryIconLayoutTests {
  @Test(
    "clampedLevel preserves nil and clamps out-of-range values",
    arguments: [
      (Int?.none, Int?.none),
      (.some(-1), .some(0)),
      (.some(0), .some(0)),
      (.some(1), .some(1)),
      (.some(49), .some(49)),
      (.some(66), .some(66)),
      (.some(100), .some(100)),
      (.some(135), .some(100)),
    ]
  )
  func clampedLevel(level: Int?, expected: Int?) {
    #expect(BatteryIconLayout.clampedLevel(level) == expected)
  }
}
