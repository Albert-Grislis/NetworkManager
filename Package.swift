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
            type: .dynamic,
            targets: ["NetworkManager"]),
    ],
    dependencies: [
        .package(name: "Utils", url: "https://github.com/Albert-Grislis/Utils", .branch("main"))
    ],
    targets: [
        .target(
            name: "NetworkManager",
            dependencies: [.product(name: "Utils", package: "Utils", condition: .none)]),
    ]
)
