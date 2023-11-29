// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HUD",
    platforms: [.iOS(.v15)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "HUD",
            targets: ["HUD"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "0.6.0"),
        .package(path: "../UITheme")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "HUD",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "UITheme", package: "UITheme")
            ]
        ),
        .testTarget(
            name: "HUDTests",
            dependencies: ["HUD"]
        )
    ]
)
