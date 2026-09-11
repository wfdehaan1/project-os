// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "ProjectOSCore",
  platforms: [.macOS(.v26)],
  products: [
    .library(name: "ProjectOSCore", targets: ["ProjectOSCore"])
  ],
  targets: [
    .target(
      name: "ProjectOSCore",
      resources: [.process("Resources")]
    ),
    .testTarget(
      name: "ProjectOSCoreTests",
      dependencies: ["ProjectOSCore"]
    ),
  ]
)
