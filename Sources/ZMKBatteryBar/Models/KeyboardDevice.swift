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

  var id: String { uuid }

  init(
    uuid: String,
    name: String,
    labelStyle: SideLabelStyle = .centralPeripheral,
    swapSides: Bool = false
  ) {
    self.uuid = uuid
    self.name = name
    self.labelStyle = labelStyle
    self.swapSides = swapSides
  }

  private enum CodingKeys: String, CodingKey {
    case uuid, name, labelStyle, swapSides
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    uuid = try container.decode(String.self, forKey: .uuid)
    name = try container.decode(String.self, forKey: .name)
    labelStyle = try container.decodeIfPresent(SideLabelStyle.self, forKey: .labelStyle) ?? .centralPeripheral
    swapSides = try container.decodeIfPresent(Bool.self, forKey: .swapSides) ?? false
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
}
