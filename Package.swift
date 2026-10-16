// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AutoSignStoreCore",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "AutoSignStoreCore", targets: ["AutoSignStoreCore"])],
    targets: [
        .target(name: "AutoSignStoreCore", path: "AutoSignStore/Core", resources: [.process("Resources")]),
        .testTarget(name: "AutoSignStoreTests", dependencies: ["AutoSignStoreCore"], path: "Tests")
    ]
)
