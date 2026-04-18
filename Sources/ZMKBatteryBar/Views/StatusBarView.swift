import SwiftUI

struct StatusBarView: View {
  let batteryState: BatteryState
  let centralLabel: String
  let peripheralLabel: String

  private static let labelFont = Font.system(size: 11, weight: .semibold, design: .rounded)

  init(batteryState: BatteryState, centralLabel: String = "C", peripheralLabel: String = "P") {
    self.batteryState = batteryState
    self.centralLabel = centralLabel
    self.peripheralLabel = peripheralLabel
  }

  var body: some View {
    let digits = max(
      StatusBarLayout.digitCount(for: batteryState.centralLevel),
      StatusBarLayout.digitCount(for: batteryState.peripheralLevel)
    )
    VStack(spacing: 0) {
      row(label: centralLabel, level: batteryState.centralLevel, digits: digits)
      row(label: peripheralLabel, level: batteryState.peripheralLevel, digits: digits)
    }
    .font(Self.labelFont)
    .frame(height: 22)
    .allowsHitTesting(false)
  }

  private func row(label: String, level: Int?, digits: Int) -> some View {
    HStack(spacing: 1) {
      Text(label)
      BatteryIconView(level: level, size: CGSize(width: 18, height: 8))
      percentText(level: level, digits: digits)
    }
    .lineLimit(1)
    .fixedSize(horizontal: false, vertical: true)
  }

  private func percentText(level: Int?, digits: Int) -> some View {
    let placeholder = String(repeating: "0", count: digits) + "%"
    let actual = level.map { "\($0)%" } ?? "--"
    return ZStack(alignment: .trailing) {
      Text(placeholder).hidden()
      Text(actual)
    }
    .font(Self.labelFont.monospacedDigit())
  }
}
