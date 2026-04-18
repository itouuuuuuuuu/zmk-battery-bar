import Foundation
import Testing

@testable import ZMKBatteryBar

@Suite("KeyboardDevice")
struct KeyboardDeviceTests {
  // MARK: - Codable round-trip

  @Test("encodes and decodes round-trip")
  func codableRoundTrip() throws {
    let original = KeyboardDevice(
      uuid: "abc",
      name: "Corne",
      labelStyle: .leftRight,
      swapSides: true
    )
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(KeyboardDevice.self, from: data)

    #expect(decoded.uuid == "abc")
    #expect(decoded.name == "Corne")
    #expect(decoded.labelStyle == .leftRight)
    #expect(decoded.swapSides == true)
  }

  @Test("missing labelStyle defaults to centralPeripheral")
  func missingLabelStyleDefaults() throws {
    let json = #"{"uuid":"x","name":"Kyria"}"#
    let decoded = try JSONDecoder().decode(KeyboardDevice.self, from: Data(json.utf8))

    #expect(decoded.labelStyle == .centralPeripheral)
    #expect(decoded.swapSides == false)
  }

  @Test("missing swapSides defaults to false")
  func missingSwapSidesDefaults() throws {
    let json = #"{"uuid":"x","name":"K","labelStyle":"leftRight"}"#
    let decoded = try JSONDecoder().decode(KeyboardDevice.self, from: Data(json.utf8))

    #expect(decoded.labelStyle == .leftRight)
    #expect(decoded.swapSides == false)
  }

  // MARK: - labelShort

  @Test(
    "labelShort covers all 2x2x2 combinations",
    arguments: [
      (SideLabelStyle.centralPeripheral, false, KeyboardSide.central, "C"),
      (SideLabelStyle.centralPeripheral, false, KeyboardSide.peripheral, "P"),
      (SideLabelStyle.centralPeripheral, true, KeyboardSide.central, "C"),
      (SideLabelStyle.centralPeripheral, true, KeyboardSide.peripheral, "P"),
      (SideLabelStyle.leftRight, false, KeyboardSide.central, "L"),
      (SideLabelStyle.leftRight, false, KeyboardSide.peripheral, "R"),
      (SideLabelStyle.leftRight, true, KeyboardSide.central, "R"),
      (SideLabelStyle.leftRight, true, KeyboardSide.peripheral, "L"),
    ]
  )
  func labelShortTable(
    style: SideLabelStyle,
    swap: Bool,
    side: KeyboardSide,
    expected: String
  ) {
    let device = KeyboardDevice(uuid: "u", name: "n", labelStyle: style, swapSides: swap)
    #expect(device.labelShort(for: side) == expected)
  }

  @Test("centralLabelShort / peripheralLabelShort mirror labelShort")
  func convenienceAccessors() {
    let device = KeyboardDevice(uuid: "u", name: "n", labelStyle: .leftRight, swapSides: true)
    #expect(device.centralLabelShort == device.labelShort(for: .central))
    #expect(device.peripheralLabelShort == device.labelShort(for: .peripheral))
  }

  // MARK: - assignLetter

  @Test("assignLetter nil resets to centralPeripheral")
  func assignLetterNilResets() {
    var device = KeyboardDevice(uuid: "u", name: "n", labelStyle: .leftRight, swapSides: true)
    device.assignLetter(nil, to: .central)

    #expect(device.labelStyle == .centralPeripheral)
    #expect(device.swapSides == false)
  }

  @Test("assignLetter L on central keeps swap=false")
  func assignLetterLOnCentral() {
    var device = KeyboardDevice(uuid: "u", name: "n")
    device.assignLetter("L", to: .central)

    #expect(device.labelStyle == .leftRight)
    #expect(device.swapSides == false)
  }

  @Test("assignLetter R on central sets swap=true")
  func assignLetterROnCentral() {
    var device = KeyboardDevice(uuid: "u", name: "n")
    device.assignLetter("R", to: .central)

    #expect(device.labelStyle == .leftRight)
    #expect(device.swapSides == true)
  }

  @Test("assignLetter L on peripheral sets swap=true")
  func assignLetterLOnPeripheral() {
    var device = KeyboardDevice(uuid: "u", name: "n")
    device.assignLetter("L", to: .peripheral)

    #expect(device.labelStyle == .leftRight)
    #expect(device.swapSides == true)
  }

  @Test("assignLetter R on peripheral keeps swap=false")
  func assignLetterROnPeripheral() {
    var device = KeyboardDevice(uuid: "u", name: "n")
    device.assignLetter("R", to: .peripheral)

    #expect(device.labelStyle == .leftRight)
    #expect(device.swapSides == false)
  }
}
