// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FeatureSchedule",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "ScheduleKit", targets: ["ScheduleKit"]),
        .library(name: "ScheduleUI", targets: ["ScheduleUI"]),
    ],
    dependencies: [.package(path: "../GxuCore"), .package(path: "../GxuDesign")],
    targets: [
        .target(name: "ScheduleKit", dependencies: [
            .product(name: "GxuFoundation", package: "GxuCore"),
            .product(name: "GxuNetworking", package: "GxuCore"),
            .product(name: "GxuAuth", package: "GxuCore"),
            .product(name: "GxuStorage", package: "GxuCore"),
        ], resources: [.copy("Resources/campus-calendar-fallback.json")]),
        .target(name: "ScheduleUI", dependencies: [
            "ScheduleKit",
            .product(name: "GxuDesign", package: "GxuDesign"),
        ]),
        .testTarget(
            name: "ScheduleUITests",
            dependencies: ["ScheduleUI", "ScheduleKit", .product(name: "GxuTestSupport", package: "GxuCore"),
                           .product(name: "GxuAuth", package: "GxuCore"), .product(name: "GxuNetworking", package: "GxuCore"),
                           .product(name: "GxuFoundation", package: "GxuCore"), .product(name: "GxuStorage", package: "GxuCore")]
        ),
        .testTarget(
            name: "ScheduleKitTests",
            dependencies: ["ScheduleKit", .product(name: "GxuTestSupport", package: "GxuCore")],
            resources: [.copy("Fixtures")]
        ),
    ]
)
