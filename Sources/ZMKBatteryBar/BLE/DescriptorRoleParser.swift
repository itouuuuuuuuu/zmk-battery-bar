import Foundation

enum DescriptorRoleParser {
  static func role(from description: String?) -> DeviceRole? {
    guard let description else { return nil }
    let lowered = description.lowercased()
    if lowered.contains("central") {
      return .central
    } else if lowered.contains("peripheral") {
      return .peripheral
    } else {
      return nil
    }
  }
}
