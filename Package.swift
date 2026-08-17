// swift-tools-version: 5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Confidence",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
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
        .package(url: "https://github.com/open-feature/swift-sdk.git", .exact("0.6.0")),
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.20.2"),
    ],
    targets: [
        .target(
            name: "Confidence",
            dependencies: [],
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
