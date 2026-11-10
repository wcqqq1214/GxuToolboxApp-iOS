// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GxuCore",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "GxuFoundation", targets: ["GxuFoundation"]),
        .library(name: "GxuNetworking", targets: ["GxuNetworking"]),
        .library(name: "GxuAuth", targets: ["GxuAuth"]),
        .library(name: "GxuStorage", targets: ["GxuStorage"]),
        .library(name: "GxuTestSupport", targets: ["GxuTestSupport"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
    ],
    targets: [
        .target(name: "GxuFoundation"),
        .target(name: "GxuNetworking", dependencies: ["GxuFoundation"]),
        .target(name: "GxuStorage", dependencies: [
            "GxuFoundation",
            .product(name: "GRDB", package: "GRDB.swift"),
        ]),
        .target(name: "GxuAuth", dependencies: ["GxuFoundation", "GxuNetworking", "GxuStorage"]),
        .target(name: "GxuTestSupport", dependencies: ["GxuFoundation", "GxuNetworking", "GxuStorage", "GxuAuth"]),
        .testTarget(name: "GxuFoundationTests", dependencies: ["GxuFoundation"]),
        .testTarget(name: "GxuNetworkingTests", dependencies: ["GxuNetworking", "GxuTestSupport"]),
        .testTarget(name: "GxuStorageTests", dependencies: ["GxuStorage", "GxuTestSupport"]),
        .testTarget(name: "GxuAuthTests", dependencies: ["GxuAuth", "GxuTestSupport"]),
    ]
)
