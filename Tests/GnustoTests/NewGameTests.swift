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

    /// Run `bin/new-game` with the given arguments, returning its exit status and
    /// the two streams. Never throws on a non-zero exit — a refusal is a result
    /// this suite asserts against, not an error.
    @discardableResult
    private static func newGame(
        _ arguments: [String],
        currentDirectory: URL = packageRoot
    ) throws -> (
        status: Int32, stdout: String, stderr: String
    ) {
        let process = Process()
        process.executableURL = packageRoot.appendingPathComponent("bin/new-game")
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectory
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try process.run()
        let outData = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (
            process.terminationStatus,
            String(decoding: outData, as: UTF8.self),
            String(decoding: errData, as: UTF8.self)
        )
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
            "Package.swift", ".mcp.json", "README.md", "Sources/Zwank/Zwank.swift",
            "Tests/ZwankTests/ZwankTests.swift",
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

    @Test func toolsAreShimsAndTheLibraryIsNotExecutable() throws {
        let game = try Self.generate()
        defer { try? FileManager.default.removeItem(at: game) }

        for tool in ["export-game", "gnusto-mcp", "playtest-replay", "playtest-measure"] {
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
}
