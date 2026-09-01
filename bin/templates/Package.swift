// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MyGame",
    platforms: [
        .macOS(.v15)
    ],
    // bin/new-game rewrites the single line carrying the marker below, to a
    // version-pinned URL by default or to another path under --dep-path. It is
    // one line so that rewriting it is one substitution rather than a parse.
    // The explicit `name:` is needed only by the path form, because a checkout
    // directory does not have to be called "Gnusto".
    dependencies: [
        .package(name: "Gnusto", path: "../..")  // gnusto-dependency
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
