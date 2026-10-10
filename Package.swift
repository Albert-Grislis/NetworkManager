// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NetworkManager",
    platforms: [
        .iOS(.v26),
    ],
    products: [
        .library(
            name: "NetworkManager",
            type: .dynamic,
            targets: [
                "NetworkManager",
            ]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/Albert-Grislis/Utils",
            from: "1.2.0"
        ),
    ],
    targets: [
        .target(
            name: "NetworkManager",
            dependencies: [
                "Utils",
            ]
        ),
        .testTarget(
            name: "NetworkManagerTests",
            dependencies: [
                "NetworkManager",
            ]
        ),
    ]
)
