// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "UIComponents",
    platforms: [.iOS(.v15)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "UIComponents",
            targets: ["UIComponents"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(path: "../UITheme"),
        .package(path: "../Utils"),
        .package(url: "https://github.com/onevcat/Kingfisher", from: "7.9.1"),
        .package(url: "https://github.com/pointfreeco/swift-identified-collections", from: "0.8.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "UIComponents",
            dependencies: [
                .product(name: "UITheme", package: "UITheme"),
                .product(name: "Utils", package: "Utils"),
                .product(name: "Kingfisher", package: "Kingfisher"),
                .product(name: "IdentifiedCollections", package: "swift-identified-collections")
            ]
        )
    ]
)
