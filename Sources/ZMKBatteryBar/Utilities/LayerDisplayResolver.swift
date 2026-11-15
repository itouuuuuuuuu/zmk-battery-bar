import Foundation

/// Turns raw layer bitmasks into what the menu bar shows.
enum LayerDisplayResolver {
  struct Display: Equatable {
    /// Name of the highest active visible layer.
    let current: String
    /// Whether `current` is locked on (no key holding it).
    let currentLocked: Bool
    /// Other locked visible layers, lowest index first (e.g. an alternate
    /// alpha layer while a function layer is on top of it).
    let badges: [String]
  }

  /// - Parameters:
  ///   - names: layer names in keymap index order.
  ///   - hidden: layer names never shown (case-insensitive), e.g. a Mouse
  ///     layer raised by trackball motion that would otherwise flicker.
  static func resolve(
    names: [String],
    activeLayers: UInt32,
    lockedLayers: UInt32,
    hidden: Set<String>
  ) -> Display? {
    guard !names.isEmpty else { return nil }
    let hiddenLower = Set(hidden.map { $0.lowercased() })
    let count = min(names.count, 32)
    func isVisible(_ i: Int) -> Bool { !hiddenLower.contains(names[i].lowercased()) }
    func isSet(_ mask: UInt32, _ i: Int) -> Bool { mask & (UInt32(1) << UInt32(i)) != 0 }

    // Highest active visible layer; index 0 counts as active even if the
    // firmware reports it clear (the default layer is always underneath).
    var currentIndex: Int?
    for i in stride(from: count - 1, through: 0, by: -1)
    where isVisible(i) && (isSet(activeLayers, i) || i == 0) {
      currentIndex = i
      break
    }
    guard let currentIndex else { return nil }

    let badges = (1..<max(count, 1)).filter { i in
      i != currentIndex && isVisible(i) && isSet(lockedLayers, i) && isSet(activeLayers, i)
    }.map { names[$0] }

    return Display(
      current: names[currentIndex],
      currentLocked: currentIndex != 0 && isSet(lockedLayers, currentIndex),
      badges: badges
    )
  }
}
