import Foundation

struct KeyboardDevice: Identifiable, Codable {
  let uuid: String
  let name: String

  var id: String { uuid }
}
