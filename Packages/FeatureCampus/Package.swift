// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FeatureCampus",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "FeatureCampus", targets: ["FeatureCampus"]),
        .library(name: "CampusKit", targets: ["CampusKit"]),
    ],
    dependencies: [.package(path: "../GxuCore"), .package(path: "../GxuDesign"), .package(path: "../FeatureSchedule")],
    targets: [
        .target(name: "CampusKit", dependencies: [
            .product(name: "GxuFoundation", package: "GxuCore"),
            .product(name: "GxuAuth", package: "GxuCore"),
            .product(name: "GxuStorage", package: "GxuCore"),
            .product(name: "ScheduleKit", package: "FeatureSchedule"),
        ]),
        .target(name: "FeatureCampus", dependencies: [
            "CampusKit",
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
            dependencies: ["FeatureCampus", "CampusKit", .product(name: "GxuTestSupport", package: "GxuCore")],
            resources: [.copy("Fixtures")]
        ),
    ]
)
