// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Utils",
    platforms: [.iOS(.v15)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "Utils",
            targets: ["Utils"]
        )
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
         .package(url: "https://github.com/devicekit/DeviceKit", from: "5.0.0"),
         .package(url: "https://github.com/onevcat/Kingfisher", from: "7.9.1"),
         .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.2.2")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "Utils",
            dependencies: [
                .product(name: "DeviceKit", package: "DeviceKit"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "Kingfisher", package: "Kingfisher")
            ]
        )
    ]
)
