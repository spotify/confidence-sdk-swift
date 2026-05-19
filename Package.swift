// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Confidence",
    platforms: [
        // NOTE(unit-local experiment): bumped from iOS 14 / macOS 12 because the
        // ConfidenceLocalResolver dependency pulls in WasmKit, which requires
        // iOS 16 / macOS 14. Revert before merging upstream.
        .iOS(.v16),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ConfidenceOpenFeature",
            targets: ["ConfidenceProvider"]),
        .library(
            name: "Confidence",
            targets: ["Confidence"])
    ],
    dependencies: [
        .package(url: "https://github.com/open-feature/swift-sdk.git", .exact("0.5.0")),
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.20.2"),
        // NOTE(unit-local experiment): local path dep on the prototype package
        // inside the confidence-resolver worktree. Will not work on other
        // machines; this is purposely local-only.
        .package(path: "../../.compass-worktrees/semi-local/confidence-resolver/openfeature-provider/swift"),
    ],
    targets: [
        .target(
            name: "Confidence",
            dependencies: [
                .product(name: "ConfidenceLocalResolver", package: "swift"),
            ],
            plugins: []
        ),
        .target(
            name: "ConfidenceProvider",
            dependencies: [
                .product(name: "OpenFeature", package: "swift-sdk"),
                "Confidence"
            ],
            plugins: []
        ),
        .testTarget(
            name: "ConfidenceProviderTests",
            dependencies: [
                "ConfidenceProvider",
            ]
        ),
        .testTarget(
            name: "ConfidenceTests",
            dependencies: [
                "Confidence",
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ]
        ),
    ]
)
