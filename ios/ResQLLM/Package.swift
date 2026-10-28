// swift-tools-version: 6.0
import PackageDescription

// ResQLLM: the on-device model, Gemma 4 E4B on LiteRT-LM (Metal GPU). Android runs the same .litertlm
// file through the Kotlin API. Kept out of ResQKit so the app and its tests build without fetching the
// LiteRT-LM binaries until the pipeline is wired in.
let package = Package(
    name: "ResQLLM",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ResQLLM", targets: ["ResQLLM"]),
    ],
    dependencies: [
        .package(path: "../ResQKit"),
        .package(url: "https://github.com/google-ai-edge/LiteRT-LM.git", exact: "0.18.1"),
    ],
    targets: [
        .target(name: "ResQLLM", dependencies: [
            .product(name: "ResQCore", package: "ResQKit"),
            .product(name: "LiteRTLM", package: "LiteRT-LM"),
        ]),
    ]
)
