// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "ZMKBatteryBar",
  platforms: [
    .macOS(.v14),
  ],
  targets: [
    .executableTarget(
      name: "ZMKBatteryBar",
      path: "Sources/ZMKBatteryBar",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    .testTarget(
      name: "ZMKBatteryBarTests",
      dependencies: ["ZMKBatteryBar"],
      path: "Tests/ZMKBatteryBarTests",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
  ]
)
