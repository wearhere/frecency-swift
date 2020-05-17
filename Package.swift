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
    targets: [
        .target(
            name: "Frecency",
            dependencies: []),
        .testTarget(
            name: "Frecency-Tests",
            dependencies: ["Frecency"]),
    ]
)
