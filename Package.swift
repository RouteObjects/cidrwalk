// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "cidrwalk",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .executable(name: "cidrwalk", targets: ["cidrwalk"]),
    ],
    dependencies: [
        .package(path: "../swift-cidr"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.7.0"),
    ],
    targets: [
        .executableTarget(
            name: "cidrwalk",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "CIDR", package: "swift-cidr"),
            ]
        ),
        .testTarget(
            name: "cidrwalkTests",
            dependencies: ["cidrwalk"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
