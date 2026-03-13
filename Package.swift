// swift-tools-version: 5.9

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
      resources: [
        .copy("../../Resources/Info.plist"),
      ]
    ),
  ]
)
