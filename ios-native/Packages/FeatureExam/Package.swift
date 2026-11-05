// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FeatureExam",
    platforms: [.iOS(.v18)],
    products: [.library(name: "FeatureExam", targets: ["FeatureExam"])],
    dependencies: [.package(path: "../GxuCore"), .package(path: "../GxuDesign")],
    targets: [
        .target(name: "FeatureExam", dependencies: [
            .product(name: "GxuFoundation", package: "GxuCore"),
            .product(name: "GxuNetworking", package: "GxuCore"),
            .product(name: "GxuAuth", package: "GxuCore"),
            .product(name: "GxuStorage", package: "GxuCore"),
            .product(name: "GxuDesign", package: "GxuDesign"),
        ]),
    ]
)
