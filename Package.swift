// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MetalRenderKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MetalRenderKit", targets: ["MetalRenderKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/BurgerMike/Generator3D.git", branch: "main")
    ],
    targets: [
        .target(
            name: "MetalRenderKit",
            dependencies: [
                .product(name: "Generator3D", package: "Generator3D"),
            ]
        ),
    ]
)
