// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FeatureCourse",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "FeatureCourse", targets: ["FeatureCourse"]),
        .library(name: "ClassWidgetKit", targets: ["ClassWidgetKit"]),
        .library(name: "ToolboxIntents", targets: ["ToolboxIntents"]),
    ],
    dependencies: [
        .package(path: "../GxuCore"), .package(path: "../GxuDesign"),
        .package(path: "../FeatureSchedule"), .package(path: "../FeatureExam"), .package(path: "../FeatureCampus"),
    ],
    targets: [
        .target(name: "FeatureCourse", dependencies: [
            .product(name: "GxuFoundation", package: "GxuCore"),
            .product(name: "GxuNetworking", package: "GxuCore"),
            .product(name: "GxuAuth", package: "GxuCore"),
            .product(name: "GxuStorage", package: "GxuCore"),
            .product(name: "GxuDesign", package: "GxuDesign"),
            .product(name: "ScheduleKit", package: "FeatureSchedule"),
            .product(name: "ExamKit", package: "FeatureExam"),
            .product(name: "ExamUI", package: "FeatureExam"),
        ]),
        .target(name: "ClassWidgetKit", dependencies: [
            .product(name: "FeatureCampus", package: "FeatureCampus"),
            .product(name: "GxuFoundation", package: "GxuCore"),
            .product(name: "GxuNetworking", package: "GxuCore"),
            .product(name: "GxuAuth", package: "GxuCore"),
            .product(name: "GxuStorage", package: "GxuCore"),
            .product(name: "ScheduleKit", package: "FeatureSchedule"),
            .product(name: "ExamKit", package: "FeatureExam"),
            .product(name: "GxuDesign", package: "GxuDesign"),
        ]),
        .target(name: "ToolboxIntents", dependencies: [
            "ClassWidgetKit",
            .product(name: "GxuFoundation", package: "GxuCore"),
            .product(name: "GxuAuth", package: "GxuCore"),
            .product(name: "GxuStorage", package: "GxuCore"),
            .product(name: "ScheduleKit", package: "FeatureSchedule"),
            .product(name: "ExamKit", package: "FeatureExam"),
        ]),
        .testTarget(name: "FeatureCourseTests", dependencies: [
            "FeatureCourse",
            .product(name: "ExamKit", package: "FeatureExam"),
            .product(name: "GxuTestSupport", package: "GxuCore"),
        ], resources: [.copy("Fixtures")]),
        .testTarget(name: "ClassWidgetKitTests", dependencies: [
            "ClassWidgetKit",
            .product(name: "FeatureCampus", package: "FeatureCampus"),
            .product(name: "GxuTestSupport", package: "GxuCore"),
        ]),
    ]
)
