import Testing

@testable import ZMKBatteryBar

@Suite("DescriptorRoleParser")
struct DescriptorRoleParserTests {
  @Test(
    "central variants",
    arguments: ["central", "Central", "CENTRAL", "Main Central", "central side"]
  )
  func centralVariants(input: String) {
    #expect(DescriptorRoleParser.role(from: input) == .central)
  }

  @Test(
    "peripheral variants",
    arguments: ["peripheral", "Peripheral", "PERIPHERAL", "Right Peripheral"]
  )
  func peripheralVariants(input: String) {
    #expect(DescriptorRoleParser.role(from: input) == .peripheral)
  }

  @Test("nil input → nil")
  func nilInput() {
    #expect(DescriptorRoleParser.role(from: nil) == nil)
  }

  @Test(
    "unrecognized strings → nil",
    arguments: ["", "unknown", "left", "right", "battery"]
  )
  func unrecognized(input: String) {
    #expect(DescriptorRoleParser.role(from: input) == nil)
  }

  @Test("when both tokens appear, central wins")
  func bothTokensFavorCentral() {
    #expect(DescriptorRoleParser.role(from: "central peripheral") == .central)
    #expect(DescriptorRoleParser.role(from: "peripheral central") == .central)
  }
}
