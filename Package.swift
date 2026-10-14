// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AutoSignStoreCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "AutoSignStoreCore", targets: ["AutoSignStoreCore"])],
    targets: [
        .target(name: "AutoSignStoreCore", path: "AutoSignStore/Core"),
        .testTarget(name: "AutoSignStoreTests", dependencies: ["AutoSignStoreCore"], path: "Tests")
    ]
)
