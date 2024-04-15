// swift-tools-version: 5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Confidence",
    platforms: [
        .iOS(.v14),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "ConfidenceProvider",
            targets: ["ConfidenceProvider"]),
        .library(
            name: "Confidence",
            targets: ["Confidence"])
    ],
    dependencies: [
        .package(url: "git@github.com:open-feature/swift-sdk.git", from: "0.1.0"),
    ],
    targets: [
        // Internal definitions shared between Confidence and ConfidenceProvider
        // These are not exposed to the consumers of Confidence or ConfidenceProvider
        .target(
            name: "Common",
            dependencies: [],
            plugins: []
        ),
        .target(
            name: "Confidence",
            dependencies: [
                "Common"
            ],
            plugins: []
        ),
        .target(
            name: "ConfidenceProvider",
            dependencies: [
                .product(name: "OpenFeature", package: "swift-sdk"),
                "Confidence",
                "Common"
            ],
            plugins: []
        ),
        .testTarget(
            name: "ConfidenceProviderTests",
            dependencies: [
                "ConfidenceProvider",
                "Common",
            ]
        ),
        .testTarget(
            name: "ConfidenceTests",
            dependencies: [
                "Confidence",
            ]
        ),
    ]
)
