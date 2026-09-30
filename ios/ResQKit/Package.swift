// swift-tools-version: 6.0
import PackageDescription

// ResQKit
// - ResQCore: pure Swift (Foundation only). Everything here is ported 1:1 to Kotlin.
//   The unit tests are the cross-platform conformance spec: port them to JUnit
//   and both apps must produce the same outputs for the same inputs.
// - ResQUI: SwiftUI reference implementation of the design (maps to Jetpack Compose).
let package = Package(
    name: "ResQKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ResQCore", targets: ["ResQCore"]),
        .library(name: "ResQUI", targets: ["ResQUI"]),
    ],
    targets: [
        .target(name: "ResQCore"),
        .target(name: "ResQUI", dependencies: ["ResQCore"], resources: [.process("Resources")]),
        .testTarget(name: "ResQCoreTests", dependencies: ["ResQCore"]),
    ]
)
