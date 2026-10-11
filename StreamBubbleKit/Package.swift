// swift-tools-version: 6.0
import PackageDescription

// The logic that does not need a screen, a camera, or a permission prompt lives here, so
// `swift test` can check it in seconds without a build of the app.
let package = Package(
    name: "StreamBubbleKit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "StreamBubbleKit", targets: ["StreamBubbleKit"]),
    ],
    targets: [
        .target(name: "StreamBubbleKit"),
        .testTarget(name: "StreamBubbleKitTests", dependencies: ["StreamBubbleKit"]),
    ],
    swiftLanguageModes: [.v6]
)
