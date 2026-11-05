// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FeatureMisc",
    platforms: [.iOS(.v18)],
    products: [.library(name: "FeatureMisc", targets: ["FeatureMisc"])],
    dependencies: [.package(path: "../GxuCore"), .package(path: "../GxuDesign")],
    targets: [
        .target(name: "FeatureMisc", dependencies: [
            .product(name: "GxuFoundation", package: "GxuCore"),
            .product(name: "GxuNetworking", package: "GxuCore"),
            .product(name: "GxuAuth", package: "GxuCore"),
            .product(name: "GxuStorage", package: "GxuCore"),
            .product(name: "GxuDesign", package: "GxuDesign"),
        ]),
    ]
)
