// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FeatureCampus",
    platforms: [.iOS(.v18)],
    products: [.library(name: "FeatureCampus", targets: ["FeatureCampus"])],
    dependencies: [.package(path: "../GxuCore"), .package(path: "../GxuDesign"), .package(path: "../FeatureSchedule")],
    targets: [
        .target(name: "FeatureCampus", dependencies: [
            .product(name: "GxuFoundation", package: "GxuCore"),
            .product(name: "GxuNetworking", package: "GxuCore"),
            .product(name: "GxuAuth", package: "GxuCore"),
            .product(name: "GxuStorage", package: "GxuCore"),
            .product(name: "GxuDesign", package: "GxuDesign"),
            .product(name: "ScheduleKit", package: "FeatureSchedule"),
            .product(name: "ScheduleUI", package: "FeatureSchedule"),
        ], resources: [.copy("Resources/campus-places.json"), .copy("Resources/teach-buildings.json")]),
        .testTarget(
            name: "FeatureCampusTests",
            dependencies: ["FeatureCampus", .product(name: "GxuTestSupport", package: "GxuCore")],
            resources: [.copy("Fixtures")]
        ),
    ]
)
