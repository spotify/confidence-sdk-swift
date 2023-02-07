// swift-tools-version: 5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "KonfidensProvider",
    platforms: [
        .iOS(.v14),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "KonfidensProvider",
            targets: ["KonfidensProvider"])
    ],
    dependencies: [
        .package(url: "git@github.com:spotify/openfeature-swift-sdk.git", from: "0.1.0"),
    ],
    targets: [
        .target(
            name: "KonfidensProvider",
            dependencies: [
                .product(name: "OpenFeature", package: "openfeature-swift-sdk"),
            ],
            plugins: []
        ),
        .testTarget(
            name: "KonfidensProviderTests",
            dependencies: [
                "KonfidensProvider",
            ]
        )
    ]
)
