import Foundation
import Testing

/// `bin/new-game`, exercised by running it.
///
/// One of the two suites in the package that shell out; ``PlaytestPathTests`` is
/// the other. It earns that: the generator's whole job is to leave a directory
/// in a particular state, and the
/// nearest thing to a unit test — reimplementing the substitution in Swift and
/// asserting the two agree — would assert that a copy of the code matches the
/// code. Running it costs a file copy and a `sed`, so the suite stays sub-second;
/// nothing here builds a package, which is CI's job.
struct NewGameTests {
    /// The package root, found relative to this file rather than to the working
    /// directory, which a test process does not control.
    private static let packageRoot =
        URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // GnustoTests
        .deletingLastPathComponent()  // Tests
        .deletingLastPathComponent()  // the package

    /// Run a command, returning its exit status and both streams. Never throws on a
    /// non-zero exit — a refusal is a result this suite asserts against, not an error.
    private static func run(
        _ tool: URL,
        _ arguments: [String],
        currentDirectory: URL = packageRoot,
        environment: [String: String]? = nil
    ) throws -> (status: Int32, stdout: String, stderr: String) {
        try ToolProcess.run(
            tool, arguments, from: currentDirectory,
            environment: ProcessInfo.processInfo.environment.merging(environment ?? [:]) { _, new in new })
    }

    /// Run `bin/new-game` with the given arguments.
    @discardableResult
    private static func newGame(
        _ arguments: [String],
        currentDirectory: URL = packageRoot
    ) throws -> (
        status: Int32, stdout: String, stderr: String
    ) {
        try run(
            packageRoot.appendingPathComponent("bin/new-game"), arguments,
            currentDirectory: currentDirectory)
    }

