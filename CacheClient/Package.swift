// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CacheClient",
    platforms: [.iOS(.v15)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "CacheClient",
            targets: ["CacheClient"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "0.6.0"),
        .package(url: "https://github.com/hyperoslo/Cache", from: "6.0.0"),
        .package(path: "../Utils"),
        .package(path: "../DataTypeExtensions")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "CacheClient",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "Utils", package: "Utils"),
                .product(name: "DataTypeExtensions", package: "DataTypeExtensions"),
                .product(name: "Cache", package: "Cache")
            ]
        ),
        .testTarget(
            name: "CacheClientTests",
            dependencies: ["CacheClient"]
        )
    ]
)
