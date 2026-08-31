// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Newton",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Newton",
            targets: ["Newton"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Newton",
            dependencies: [],
            path: "."
        )
    ]
)
