import SwiftUI

struct StatusBarRow: Equatable {
  let label: String
  let level: Int?
}

struct StatusBarView: View {
  let rows: [StatusBarRow]

  private static let labelFont = Font.system(size: 11, weight: .semibold, design: .rounded)

  var body: some View {
    let digits = rows.map { StatusBarLayout.digitCount(for: $0.level) }.max() ?? 2
    VStack(spacing: 0) {
      ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
        self.row(label: row.label, level: row.level, digits: digits)
      }
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
