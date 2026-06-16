// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EyelineKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "EyelineKit", targets: ["EyelineKit"]),
    ],
    targets: [
        .target(name: "EyelineKit"),
        .testTarget(name: "EyelineKitTests", dependencies: ["EyelineKit"]),
    ],
    swiftLanguageModes: [.v5]   // skip Swift 6 strict-concurrency noise during early dev
)
