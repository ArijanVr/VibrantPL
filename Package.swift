// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "VibrantPlus",
    platforms: [.macOS(.v26)],
    targets: [
        // Rules and data logic with no SwiftUI, so tests run without the app.
        // The app binary is built with XcodeGen (`./build.sh`), not with SwiftPM.
        .target(name: "VibrantPlusKit"),
        .testTarget(name: "VibrantPlusKitTests", dependencies: ["VibrantPlusKit"]),
    ]
)
