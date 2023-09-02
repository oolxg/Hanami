// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ImageClient",
    platforms: [.iOS(.v15)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "ImageClient",
            targets: ["ImageClient"]
        )
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "0.6.0"),
        .package(url: "https://github.com/kean/Nuke", from: "11.6.4"),
        .package(path: "../Utils")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "ImageClient",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "Utils", package: "Utils"),
                .product(name: "Nuke", package: "Nuke")
            ]
        ),
        .testTarget(
            name: "ImageClientTests",
            dependencies: ["ImageClient"]
        )
    ]
)
