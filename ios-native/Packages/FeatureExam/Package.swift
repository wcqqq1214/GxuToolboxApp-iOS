// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FeatureExam",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "ExamKit", targets: ["ExamKit"]),
        .library(name: "ExamUI", targets: ["ExamUI"]),
        // 兼容旧名：= ExamKit + ExamUI
        .library(name: "FeatureExam", targets: ["FeatureExam"]),
    ],
    dependencies: [
        .package(path: "../GxuCore"), .package(path: "../GxuDesign"), .package(path: "../FeatureSchedule"),
    ],
    targets: [
        .target(name: "ExamKit", dependencies: [
            .product(name: "GxuFoundation", package: "GxuCore"),
            .product(name: "GxuNetworking", package: "GxuCore"),
            .product(name: "GxuAuth", package: "GxuCore"),
            .product(name: "GxuStorage", package: "GxuCore"),
            .product(name: "ScheduleKit", package: "FeatureSchedule"),
        ]),
        .target(name: "ExamUI", dependencies: [
            "ExamKit",
            .product(name: "GxuDesign", package: "GxuDesign"),
        ]),
        .target(name: "FeatureExam", dependencies: ["ExamKit", "ExamUI"]),
        .testTarget(name: "ExamKitTests", dependencies: [
            "ExamKit",
            .product(name: "GxuTestSupport", package: "GxuCore"),
        ], resources: [.copy("Fixtures")]),
    ]
)
