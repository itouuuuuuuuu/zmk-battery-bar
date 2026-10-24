import Foundation

/// Decides which saved keyboard the app should switch to when HID input
/// arrives from a device. Pure logic so it can be unit-tested without IOKit.
enum ActiveKeyboardResolver {
  /// Returns the UUID of the saved keyboard to select for input coming from
  /// the HID device named `productName`, or nil when no switch should happen.
  ///
  /// ZMK advertises the same device name over BLE (seen by CoreBluetooth) and
  /// as the HID product string (seen by IOKit), so the name is the only
  /// identifier the two sides share. The match is case-insensitive and
  /// ignores surrounding whitespace.
  ///
  /// No switch happens when:
  /// - the name matches no saved keyboard (e.g. the built-in keyboard),
  /// - the currently selected keyboard already matches (nothing to do),
  /// - more than one saved keyboard matches (ambiguous; switching would be a
  ///   coin flip, so the current selection is kept).
  static func keyboardToSelect(
    forHIDProductName productName: String,
    savedKeyboards: [KeyboardDevice],
    selectedUUID: String?
  ) -> String? {
    let needle = normalize(productName)
    guard !needle.isEmpty else { return nil }

    let matches = savedKeyboards.filter { normalize($0.name) == needle }
    guard !matches.isEmpty else { return nil }
    if let selectedUUID, matches.contains(where: { $0.uuid == selectedUUID }) {
      return nil
    }
    guard matches.count == 1 else { return nil }
    return matches[0].uuid
  }

  private static func normalize(_ name: String) -> String {
    name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }
}
