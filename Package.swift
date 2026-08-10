// swift-tools-version: 6.2

import CompilerPluginSupport
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

// Swift Testing builds exit tests — `#expect(processExitsWith:)`, the only way
// to assert on a `fatalError`'s message — on some platforms and not others, and
// the API is simply absent where it doesn't. Rather than repeat an OS list at
// every trap test, the platform policy is stated once, here, and the code says
// `#if GNUSTO_EXIT_TESTS`. Listing platforms in rather than out means a new one
// loses the trap tests until someone adds it, which is the safe direction: a
// silently skipped test beats a platform that cannot compile the suite.
let exitTests: [SwiftSetting] = [
    .define("GNUSTO_EXIT_TESTS", .when(platforms: [.macOS, .linux, .windows]))
]

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
        .library(name: "GnustoSpellcasting", targets: ["GnustoSpellcasting"]),
        .library(name: "GnustoClock", targets: ["GnustoClock"]),
        .library(name: "GnustoConversation", targets: ["GnustoConversation"]),
        .library(name: "GnustoTestSupport", targets: ["GnustoTestSupport"]),
        .executable(name: "CloakOfDarkness", targets: ["CloakOfDarkness"]),
        .executable(name: "Lighthouse", targets: ["Lighthouse"]),
        .executable(name: "Zork1", targets: ["Zork1"]),
        .executable(name: "Dungeon", targets: ["Dungeon"]),
        .executable(name: "Gramarye", targets: ["Gramarye"]),
        .executable(name: "Fulminate", targets: ["Fulminate"]),
        .executable(name: "KindlyDeep", targets: ["KindlyDeep"]),
    ],
    dependencies: devDependencies + [
        // The #verb macro's expansion machinery. Unlike the dev tooling above,
        // a macro target cannot hide behind the sentinel: the macro is public
        // API, so swift-syntax is a real dependency of every consumer.
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "601.0.0"..<"700.0.0")
    ],
    targets: [
        .macro(
            name: "GnustoMacros",
            dependencies: [
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ],
            plugins: devPlugins
        ),
        .target(name: "Gnusto", dependencies: ["GnustoMacros"], plugins: devPlugins),
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
        // A reusable spellcasting layer: at-will cantrips, memorized spells, an
        // energy pool, and one-shot scrolls, over one uniform notion of a spell.
        .target(
            name: "GnustoSpellcasting",
            dependencies: ["Gnusto"],
            plugins: devPlugins
        ),
        // A time-of-day clock and deterministic NPC timetables: the temporal
        // layer a mystery needs, where `roams` gives a stochastic wanderer.
        .target(
            name: "GnustoClock",
            dependencies: ["Gnusto"],
            plugins: devPlugins
        ),
        // ASK/TELL/SHOW over per-actor topic tables, gated on and feeding a
        // saved set of facts the player has worked out.
        .target(
            name: "GnustoConversation",
            dependencies: ["Gnusto"],
            plugins: devPlugins
        ),
        .executableTarget(
            name: "CloakOfDarkness",
            dependencies: ["Gnusto", "GnustoScoring"],
            plugins: devPlugins
        ),
        // The feature-tour example: a mid-size game that demonstrates the
        // idioms an author reaches for early — containers/surfaces, locked
        // doors, fuses and daemons, a roaming actor, `@Global` state, a
        // content bundle, and the scoring/actor plugins — in one buildable,
        // transcript-tested place. Sits between CloakOfDarkness and Zork1.
        .executableTarget(
            name: "Lighthouse",
            dependencies: ["Gnusto", "GnustoActors", "GnustoScoring"],
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
        // The scale test: a reconstruction of the original MIT mainframe Zork —
        // three times Zork1's size, and the first demo game whose prose is
        // *adapted* rather than reproduced. Built one milestone at a time; the
        // charter, the mechanics contract and the prose rule are in
        // `docs/games/dungeon.md`, and `FIDELITY.md`'s Dungeon section states
        // that prose rule before any region entry.
        .executableTarget(
            name: "Dungeon",
            dependencies: [
                "Gnusto", "GnustoActors", "GnustoDangerousDark", "GnustoScoring",
                "GnustoMeleeCombat",
            ],
            plugins: devPlugins
        ),
        // The spellcasting demo: a small original game that exercises all four
        // magic paradigms (cantrip, memorized, energy, scroll) via
        // GnustoSpellcasting — the "prove the engine hosts a spell system" game.
        .executableTarget(
            name: "Gramarye",
            dependencies: ["Gnusto", "GnustoScoring", "GnustoSpellcasting"],
            plugins: devPlugins
        ),
        // The mystery demo: a one-evening whodunit on a wall clock, where the
        // suspects keep a timetable and their movements are the evidence — the
        // "prove the engine hosts a clock-driven mystery" game. Design notes
        // and the story's mechanics contract live in `docs/games/fulminate.md`.
        .executableTarget(
            name: "Fulminate",
            dependencies: ["Gnusto", "GnustoClock", "GnustoConversation"],
            plugins: devPlugins
        ),
        // The survival demo: two failing clocks (thirst, fatigue) and a mule
        // who follows, is parked, and rejoins — issue #39's companion/survival
        // substrate, via GnustoActors and GnustoScoring.
        .executableTarget(
            name: "KindlyDeep",
            dependencies: ["Gnusto", "GnustoActors", "GnustoScoring"],
            plugins: devPlugins
        ),
        // Transcript-testing helpers for game authors. Link it into TEST
        // targets only: the Testing library it imports ships in the toolchain,
        // not the OS, so a plain executable linking it can fail at load time.
        .target(
            name: "GnustoTestSupport",
            dependencies: ["Gnusto"],
            swiftSettings: exitTests,
            plugins: devPlugins
        ),
        .testTarget(
            name: "GnustoMacrosTests",
            dependencies: [
                "GnustoMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "GnustoTests",
            dependencies: [
                "Gnusto", "GnustoDangerousDark", "GnustoScoring", "GnustoActors",
                "GnustoMeleeCombat", "GnustoSpellcasting", "GnustoClock", "GnustoConversation",
                "GnustoTestSupport",
                "CloakOfDarkness", "Lighthouse", "Zork1", "Dungeon", "Gramarye",
                "Fulminate", "KindlyDeep",
            ],
            swiftSettings: exitTests,
            plugins: devPlugins
        ),
    ]
)
