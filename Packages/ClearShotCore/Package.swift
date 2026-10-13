// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ClearShotCore",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "ClearShotCore", targets: ["ClearShotCore"]),
    ],
    targets: [
        .target(name: "ClearShotCore"),
        .testTarget(name: "ClearShotCoreTests", dependencies: ["ClearShotCore"]),
    ]
)
