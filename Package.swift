// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NetworkManager",
    platforms: [
        .iOS(.v13),
    ],
    products: [
        .library(
            name: "NetworkManager",
            targets: ["NetworkManager"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Albert-Grislis/Utils", from: Version(1, 0, 0))
    ],
    targets: [
        .target(
            name: "NetworkManager",
            dependencies: [.product(name: "Utils", package: "Utils", condition: .none)]),
        .testTarget(
            name: "NetworkManagerTests",
            dependencies: ["NetworkManager"]),
    ]
)
