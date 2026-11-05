// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FeatureCampus",
    platforms: [.iOS(.v18)],
    products: [.library(name: "FeatureCampus", targets: ["FeatureCampus"])],
    dependencies: [.package(path: "../GxuCore"), .package(path: "../GxuDesign")],
    targets: [
        .target(name: "FeatureCampus", dependencies: [
            .product(name: "GxuFoundation", package: "GxuCore"),
            .product(name: "GxuNetworking", package: "GxuCore"),
            .product(name: "GxuAuth", package: "GxuCore"),
            .product(name: "GxuStorage", package: "GxuCore"),
            .product(name: "GxuDesign", package: "GxuDesign"),
        ]),
    ]
)
