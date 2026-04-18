import Foundation
import Testing

@testable import ZMKBatteryBar

@Suite("AppSettings")
struct AppSettingsTests {
  // Use a fresh, isolated UserDefaults suite per test so state never leaks.
  private func makeSettings(file: String = #fileID, line: Int = #line) -> AppSettings {
    let suiteName = "ZMKBatteryBarTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return AppSettings(defaults: defaults)
  }

  @Test("savedKeyboards starts empty")
  func savedKeyboardsDefaultsEmpty() {
    let settings = makeSettings()
    #expect(settings.savedKeyboards.isEmpty)
  }

  @Test("addKeyboard appends a new entry")
  func addKeyboardAppends() {
    let settings = makeSettings()
    settings.addKeyboard(uuid: "u1", name: "Corne")

    #expect(settings.savedKeyboards.count == 1)
    #expect(settings.savedKeyboards[0].uuid == "u1")
    #expect(settings.savedKeyboards[0].name == "Corne")
  }

  @Test("addKeyboard is idempotent on same UUID")
  func addKeyboardDeduplicates() {
    let settings = makeSettings()
    settings.addKeyboard(uuid: "u1", name: "Corne")
    settings.addKeyboard(uuid: "u1", name: "Corne again")

    #expect(settings.savedKeyboards.count == 1)
    #expect(settings.savedKeyboards[0].name == "Corne")
  }

  @Test("savedKeyboards persists via JSON and reloads identical")
  func savedKeyboardsRoundTrip() {
    let suiteName = "ZMKBatteryBarTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let settingsWrite = AppSettings(defaults: defaults)
    settingsWrite.addKeyboard(uuid: "u1", name: "A")
    settingsWrite.addKeyboard(uuid: "u2", name: "B")

    let settingsRead = AppSettings(defaults: defaults)
    #expect(settingsRead.savedKeyboards.map(\.uuid) == ["u1", "u2"])
    #expect(settingsRead.savedKeyboards.map(\.name) == ["A", "B"])
  }

  @Test("updateKeyboard mutates the targeted entry")
  func updateKeyboardMutates() {
    let settings = makeSettings()
    settings.addKeyboard(uuid: "u1", name: "A")
    settings.updateKeyboard(uuid: "u1") { device in
      device.labelStyle = .leftRight
      device.swapSides = true
    }

    #expect(settings.savedKeyboards[0].labelStyle == .leftRight)
    #expect(settings.savedKeyboards[0].swapSides == true)
  }

  @Test("updateKeyboard ignores unknown UUID")
  func updateKeyboardIgnoresUnknown() {
    let settings = makeSettings()
    settings.addKeyboard(uuid: "u1", name: "A")
    settings.updateKeyboard(uuid: "unknown") { device in
      device.labelStyle = .leftRight
    }

    #expect(settings.savedKeyboards[0].labelStyle == .centralPeripheral)
  }

  @Test("removeKeyboard clears selectedKeyboardUUID when matching")
  func removeKeyboardClearsSelection() {
    let settings = makeSettings()
    settings.addKeyboard(uuid: "u1", name: "A")
    settings.selectedKeyboardUUID = "u1"

    settings.removeKeyboard(uuid: "u1")

    #expect(settings.savedKeyboards.isEmpty)
    #expect(settings.selectedKeyboardUUID == nil)
  }

  @Test("removeKeyboard keeps selection when removing other UUID")
  func removeKeyboardKeepsSelectionForOther() {
    let settings = makeSettings()
    settings.addKeyboard(uuid: "u1", name: "A")
    settings.addKeyboard(uuid: "u2", name: "B")
    settings.selectedKeyboardUUID = "u1"

    settings.removeKeyboard(uuid: "u2")

    #expect(settings.selectedKeyboardUUID == "u1")
  }

  @Test("selectedKeyboard returns the matching device")
  func selectedKeyboardLookup() {
    let settings = makeSettings()
    settings.addKeyboard(uuid: "u1", name: "A")
    settings.addKeyboard(uuid: "u2", name: "B")
    settings.selectedKeyboardUUID = "u2"

    #expect(settings.selectedKeyboard?.uuid == "u2")
    #expect(settings.selectedKeyboard?.name == "B")
  }

  @Test("selectedKeyboard nil when UUID not in saved list")
  func selectedKeyboardMissing() {
    let settings = makeSettings()
    settings.selectedKeyboardUUID = "ghost"
    #expect(settings.selectedKeyboard == nil)
  }
}
