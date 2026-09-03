// swift-tools-version: 6.0
import PackageDescription

// Foundation Models is macOS 26+ / Apple silicon. Building this on an older SDK
// will fail at `import FoundationModels`, which is the intended signal.
let package = Package(
    name: "screen",
    platforms: [.macOS(.v26)],
    targets: [.executableTarget(name: "screen", path: "Sources/screen")]
)
