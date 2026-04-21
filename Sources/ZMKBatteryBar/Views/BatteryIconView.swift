import AppKit
import SwiftUI

enum BatteryIconLayout {
  static func clampedLevel(_ level: Int?) -> Int? {
    guard let level else { return nil }
    return min(max(level, 0), 100)
  }

  static func snap(_ value: CGFloat, scale: CGFloat) -> CGFloat {
    let scale = max(scale, 1)
    return (value * scale).rounded() / scale
  }
}

struct BatteryIconView: View {
  @Environment(\.displayScale) private var displayScale

  let level: Int?
  var size: CGSize = CGSize(width: 20, height: 9)

  private let strokeWidth: CGFloat = 0.75
  private let nubWidth: CGFloat = 1.5
  private let nubSpacing: CGFloat = 0.375
  private let fillCornerRadius: CGFloat = 0.75
  private let bodyCornerRadius: CGFloat = 2

  private var iconColor: Color {
    Color(nsColor: .labelColor).opacity(0.8)
  }

  private var scale: CGFloat {
    max(displayScale, 1)
  }

  private func snap(_ value: CGFloat) -> CGFloat {
    BatteryIconLayout.snap(value, scale: scale)
  }

  private var iconWidth: CGFloat {
    snap(size.width)
  }

  private var iconHeight: CGFloat {
    snap(size.height)
  }

  private var lineWidth: CGFloat {
    max(snap(strokeWidth), 1 / scale)
  }

  private var nubSpacingValue: CGFloat {
    snap(nubSpacing)
  }

  private var nubWidthValue: CGFloat {
    snap(nubWidth)
  }

  private var bodyCornerRadiusValue: CGFloat {
    snap(bodyCornerRadius)
  }

  private var fillCornerRadiusValue: CGFloat {
    snap(fillCornerRadius)
  }

  private var bodyWidth: CGFloat {
    max(iconWidth - nubWidthValue - nubSpacingValue, 0)
  }

  private var fillInsetX: CGFloat {
    snap(lineWidth + 0.5)
  }

  private var fillInsetY: CGFloat {
    snap(lineWidth + 0.75)
  }

  private var fillHeight: CGFloat {
    max(iconHeight - fillInsetY * 2, 0)
  }

  private var fillWidth: CGFloat {
    let clampedLevel = CGFloat(BatteryIconLayout.clampedLevel(level) ?? 0)
    let availableWidth = max(bodyWidth - fillInsetX * 2, 0)
    let rawWidth = availableWidth * clampedLevel / 100.0
    return min(max(snap(rawWidth), 0), availableWidth)
  }

  private var nubHeight: CGFloat {
    snap(iconHeight * 0.35)
  }

  var body: some View {
    HStack(alignment: .center, spacing: nubSpacingValue) {
      ZStack(alignment: .topLeading) {
        RoundedRectangle(cornerRadius: bodyCornerRadiusValue)
          .strokeBorder(iconColor, lineWidth: lineWidth)

        if fillWidth > 0 {
          RoundedRectangle(cornerRadius: fillCornerRadiusValue)
            .fill(iconColor)
            .frame(width: fillWidth, height: fillHeight)
            .offset(x: fillInsetX, y: fillInsetY)
        }
      }
      .frame(width: bodyWidth, height: iconHeight)

      RoundedRectangle(cornerRadius: 0.5)
        .fill(iconColor)
        .frame(width: nubWidthValue, height: nubHeight)
    }
    .frame(width: iconWidth, height: iconHeight)
    .accessibilityHidden(true)
  }
}
