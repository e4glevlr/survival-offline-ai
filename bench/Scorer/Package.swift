// swift-tools-version: 6.0
import PackageDescription

// Runs model outputs through the app's real AnswerParser + GroundingValidator.
let package = Package(
    name: "Scorer",
    platforms: [.macOS(.v14)],
    dependencies: [.package(path: "../../ios/ResQKit")],
    targets: [
        .executableTarget(name: "Scorer", dependencies: [.product(name: "ResQCore", package: "ResQKit")]),
    ]
)
