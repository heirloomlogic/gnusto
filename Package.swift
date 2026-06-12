// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Gnusto",
    platforms: [
        .macOS(.v15)  // Synchronization.Mutex
    ],
    products: [
        .library(name: "Gnusto", targets: ["Gnusto"]),
        .executable(name: "CloakOfDarkness", targets: ["CloakOfDarkness"]),
    ],
    targets: [
        .target(name: "Gnusto"),
        .executableTarget(name: "CloakOfDarkness", dependencies: ["Gnusto"]),
        .testTarget(name: "GnustoTests", dependencies: ["Gnusto", "CloakOfDarkness"]),
    ]
)
