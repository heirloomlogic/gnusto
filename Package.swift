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

let devDependencies: [Package.Dependency] = isDevBuild
    ? [
        .package(url: "https://github.com/HeirloomLogic/Persnicket", from: "2.0.0")
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
        .executable(name: "CloakOfDarkness", targets: ["CloakOfDarkness"]),
    ],
    dependencies: devDependencies,
    targets: [
        .target(name: "Gnusto", plugins: devPlugins),
        .executableTarget(
            name: "CloakOfDarkness",
            dependencies: ["Gnusto"],
            plugins: devPlugins
        ),
        .testTarget(
            name: "GnustoTests",
            dependencies: ["Gnusto", "CloakOfDarkness"],
            plugins: devPlugins
        ),
    ]
)
