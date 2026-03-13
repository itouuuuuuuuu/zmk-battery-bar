import SwiftUI

struct StatusBarView: View {
  let batteryState: BatteryState

  var body: some View {
    VStack(spacing: 0) {
      row(label: "C", level: batteryState.centralLevel)
      row(label: "P", level: batteryState.peripheralLevel)
    }
    .frame(height: 22)
    .allowsHitTesting(false)
  }

  private func row(label: String, level: Int?) -> some View {
    HStack(spacing: 1) {
      Text(label)
        .font(.system(size: 11, weight: .semibold, design: .rounded))
      BatteryIconView(level: level, size: CGSize(width: 18, height: 8))
      Text(level.map { "\($0)%" } ?? "--")
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .padding(.leading, level == nil ? 2 : 0)
    }
    .lineLimit(1)
    .fixedSize(horizontal: false, vertical: true)
  }
}
