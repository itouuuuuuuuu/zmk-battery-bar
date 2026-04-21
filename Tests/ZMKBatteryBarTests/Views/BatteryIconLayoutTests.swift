import CoreGraphics
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

  @Test(
    "snap rounds to the active display scale and guards scale below 1",
    arguments: [
      (CGFloat(0.375), CGFloat(1), CGFloat(0)),
      (CGFloat(0.375), CGFloat(2), CGFloat(0.5)),
      (CGFloat(0.625), CGFloat(2), CGFloat(0.5)),
      (CGFloat(0.875), CGFloat(2), CGFloat(1.0)),
      (CGFloat(0.375), CGFloat(0.5), CGFloat(0)),
      (CGFloat(1.25), CGFloat(0), CGFloat(1)),
    ]
  )
  func snap(value: CGFloat, scale: CGFloat, expected: CGFloat) {
    #expect(BatteryIconLayout.snap(value, scale: scale) == expected)
  }
}
