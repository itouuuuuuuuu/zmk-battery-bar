import Foundation

enum BatteryPayload {
  static func parseLevel(from data: Data?) -> Int? {
    guard let byte = data?.first else { return nil }
    return Int(byte)
  }
}
