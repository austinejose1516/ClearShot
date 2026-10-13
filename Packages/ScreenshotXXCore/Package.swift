// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ScreenshotXXCore",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "ScreenshotXXCore", targets: ["ScreenshotXXCore"]),
    ],
    targets: [
        .target(name: "ScreenshotXXCore"),
        .testTarget(name: "ScreenshotXXCoreTests", dependencies: ["ScreenshotXXCore"]),
    ]
)
