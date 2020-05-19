// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Frecency",
    products: [
        .library(
            name: "Frecency",
            targets: ["Frecency"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Quick/Quick.git", .upToNextMajor(from: "2.2.0")),
        .package(url: "https://github.com/Quick/Nimble.git", .upToNextMajor(from: "8.0.9"))
    ],
    targets: [
        .target(
            name: "Frecency",
            dependencies: []),
        .testTarget(
            name: "FrecencyTests",
            dependencies: ["Frecency", "Quick", "Nimble"]),
    ]
)
