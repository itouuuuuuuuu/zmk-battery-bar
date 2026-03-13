import Foundation

final class AppSettings {
  private let defaults = UserDefaults.standard

  private enum Keys {
    static let selectedKeyboardUUID = "selectedKeyboardUUID"
    static let savedKeyboards = "savedKeyboards"
  }

  var selectedKeyboardUUID: String? {
    get { defaults.string(forKey: Keys.selectedKeyboardUUID) }
    set { defaults.set(newValue, forKey: Keys.selectedKeyboardUUID) }
  }

  var savedKeyboards: [KeyboardDevice] {
    get {
      guard let data = defaults.data(forKey: Keys.savedKeyboards),
            let devices = try? JSONDecoder().decode([KeyboardDevice].self, from: data)
      else { return [] }
      return devices
    }
    set {
      if let data = try? JSONEncoder().encode(newValue) {
        defaults.set(data, forKey: Keys.savedKeyboards)
      }
    }
  }

  var selectedKeyboard: KeyboardDevice? {
    guard let uuid = selectedKeyboardUUID else { return nil }
    return savedKeyboards.first { $0.uuid == uuid }
  }

  func addKeyboard(uuid: String, name: String) {
    var keyboards = savedKeyboards
    if !keyboards.contains(where: { $0.uuid == uuid }) {
      keyboards.append(KeyboardDevice(uuid: uuid, name: name))
      savedKeyboards = keyboards
    }
  }

  func removeKeyboard(uuid: String) {
    var keyboards = savedKeyboards
    keyboards.removeAll { $0.uuid == uuid }
    savedKeyboards = keyboards

    if selectedKeyboardUUID == uuid {
      selectedKeyboardUUID = nil
    }
  }
}
