// swift-tools-version: 5.8.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NetworkManager",
    platforms: [
        .iOS(.v16),
    ],
    products: [
        .library(
            name: "NetworkManager",
            type: .dynamic,
            targets: [
                "NetworkManager"
            ]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/Albert-Grislis/Utils",
            branch: "main"
        ),
    ],
    targets: [
        .target(
            name: "NetworkManager",
            dependencies: [
                .product(
                    name: "Utils",
                    package: "Utils",
                    condition: .none
                ),
            ]
        ),
    ]
)
