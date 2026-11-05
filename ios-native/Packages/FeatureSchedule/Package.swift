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
        ]),
        .target(name: "ScheduleUI", dependencies: [
            "ScheduleKit",
            .product(name: "GxuDesign", package: "GxuDesign"),
        ]),
    ]
)
