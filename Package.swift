// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "PriceLensCore",
    platforms: [.macOS(.v13)],
    products: [.library(name: "PriceLensCore", targets: ["PriceLensCore"])],
    targets: [
        .target(name: "PriceLensCore", path: "PriceLens/Core"),
        .testTarget(name: "PriceLensCoreTests", dependencies: ["PriceLensCore"], path: "PriceLensTests")
    ]
)
