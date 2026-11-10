// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GxuDesign",
    platforms: [.iOS(.v18)],
    products: [.library(name: "GxuDesign", targets: ["GxuDesign"])],
    dependencies: [.package(path: "../GxuCore")],
    targets: [
        .target(name: "GxuDesign", dependencies: [.product(name: "GxuFoundation", package: "GxuCore")]),
        .testTarget(name: "GxuDesignTests", dependencies: ["GxuDesign"]),
    ]
)
