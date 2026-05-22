// swift-tools-version: 6.3

//===----------------------------------------------------------------------===//
//
// This source file is part of the cidrwalk package.
//
// Copyright (c) 2026 Craig A. Munro
//
// Licensed under the Apache License, Version 2.0.
// See the LICENSE file for details.
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

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
        .package(url: "https://github.com/RouteObjects/swift-cidr.git", from: "0.1.0"),
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
