import SwiftUI

struct BatteryIconView: View {
  let level: Int?
  var size: CGSize = CGSize(width: 20, height: 9)

  var body: some View {
    Canvas { context, canvasSize in
      let lineW: CGFloat = 0.75
      let half = lineW / 2
      let nubW: CGFloat = 1.5
      let bodyWidth = canvasSize.width - nubW
      let bodyHeight = canvasSize.height
      let color: Color = .primary

      let bodyRect = CGRect(x: half, y: half, width: bodyWidth - lineW, height: bodyHeight - lineW)
      let bodyPath = Path(roundedRect: bodyRect, cornerRadius: 2)
      context.stroke(bodyPath, with: .color(color.opacity(0.8)), lineWidth: lineW)

      if let level {
        let inset: CGFloat = lineW + 0.75
        let fillMaxWidth = bodyWidth - inset * 2
        let fillWidth = fillMaxWidth * CGFloat(min(max(level, 0), 100)) / 100.0
        let fillRect = CGRect(x: inset, y: inset, width: fillWidth, height: bodyHeight - inset * 2)
        let fillPath = Path(roundedRect: fillRect, cornerRadius: 0.75)
        context.fill(fillPath, with: .color(color.opacity(0.8)))
      }

      let nubHeight = bodyHeight * 0.35
      let nubY = (bodyHeight - nubHeight) / 2
      let nubRect = CGRect(x: bodyWidth, y: nubY, width: nubW, height: nubHeight)
      let nubPath = Path(roundedRect: nubRect, cornerRadius: 0.5)
      context.fill(nubPath, with: .color(color.opacity(0.8)))
    }
    .frame(width: size.width, height: size.height)
    .drawingGroup()
  }
}
