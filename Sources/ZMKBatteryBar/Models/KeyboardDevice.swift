import Foundation

enum SideLabelStyle: String, Codable {
  case centralPeripheral
  case leftRight
}

enum KeyboardSide {
  case central
  case peripheral
}

struct KeyboardDevice: Identifiable, Codable {
  let uuid: String
  let name: String
  var labelStyle: SideLabelStyle
  var swapSides: Bool
  /// Per-peripheral custom labels, indexed by peripheral position.
  /// e.g. ["L", "R"] means P1=L, P2=R.
  var peripheralLabels: [String]

  var id: String { uuid }

  init(
    uuid: String,
    name: String,
    labelStyle: SideLabelStyle = .centralPeripheral,
    swapSides: Bool = false,
    peripheralLabels: [String] = []
  ) {
    self.uuid = uuid
    self.name = name
    self.labelStyle = labelStyle
    self.swapSides = swapSides
    self.peripheralLabels = peripheralLabels
  }

  private enum CodingKeys: String, CodingKey {
    case uuid, name, labelStyle, swapSides, peripheralLabels
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    uuid = try container.decode(String.self, forKey: .uuid)
    name = try container.decode(String.self, forKey: .name)
    labelStyle = try container.decodeIfPresent(SideLabelStyle.self, forKey: .labelStyle) ?? .centralPeripheral
    swapSides = try container.decodeIfPresent(Bool.self, forKey: .swapSides) ?? false
    peripheralLabels = try container.decodeIfPresent([String].self, forKey: .peripheralLabels) ?? []
  }

  func labelShort(for side: KeyboardSide) -> String {
    switch (labelStyle, side) {
    case (.centralPeripheral, .central): return "C"
    case (.centralPeripheral, .peripheral): return "P"
    case (.leftRight, .central): return swapSides ? "R" : "L"
    case (.leftRight, .peripheral): return swapSides ? "L" : "R"
    }
  }

  var centralLabelShort: String { labelShort(for: .central) }
  var peripheralLabelShort: String { labelShort(for: .peripheral) }

  mutating func assignLetter(_ letter: String?, to side: KeyboardSide) {
    guard let letter else {
      labelStyle = .centralPeripheral
      swapSides = false
      return
    }
    labelStyle = .leftRight
    switch side {
    case .central: swapSides = (letter == "R")
    case .peripheral: swapSides = (letter == "L")
    }
  }

  /// Assign a custom label to a specific peripheral by index.
  /// Clears the same label from any other peripheral to enforce uniqueness.
  mutating func assignPeripheralLabel(_ letter: String?, at index: Int) {
    // Grow array if needed
    while peripheralLabels.count <= index {
      peripheralLabels.append("")
    }
    if let letter, !letter.isEmpty {
      for i in peripheralLabels.indices where peripheralLabels[i] == letter {
        peripheralLabels[i] = ""
      }
    }
    peripheralLabels[index] = letter ?? ""
  }

  /// True when every peripheral (up to `count`) has a non-empty unique label.
  func hasValidPeripheralLabels(count: Int) -> Bool {
    guard count > 0, peripheralLabels.count >= count else { return false }
    let labels = peripheralLabels.prefix(count)
    let nonEmpty = labels.filter { !$0.isEmpty }
    return nonEmpty.count == count && Set(nonEmpty).count == count
  }
}