    /// A fresh empty directory that does not exist yet, so the generator is the
    /// thing that creates it.
    private static func scratch() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("Zwank")
    }

    private static func generate(_ extra: [String] = []) throws -> URL {
        let destination = scratch()
        let result = try newGame(["Zwank", destination.path] + extra)
        #expect(result.status == 0, "bin/new-game failed: \(result.stderr)")
        return destination
    }

    /// Every path under a directory, relative to it, files and directories alike.
    ///
    /// Every failure mode of `FileManager`'s enumerator -- a nil enumerator because
    /// the root does not exist, an `allObjects` cast that fails, a root that is
    /// really there but empty -- collapses to the same `[]` a truly clean generated
    /// tree would produce. Nothing downstream can tell those apart from the return
    /// value alone, which is why a caller that means to prove the tree is clean
    /// has to assert the enumeration found *something* before trusting an empty
    /// loop as good news, rather than reading silence as success.
    private static func entries(under root: URL) -> [String] {
        let enumerator = FileManager.default.enumerator(atPath: root.path)
        return (enumerator?.allObjects as? [String] ?? []).sorted()
    }

    /// One JSON file, parsed. Throws rather than returning an empty dictionary,
    /// because a malformed file and a file that says nothing are the same `[:]` and
    /// only one of them is a passing test.
    private static func json(at url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }

    @Test func generatedPackageKeepsNoTraceOfTheTemplateName() throws {
        let game = try Self.generate()
        defer { try? FileManager.default.removeItem(at: game) }

        let entries = Self.entries(under: game)
        #expect(
            !entries.isEmpty,
            "found nothing under \(game.path) -- that means the enumerator or the root is wrong, not that the generated tree is clean"
        )

        // Which files this loop actually opened and read as text, so the absence
        // of "MyGame" below is evidence about files that were checked rather than
        // an artifact of the UTF-8 guard silently skipping past them.
        var filesRead: Set<String> = []
        for entry in entries {
            #expect(!entry.contains("MyGame"), "\(entry) still carries the template name")
            let url = game.appendingPathComponent(entry)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                !isDirectory.boolValue,
                let text = try? String(contentsOf: url, encoding: .utf8)
            else { continue }
            filesRead.insert(entry)
            #expect(!text.contains("MyGame"), "\(entry) still mentions MyGame")
            #expect(!text.contains("mygame"), "\(entry) still mentions mygame")
        }

        #expect(!filesRead.isEmpty, "no file under \(game.path) was read as text")
        let namedFiles = [
            "Package.swift", ".mcp.json", ".claude/settings.json", "README.md",
            "Sources/Zwank/Zwank.swift", "Tests/ZwankTests/ZwankTests.swift",
        ]
        for file in namedFiles {
            #expect(
                filesRead.contains(file),
                "\(file) was never opened, so its clean bill of health proves nothing")
        }
    }

    @Test func generatedPackageIsNamedForTheGame() throws {
        let game = try Self.generate()
        defer { try? FileManager.default.removeItem(at: game) }

        let manifest = try String(
            contentsOf: game.appendingPathComponent("Package.swift"), encoding: .utf8)
        #expect(manifest.contains(#"name: "Zwank""#))
        #expect(manifest.contains(#".executableTarget("#))
        #expect(manifest.contains(#"name: "ZwankTests""#))

        let paths = Self.entries(under: game)
        #expect(paths.contains("Sources/Zwank/Zwank.swift"))
        #expect(paths.contains("Sources/Zwank/Entry.swift"))
        #expect(paths.contains("Tests/ZwankTests/ZwankTests.swift"))
    }

    @Test func mcpEntryIsKeyedLowercaseAndArgumentIsTheProduct() throws {
        let game = try Self.generate()
        defer { try? FileManager.default.removeItem(at: game) }

        let json = try String(
            contentsOf: game.appendingPathComponent(".mcp.json"), encoding: .utf8)
        #expect(json.contains(#""zwank""#))
        #expect(json.contains(#"["Zwank"]"#))
    }

    /// The pair `bin/playtest-preflight`'s `mcp key` row checks, asserted here so a
    /// generated package cannot fail preflight on the day it is written.
    ///
    /// Two files have to agree on one word and neither knows about the other:
    /// `.mcp.json` registers the server and `.claude/settings.json` enables it. A
    /// package registering a server it never enables looks completely fine until a
    /// round dispatches, at which point every tester's `ToolSearch` returns nothing
    /// and each of them reports, accurately and uselessly, that it cannot use MCP.
    @Test func theMcpKeyAndTheEnabledServerAreTheSameWord() throws {
        let game = try Self.generate()
        defer { try? FileManager.default.removeItem(at: game) }

        let mcp = try Self.json(at: game.appendingPathComponent(".mcp.json"))
        let servers = mcp["mcpServers"] as? [String: Any] ?? [:]
        #expect(servers.count == 1, "expected exactly one registered server, got \(servers.keys)")

        let settings = try Self.json(at: game.appendingPathComponent(".claude/settings.json"))
        let enabled = settings["enabledMcpjsonServers"] as? [String] ?? []
        #expect(enabled == ["zwank"])
        #expect(Array(servers.keys) == enabled, "\(servers.keys) is not \(enabled)")

        // Both are load-bearing on the headless path, and both are read out of THIS
        // file rather than repeated in the script: `bin/playtest-preflight` spreads
        // the package's own `env` into `claude -p`, so a package missing them runs a
        // round that dies at 600 seconds at whatever phase it had reached, silently.
        let env = settings["env"] as? [String: String] ?? [:]
        #expect(env["MCP_TIMEOUT"] == "180000")
        #expect(env["CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS"] == "0")

        // Every shim a round actually runs. `playtest-routes` is the one the Distill
        // phase needs, and an un-allowlisted tool there stalls the whole round on a
        // permission prompt rather than failing.
        let allow = (settings["permissions"] as? [String: Any])?["allow"] as? [String] ?? []
        for tool in ["playtest-preflight", "playtest-replay", "playtest-routes"] {
            #expect(
                allow.contains("Bash(bin/\(tool):*)"),
                "bin/\(tool) is not allowlisted, so a round stalls on a permission prompt")
        }
        #expect(allow.contains("mcp__zwank"))
        #expect(allow.contains("Workflow"))
        #expect(allow.contains("Bash(gh issue list:*)"))
        #expect(!allow.contains("Bash(gh issue create:*)"))
        let ask = (settings["permissions"] as? [String: Any])?["ask"] as? [String] ?? []
        #expect(ask.contains("Bash(gh issue create:*)"))
    }

    @Test func generatedPlaytestEntryPointsUseTheResolvedWorkflow() throws {
        let game = try Self.generate()
        defer { try? FileManager.default.removeItem(at: game) }

        let skill = try String(
            contentsOf: game.appendingPathComponent(".claude/skills/playtest/SKILL.md"), encoding: .utf8)
        #expect(skill.contains("bin/playtest-preflight Zwank"))
        #expect(skill.contains(".context/playtest-round-args.json"))
        #expect(skill.contains("args.workflowPath"))
        #expect(!skill.contains("scriptPath: \".claude/workflows/playtest.js\""))
        #expect(FileManager.default.fileExists(atPath: game.appendingPathComponent("docs/playtesting.md").path))
    }

    @Test func toolsAreShimsAndTheLibraryIsNotExecutable() throws {
        let game = try Self.generate()
        defer { try? FileManager.default.removeItem(at: game) }

        for tool in [
            "export-game", "gnusto-mcp", "playtest-replay", "playtest-measure",
            "playtest-preflight", "playtest-routes",
        ] {
            let path = game.appendingPathComponent("bin/\(tool)").path
            #expect(
                FileManager.default.isExecutableFile(atPath: path),
                "bin/\(tool) is missing or not executable")

            // The executable bit alone would pass four empty executable files.
            // A whole-branch review found that no test or CI step short of
            // actually running a shim proved it dispatches anywhere at all — so
            // assert the body sources the library and ends by handing off to the
            // ONE tool named for it. Naming the tool per file, rather than just
            // checking for *some* `gnusto_exec` call, is what catches a
            // copy-paste mistake where two shims dispatch to the same tool.
            let body = try String(contentsOfFile: path, encoding: .utf8)
            #expect(
                body.contains(#". "$(dirname "$0")/lib/gnusto-tooling.sh""#),
                "bin/\(tool) does not source gnusto-tooling.sh")
            let lines = body.split(separator: "\n", omittingEmptySubsequences: true)
            #expect(
                lines.last == Substring(#"gnusto_exec \#(tool) "$@""#),
                "bin/\(tool) does not end by dispatching gnusto_exec \(tool), got: \(lines.last ?? "")")
        }
        let library = game.appendingPathComponent("bin/lib/gnusto-tooling.sh").path
        #expect(FileManager.default.fileExists(atPath: library))
        #expect(
            !FileManager.default.isExecutableFile(atPath: library),
            "the library is sourced, not run, so it should carry no executable bit")
    }

    @Test func dependencyIsAPinnedURLByDefault() throws {
        let game = try Self.generate()
        defer { try? FileManager.default.removeItem(at: game) }

        let manifest = try String(
            contentsOf: game.appendingPathComponent("Package.swift"), encoding: .utf8)
        #expect(manifest.contains(#"url: "https://github.com/HeirloomLogic/Gnusto""#))
        #expect(manifest.contains("from: \""))
        #expect(!manifest.contains("path: \"../..\""))
    }

    /// The default pin may forward a trait only if the release it pins declares one.
    ///
    /// SwiftPM validates trait forwarding at resolution, not at compile time, and
    /// refuses a dependency that enables a trait the dependency never declared:
    /// *"Package 'zwank' (Zwank) enables traits [Playtest] on package 'gnusto'
    /// (Gnusto) that declares no traits."* Every release up to and including 0.5.0
    /// declares none, so the generated package would not resolve at all — and a
    /// suite that only string-matches the manifest is exactly what let that
    /// through, since the emitted line looks perfectly correct on its own.
    ///
    /// So this asks the pinned tag rather than a constant: read the version out of
    /// the line the generator wrote, read that tag's own manifest out of git, and
    /// require the two to agree. It costs a `git show` rather than a resolve, which
    /// keeps this suite's no-`swift` rule, and it retires itself — the day a tag
    /// declaring the trait ships, the same assertion starts demanding the
    /// forwarding instead of forbidding it.
    @Test func theDefaultPinForwardsTheTraitOnlyIfTheReleaseDeclaresIt() throws {
        guard let git = Self.which("git") else { return }  // no git, no check

        let destination = Self.scratch()
        defer { try? FileManager.default.removeItem(at: destination) }
        let generated = try Self.newGame(["Zwank", destination.path])
        #expect(generated.status == 0, "bin/new-game failed: \(generated.stderr)")

        let manifest = try String(
            contentsOf: destination.appendingPathComponent("Package.swift"), encoding: .utf8)
        let dependency = try #require(
            manifest.split(separator: "\n").first { $0.contains("HeirloomLogic/Gnusto") },
            "the generated manifest carries no pinned Gnusto dependency")

        let version = try #require(
            dependency.range(of: #"from: ""#).map { start in
                String(dependency[start.upperBound...].prefix { $0 != "\"" })
            },
            "no `from:` version in \(dependency)")

        let released = try Self.run(git, ["show", "\(version):Package.swift"])
        #expect(released.status == 0, "could not read the pinned tag's manifest: \(released.stderr)")
        // Whitespace-stripped, because the declaration is one line in the template
        // and four in the engine's own manifest, and only one of those spellings
        // would survive a literal grep.
        let declares = released.stdout
            .filter { !$0.isWhitespace }
            .contains(#".trait(name:"Playtest""#)

        #expect(
            dependency.contains("traits: gnusto") == declares,
            declares
                ? "Gnusto \(version) declares the Playtest trait, so the generated package should forward it: \(dependency)"
                : "Gnusto \(version) declares no Playtest trait, so forwarding one makes the generated package unresolvable: \(dependency)"
        )

        // A pin that cannot carry the forwarding is a pin whose `--disable-default-traits`
        // does not reach the engine, and the author has to be told so at the one
        // moment they are looking at this output.
        #expect(
            generated.stdout.contains("predates the Playtest trait") == !declares,
            "the traitless-pin warning does not match what was emitted: \(generated.stdout)")
    }

    @Test func depPathOverridesTheURL() throws {
        let game = try Self.generate(["--dep-path", Self.packageRoot.path])
        defer { try? FileManager.default.removeItem(at: game) }

        let manifest = try String(
            contentsOf: game.appendingPathComponent("Package.swift"), encoding: .utf8)
        #expect(manifest.contains(#"name: "Gnusto", path: ""#))
        #expect(manifest.contains(Self.packageRoot.path))
        #expect(!manifest.contains("url: \"https://github.com"))
    }

    @Test func aNonEmptyDestinationIsRefused() throws {
        let destination = Self.scratch()
        try FileManager.default.createDirectory(
            at: destination, withIntermediateDirectories: true)
        try "occupied".write(
            to: destination.appendingPathComponent("something"), atomically: true,
            encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: destination) }

        let result = try Self.newGame(["Zwank", destination.path])
        #expect(result.status == 2)
        #expect(result.stderr.contains("not empty"))
    }

    @Test func aRelativeDestinationResolvesAgainstTheCallersDirectory() throws {
        // bin/new-game cd's to the repo root before it even parses its arguments,
        // so a relative destination re-resolved after that cd lands inside the
        // repo instead of wherever the caller actually stood. Verified by hand
        // from /tmp/relcheck: `…/bin/new-game Relgame ./Relgame` wrote the
        // package inside this checkout, not /tmp/relcheck/Relgame (whole-branch
        // review, #368 follow-up).
        let cwd = FileManager.default.temporaryDirectory
            .appendingPathComponent("new-game-relcheck-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: cwd, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: cwd) }
        defer {
            try? FileManager.default.removeItem(
                at: Self.packageRoot.appendingPathComponent("Zwank"))
        }

        let result = try Self.newGame(["Zwank", "./Zwank"], currentDirectory: cwd)
        #expect(result.status == 0, "bin/new-game failed: \(result.stderr)")

        let landedWhereCalled = cwd.appendingPathComponent("Zwank/Package.swift")
        #expect(
            FileManager.default.fileExists(atPath: landedWhereCalled.path),
            "expected \(landedWhereCalled.path) to exist")

        let landedInTheRepo = Self.packageRoot.appendingPathComponent("Zwank/Package.swift")
        #expect(
            !FileManager.default.fileExists(atPath: landedInTheRepo.path),
            "a relative destination wrote the package inside the Gnusto checkout instead of the caller's directory")
    }

    @Test func aRelativeDepPathResolvesAgainstTheCallersDirectory() throws {
        // Same bug, same fix, for the other path this script reads off the
        // command line: a relative --dep-path is parsed after the same cd, so it
        // needs the same resolution. `cwd` here is a subdirectory of the repo one
        // level down, so "--dep-path .." unambiguously means the repo root if
        // resolved against the caller and something else entirely (or nothing)
        // if resolved against wherever the script happened to cd to first.
        let cwd = Self.packageRoot.appendingPathComponent(
            ".new-game-relcheck-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: cwd, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: cwd) }

        let destination = cwd.appendingPathComponent("Zwank")
        let result = try Self.newGame(
            ["Zwank", "./Zwank", "--dep-path", ".."], currentDirectory: cwd)
        #expect(result.status == 0, "bin/new-game failed: \(result.stderr)")

        let manifest = try String(
            contentsOf: destination.appendingPathComponent("Package.swift"), encoding: .utf8)
        #expect(manifest.contains(#"name: "Gnusto", path: ""#))
        #expect(manifest.contains(Self.packageRoot.path))
    }

    @Test func anInvalidGameNameIsRefused() throws {
        let result = try Self.newGame(["my game", Self.scratch().path])
        #expect(result.status == 2)
        #expect(result.stderr.contains("Swift identifier"))
    }

    @Test func missingArgumentsPrintUsage() throws {
        let result = try Self.newGame([])
        #expect(result.status == 2)
        #expect(result.stderr.contains("usage"))
    }

    /// The one line the whole shim mechanism rests on.
    ///
    /// `bin/lib/playtest-focus.js` answers with the package under test, which is not
    /// the checkout it lives in: `bin/lib/gnusto-tooling.sh` exports
    /// `GNUSTO_PACKAGE_PATH` and then execs the ENGINE's copy of
    /// `bin/playtest-preflight`, so a `__dirname`-derived root would have both
    /// front-door scripts chdir into the engine and check a package the author does
    /// not have. Get it wrong and `routeManifests` returns `[]` — indistinguishable
    /// from a game that has cut no routes yet, so the round dispatches and plays
    /// cold with nothing anywhere saying why.
    ///
    /// A node one-liner, because it pins that line in well under a second with no
    /// toolchain. Everything heavier belongs to CI, which runs a real preflight
    /// inside a real generated package; ``PlaytestPathTests`` records why this suite
    /// refuses to run `swift`.
    @Test func theFocusModuleRootsAtThePackageAndNotAtTheEngine() throws {
        guard let node = Self.which("node") else { return }  // no node, no check

        // The module path travels as an argument rather than interpolated into the
        // script, so a directory with a quote in its name cannot rewrite the
        // one-liner around it. `node -e` puts trailing operands at `process.argv[1]`.
        let module = Self.packageRoot.appendingPathComponent("bin/lib/playtest-focus").path
        let script = "console.log(require(process.argv[1]).ROOT)"

        let here = try Self.run(node, ["-e", script, module])
        #expect(
            here.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == Self.packageRoot.path,
            "with no GNUSTO_PACKAGE_PATH the root should be this checkout: \(here)")

        let elsewhere = FileManager.default.temporaryDirectory
            .appendingPathComponent("focus-root-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: elsewhere, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: elsewhere) }

        let there = try Self.run(
            node, ["-e", script, module],
            environment: ["GNUSTO_PACKAGE_PATH": elsewhere.path])
        #expect(
            there.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                == elsewhere.resolvingSymlinksInPath().path,
            "GNUSTO_PACKAGE_PATH does not move the root, so a shimmed tool would check the engine: \(there)")
    }

    /// The first `node` on PATH, or nil. Skipping rather than failing: `node` is not
    /// a build dependency of this package and CI's Swift container ships none, which
    /// is why the check that needs it lives in a job of its own.
    private static func which(_ tool: String) -> URL? {
        let paths = (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":")
        for directory in paths {
            let candidate = "\(directory)/\(tool)"
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return URL(fileURLWithPath: candidate)
            }
        }
        return nil
    }
}
