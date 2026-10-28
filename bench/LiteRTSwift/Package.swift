// swift-tools-version: 6.0
import PackageDescription

// Runs bench prompts through the app's own LiteRTModel (ios/ResQLLM), the Swift code iOS ships.
let package = Package(
    name: "LiteRTSwift",
    platforms: [.macOS(.v14)],
    dependencies: [.package(path: "../../ios/ResQLLM"), .package(path: "../../ios/ResQKit")],
    targets: [
        .executableTarget(name: "LiteRTSwift", dependencies: [
            .product(name: "ResQLLM", package: "ResQLLM"),
            .product(name: "ResQCore", package: "ResQKit"),
        ]),
    ]
)
