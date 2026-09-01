// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MyGame",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        // In your own copy, depend on Gnusto by URL instead:
        // .package(url: "https://github.com/HeirloomLogic/Gnusto", from: "0.1.0"),
        // (The explicit name is only needed by the path form, because the
        // repo's checkout directory doesn't have to be called "Gnusto".)
        .package(name: "Gnusto", path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "MyGame",
            dependencies: [
                .product(name: "Gnusto", package: "Gnusto")
            ]
        ),
        .testTarget(
            name: "MyGameTests",
            dependencies: [
                "MyGame",
                .product(name: "GnustoTestSupport", package: "Gnusto"),
            ]
        ),
    ]
)
