import SwiftUI

struct StatusBarRow: Equatable {
  let label: String
  let level: Int?
}

/// Layer and split-link information drawn before the battery rows. Present
/// only for keyboards running the zmk-host-status firmware module.
struct StatusBarLayerInfo: Equatable {
  var layer: LayerDisplayResolver.Display?
  /// True when a split half is not linked to the central half.
  var splitLinkDown: Bool
}

struct StatusBarView: View {
  let rows: [StatusBarRow]
  var showBatteryIcon: Bool = true
  /// When true, all rows are laid out on a single line (e.g. "C50% P50%")
  /// with a slightly larger font and a taller battery icon. The icon width is
  /// unchanged from the two-line layout.
  var singleLine: Bool = false
  var layerInfo: StatusBarLayerInfo? = nil

  private static let labelFont = Font.system(size: 11, weight: .semibold, design: .rounded)
  private static let singleLineFont = Font.system(size: 13, weight: .semibold, design: .rounded)

  // Icon width is identical in both layouts; only the height grows in the
  // single-line layout so it reads naturally next to the larger text.
  private static let iconWidth: CGFloat = 18
  private static let twoLineIconHeight: CGFloat = 8
  private static let singleLineIconHeight: CGFloat = 10

  var body: some View {
    HStack(spacing: 5) {
      if let layerInfo {
        layerBody(layerInfo)
      }
      if singleLine {
        singleLineBody
      } else {
        twoLineBody
      }
    }
    .frame(height: 22)
    .allowsHitTesting(false)
  }

  private func layerBody(_ info: StatusBarLayerInfo) -> some View {
    HStack(spacing: 3) {
      if info.splitLinkDown {
        // A half is not linked to the central half: the most important
        // thing the indicator can say, so it comes first.
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.system(size: 11, weight: .semibold))
      }
      if let layer = info.layer {
        Text(layer.current)
          .font(Self.singleLineFont)
        if layer.currentLocked {
          Image(systemName: "lock.fill")
            .font(.system(size: 8, weight: .semibold))
        }
        ForEach(layer.badges, id: \.self) { badge in
          Text(badge)
            .font(Self.labelFont)
            .padding(.horizontal, 3)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(lineWidth: 1))
        }
      }
    }
    .lineLimit(1)
    .fixedSize()
    .padding(.leading, 1)
  }

  private var twoLineBody: some View {
    let digits = rows.map { StatusBarLayout.digitCount(for: $0.level) }.max() ?? 2
    return VStack(spacing: 0) {
      ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
        self.twoLineRow(label: row.label, level: row.level, digits: digits)
      }
    }
    .font(Self.labelFont)
    .frame(height: 22)
    // Horizontal slack so the ImageRenderer output does not clip glyph
    // overhang/antialiasing at the edges (notably the trailing "%").
    .padding(.horizontal, 1)
    .allowsHitTesting(false)
  }

  private var singleLineBody: some View {
    let digits = rows.map { StatusBarLayout.digitCount(for: $0.level) }.max() ?? 2
    return HStack(spacing: 6) {
      ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
        self.singleLineRow(label: row.label, level: row.level, digits: digits)
      }
    }
    .font(Self.singleLineFont)
    .frame(height: 22)
    .padding(.horizontal, 1)
    .allowsHitTesting(false)
  }

  private func twoLineRow(label: String, level: Int?, digits: Int) -> some View {
    HStack(spacing: 1) {
      Text(label)
      if showBatteryIcon {
        BatteryIconView(level: level, size: CGSize(width: Self.iconWidth, height: Self.twoLineIconHeight))
          .padding(.trailing, 1)
      }
      percentText(level: level, digits: digits)
    }
    .lineLimit(1)
    .fixedSize(horizontal: false, vertical: true)
  }

  private func singleLineRow(label: String, level: Int?, digits: Int) -> some View {
    HStack(spacing: 1) {
      Text(label)
      if showBatteryIcon {
        BatteryIconView(level: level, size: CGSize(width: Self.iconWidth, height: Self.singleLineIconHeight))
          .padding(.trailing, 1)
      }
      percentText(level: level, digits: digits, font: Self.singleLineFont)
    }
    .lineLimit(1)
    .fixedSize(horizontal: false, vertical: true)
  }

  private func percentText(level: Int?, digits: Int, font: Font = StatusBarView.labelFont) -> some View {
    let placeholder = String(repeating: "0", count: digits) + "%"
    let actual = level.map { "\($0)%" } ?? "--"
    return ZStack(alignment: .trailing) {
      Text(placeholder).hidden()
      Text(actual)
    }
    .font(font.monospacedDigit())
  }
}
