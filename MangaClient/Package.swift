// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MangaClient",
    platforms: [.iOS(.v15)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "MangaClient",
            targets: ["MangaClient"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "0.6.0"),
        .package(path: "../ModelKit"),
        .package(path: "../Utils"),
        .package(path: "../CacheClient"),
        .package(path: "../DataTypeExtensions")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "MangaClient",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "Utils", package: "Utils"),
                .product(name: "ModelKit", package: "ModelKit"),
                .product(name: "CacheClient", package: "CacheClient"),
                .product(name: "DataTypeExtensions", package: "DataTypeExtensions")
            ]
        ),
        .testTarget(
            name: "MangaClientTests",
            dependencies: ["MangaClient"]
        )
    ]
)
