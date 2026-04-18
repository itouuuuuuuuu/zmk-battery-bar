import Foundation

enum StatusBarLayout {
  static func digitCount(for level: Int?) -> Int {
    level.map { String($0).count } ?? 2
  }
}
