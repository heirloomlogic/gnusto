// swift-tools-version: 6.2

import PackageDescription

// The engine compiles an MCP play-test server into every game it builds — a
// second program, larger than the engine itself, that an agent drives over
// stdio. It is on by default, because that is what makes this package
// play-testable out of the box (`bin/gnusto-mcp`, `.mcp.json`). Turning this
// package's `Playtest` trait off turns the engine's off with it, and then the
// server is not in the binary at all and `GNUSTO_MCP` is refused rather than
// honoured. `bin/export-game` and `.github/workflows/release.yml` already build
// that way, since a binary you hand to somebody else is the one that should not
// carry it.
//
// The forwarding is not optional: a dependency's default traits are enabled
// whatever the root package does, so without this line the engine's server
// would ship even from a build that asked for no traits at all.
let gnusto: Set<Package.Dependency.Trait> = [
    .trait(name: "Playtest", condition: .when(traits: ["Playtest"]))
]

let package = Package(
    name: "MyGame",
    platforms: [
        .macOS(.v15)
    ],
    traits: [
        .trait(name: "Playtest", description: "Compile the Gnusto play-test server into this game."),
        .default(enabledTraits: ["Playtest"]),
    ],
    // bin/new-game rewrites the single line carrying the marker below, to a
    // version-pinned URL by default or to another path under --dep-path. It is
    // one line so that rewriting it is one substitution rather than a parse.
    // The explicit `name:` is needed only by the path form, because a checkout
    // directory does not have to be called "Gnusto".
    dependencies: [
        .package(name: "Gnusto", path: "../..", traits: gnusto)  // gnusto-dependency
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
