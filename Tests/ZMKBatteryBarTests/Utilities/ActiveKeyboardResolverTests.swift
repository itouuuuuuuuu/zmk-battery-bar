import Foundation
import Testing

@testable import ZMKBatteryBar

@Suite("ActiveKeyboardResolver")
struct ActiveKeyboardResolverTests {
  private let corne = KeyboardDevice(uuid: "u-corne", name: "Corne")
  private let sofle = KeyboardDevice(uuid: "u-sofle", name: "Sofle")

  @Test("switches to the saved keyboard whose name matches the HID product")
  func switchesToMatchingKeyboard() {
    let result = ActiveKeyboardResolver.keyboardToSelect(
      forHIDProductName: "Sofle",
      savedKeyboards: [corne, sofle],
      selectedUUID: corne.uuid
    )
    #expect(result == sofle.uuid)
  }

  @Test("does nothing when the selected keyboard already matches")
  func noSwitchWhenAlreadySelected() {
    let result = ActiveKeyboardResolver.keyboardToSelect(
      forHIDProductName: "Corne",
      savedKeyboards: [corne, sofle],
      selectedUUID: corne.uuid
    )
    #expect(result == nil)
  }

  @Test("ignores devices that are not saved keyboards")
  func ignoresUnknownDevices() {
    let result = ActiveKeyboardResolver.keyboardToSelect(
      forHIDProductName: "Apple Internal Keyboard / Trackpad",
      savedKeyboards: [corne, sofle],
      selectedUUID: corne.uuid
    )
    #expect(result == nil)
  }

  @Test("selects a matching keyboard when nothing is selected yet")
  func selectsWhenNothingSelected() {
    let result = ActiveKeyboardResolver.keyboardToSelect(
      forHIDProductName: "Corne",
      savedKeyboards: [corne, sofle],
      selectedUUID: nil
    )
    #expect(result == corne.uuid)
  }

  @Test("matches case-insensitively and ignores surrounding whitespace")
  func normalizesNames() {
    let result = ActiveKeyboardResolver.keyboardToSelect(
      forHIDProductName: "  sofle \n",
      savedKeyboards: [corne, sofle],
      selectedUUID: corne.uuid
    )
    #expect(result == sofle.uuid)
  }

  @Test("keeps the current selection when several saved keyboards share the name")
  func ambiguousNamesDoNotSwitch() {
    let sofle2 = KeyboardDevice(uuid: "u-sofle-2", name: "Sofle")
    let result = ActiveKeyboardResolver.keyboardToSelect(
      forHIDProductName: "Sofle",
      savedKeyboards: [corne, sofle, sofle2],
      selectedUUID: corne.uuid
    )
    #expect(result == nil)
  }

  @Test("keeps the selection when it is one of several same-named keyboards")
  func ambiguousNamesKeepSelectedTwin() {
    let sofle2 = KeyboardDevice(uuid: "u-sofle-2", name: "Sofle")
    let result = ActiveKeyboardResolver.keyboardToSelect(
      forHIDProductName: "Sofle",
      savedKeyboards: [sofle, sofle2],
      selectedUUID: sofle2.uuid
    )
    #expect(result == nil)
  }

  @Test("empty product name never switches")
  func emptyNameDoesNothing() {
    let result = ActiveKeyboardResolver.keyboardToSelect(
      forHIDProductName: "   ",
      savedKeyboards: [corne],
      selectedUUID: nil
    )
    #expect(result == nil)
  }
}
