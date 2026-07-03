// swift-tools-version: 6.2

import Foundation
import PackageDescription

// Dev-only tooling (the Persnoop swift-format linter) must not leak into
// downstream consumers' dependency graphs: a build-tool plugin attached to a
// published target makes Persnicket a hard dependency of every package that
// depends on Gnusto. SwiftPM has no first-class dev-dependencies, so gate it on
// a gitignored `.dev-tooling` sentinel, present only in a maintainer's working
// clone (and created as a step in CI). `#filePath` anchors the lookup to this
// manifest's directory, independent of the current working directory.
//
// Note: SwiftPM caches the evaluated manifest keyed on this file's text, so
// toggling the sentinel after a build requires `swift package purge-cache`.
let packageDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let devSentinel = packageDir.appendingPathComponent(".dev-tooling").path
let isDevBuild = FileManager.default.fileExists(atPath: devSentinel)

// The DocC plugin is a command plugin (`swift package generate-documentation`),
// invoked only when building the documentation — never on a normal build. Like
// Persnicket, it is gated behind the dev sentinel so it doesn't leak into
// downstream consumers' dependency graphs; the Documentation CI workflow creates
// `.dev-tooling` before generating the docs.
let devDependencies: [Package.Dependency] = isDevBuild
    ? [
        .package(url: "https://github.com/HeirloomLogic/Persnicket", from: "2.1.0"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.5.0"),
    ]
    : []

let devPlugins: [Target.PluginUsage] = isDevBuild
    ? [.plugin(name: "Persnoop", package: "Persnicket")]
    : []

let package = Package(
    name: "Gnusto",
    platforms: [
        .macOS(.v15)  // Synchronization.Mutex
    ],
    products: [
        .library(name: "Gnusto", targets: ["Gnusto"]),
        .library(name: "GnustoDangerousDark", targets: ["GnustoDangerousDark"]),
        .library(name: "GnustoScoring", targets: ["GnustoScoring"]),
        .library(name: "GnustoActors", targets: ["GnustoActors"]),
        .library(name: "GnustoMeleeCombat", targets: ["GnustoMeleeCombat"]),
        .executable(name: "CloakOfDarkness", targets: ["CloakOfDarkness"]),
        .executable(name: "Zork1", targets: ["Zork1"]),
    ],
    dependencies: devDependencies,
    targets: [
        .target(name: "Gnusto", plugins: devPlugins),
        .target(
            name: "GnustoDangerousDark",
            dependencies: ["Gnusto"],
            plugins: devPlugins
        ),
        .target(
            name: "GnustoScoring",
            dependencies: ["Gnusto"],
            plugins: devPlugins
        ),
        .target(
            name: "GnustoActors",
            dependencies: ["Gnusto"],
            plugins: devPlugins
        ),
        .target(
            name: "GnustoMeleeCombat",
            dependencies: ["Gnusto"],
            plugins: devPlugins
        ),
        .executableTarget(
            name: "CloakOfDarkness",
            dependencies: ["Gnusto"],
            plugins: devPlugins
        ),
        .executableTarget(
            name: "Zork1",
            dependencies: [
                "Gnusto", "GnustoDangerousDark", "GnustoScoring", "GnustoActors",
                "GnustoMeleeCombat",
            ],
            plugins: devPlugins
        ),
        .testTarget(
            name: "GnustoTests",
            dependencies: [
                "Gnusto", "GnustoDangerousDark", "GnustoScoring", "GnustoActors",
                "GnustoMeleeCombat", "CloakOfDarkness", "Zork1",
            ],
            plugins: devPlugins
        ),
    ]
)
