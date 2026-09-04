import Foundation
import Testing

struct GeneratedResolverTests {
    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private struct Fixture {
        let directory: URL
        let package: URL
        let engine: URL

        init(engineName: String = "arbitrary checkout") throws {
            let temporary = FileManager.default.temporaryDirectory
                .appendingPathComponent("gnusto-resolver-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
            // Foundation strips /private on Darwin; shell pwd -P keeps it.
            let resolved = try #require(realpath(temporary.path, nil))
            defer { free(resolved) }
            directory = URL(fileURLWithPath: String(cString: resolved))
            package = directory.appendingPathComponent("Gnusto")
            engine = directory.appendingPathComponent(engineName)
            try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
            try FileManager.default.copyItem(
                at: Self.template.appendingPathComponent("bin"),
                to: package.appendingPathComponent("bin"))
            try write("", at: package.appendingPathComponent("Package.swift"))
            try write("", at: engine.appendingPathComponent("Sources/Gnusto/marker"))
            try write("", at: engine.appendingPathComponent("bin/lib/playtest-focus.js"))
            try write(
                "#!/bin/bash\nexit 0\n", at: engine.appendingPathComponent("bin/gnusto-mcp"),
                executable: true)
            try write(
                #"#!/bin/bash"# + "\n"
                    + #"printf '%s\n' "$PWD" "$GNUSTO_PACKAGE_PATH" "${GNUSTO_INVOCATION_DIR:-missing}" "$@""#
                    + "\n",
                at: engine.appendingPathComponent("bin/playtest-measure"), executable: true)
        }

        private static var template: URL {
            GeneratedResolverTests.root.appendingPathComponent("bin/templates")
        }

        func write(_ text: String, at url: URL, executable: Bool = false) throws {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
            if executable {
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
            }
        }

        func clean() { try? FileManager.default.removeItem(at: directory) }
    }

    private static func run(
        _ arguments: [String], cwd: URL, environment: [String: String] = [:]
    ) throws -> (status: Int32, output: String, error: String) {
        var env = ProcessInfo.processInfo.environment
        for key in ["GNUSTO_REPO", "GNUSTO_PACKAGE_PATH", "GNUSTO_INVOCATION_DIR"] {
            env.removeValue(forKey: key)
        }
        let result = try ToolProcess.run(
            URL(fileURLWithPath: "/bin/bash"), arguments, from: cwd,
            environment: env.merging(environment) { _, new in new })
        return (result.status, result.stdout, result.stderr)
    }

    @Test(arguments: ["pipe|amp&", #"quote"slash\(literal)"#, "tab\tand\nnewline"])
    func generatedDependencyRoundTripsSpecialCharacters(_ name: String) throws {
        let fixture = try Fixture(engineName: name)
        defer { fixture.clean() }
        let generated = fixture.directory.appendingPathComponent("Generated")
        let result = try Self.run(
            [
                Self.root.appendingPathComponent("bin/new-game").path, "Generated", generated.path,
                "--dep-path", fixture.engine.path,
            ],
            cwd: fixture.directory)
        #expect(result.status == 0, "\(result.error)")
        guard result.status == 0 else { return }
        let manifest = try String(
            contentsOf: generated.appendingPathComponent("Package.swift"), encoding: .utf8)
        let literal = fixture.engine.path.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\t", with: "\\t")
            .replacingOccurrences(of: "\n", with: "\\n")
        #expect(manifest.contains("path: \"\(literal)\""))
        let dispatched = try Self.run(
            [generated.appendingPathComponent("bin/playtest-measure").path, "probe"],
            cwd: fixture.directory)
        #expect(dispatched.status == 0, "\(dispatched.error)")
        #expect(
            dispatched.output
                == "\(generated.path)\n\(generated.path)\n\(fixture.directory.path)\nprobe\n")
    }

    @Test func relativeOverrideAndCallerDirectorySurviveDispatch() throws {
        let fixture = try Fixture()
        defer { fixture.clean() }
        try fixture.write(
            "#!/bin/bash\n"
                + #"printf '%s\n' "$PWD" "$GNUSTO_PACKAGE_PATH" "$GNUSTO_INVOCATION_DIR" "$GNUSTO_REPO" "$@""# + "\n",
            at: fixture.engine.appendingPathComponent("bin/playtest-measure"), executable: true)
        let caller = fixture.package.appendingPathComponent("nested")
        try FileManager.default.createDirectory(at: caller, withIntermediateDirectories: true)
        let result = try Self.run(
            [
                fixture.package.appendingPathComponent("bin/playtest-measure").path, "../probe with spaces",
            ], cwd: caller,
            environment: ["GNUSTO_REPO": "../../arbitrary checkout"])
        #expect(result.status == 0, "\(result.error)")
        #expect(
            result.output
                == "\(fixture.package.path)\n\(fixture.package.path)\n\(caller.path)\n\(fixture.engine.path)\n../probe with spaces\n"
        )
    }

    @Test func relativeManifestDependencyResolvesFromThePackage() throws {
        let fixture = try Fixture()
        defer { fixture.clean() }
        try fixture.write(
            #".package(name: "Gnusto", path: "../arbitrary checkout")"#,
            at: fixture.package.appendingPathComponent("Package.swift"))
        let result = try Self.run(
            [fixture.package.appendingPathComponent("bin/playtest-measure").path],
            cwd: fixture.directory)
        #expect(result.status == 0, "\(result.error)")
        #expect(result.output.hasPrefix(fixture.package.path + "\n"))
    }

    @Test func explicitOverrideRejectsAGameNamedGnusto() throws {
        let fixture = try Fixture()
        defer { fixture.clean() }
        try fixture.write("", at: fixture.package.appendingPathComponent("Sources/Gnusto/game.swift"))
        let result = try Self.run(
            [fixture.package.appendingPathComponent("bin/playtest-measure").path],
            cwd: fixture.directory, environment: ["GNUSTO_REPO": fixture.package.path])
        #expect(result.status == 2)
        #expect(result.error.contains("is not a Gnusto checkout"))
        #expect(result.output.isEmpty)
    }

    @Test func checkoutDiscoverySkipsAGameNamedGnusto() throws {
        let fixture = try Fixture()
        defer { fixture.clean() }
        let checkouts = fixture.package.appendingPathComponent(".build/checkouts")
        try FileManager.default.createDirectory(at: checkouts, withIntermediateDirectories: true)
        let impostor = checkouts.appendingPathComponent("a-game")
        try fixture.write("", at: impostor.appendingPathComponent("Sources/Gnusto/game.swift"))
        try fixture.write(
            "#!/bin/bash\nexit 0\n", at: impostor.appendingPathComponent("bin/gnusto-mcp"),
            executable: true)
        try FileManager.default.createSymbolicLink(
            at: checkouts.appendingPathComponent("z-engine"), withDestinationURL: fixture.engine)
        let result = try Self.run(
            [fixture.package.appendingPathComponent("bin/playtest-measure").path], cwd: fixture.directory)
        #expect(result.status == 0, "\(result.error)")
        #expect(result.output.hasPrefix(fixture.package.path + "\n"))
    }

    @Test(arguments: [false, true])
    func samePhysicalPackageIsRefused(_ symlink: Bool) throws {
        let fixture = try Fixture()
        defer { fixture.clean() }
        try fixture.write("", at: fixture.package.appendingPathComponent("Sources/Gnusto/game.swift"))
        try fixture.write("", at: fixture.package.appendingPathComponent("bin/lib/playtest-focus.js"))
        let alias = fixture.directory.appendingPathComponent("alias")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: fixture.package)
        // Source the resolver directly so a broken guard cannot recurse forever.
        let script = #"source "$1"; gnusto_exec probe"#
        try fixture.write(
            "#!/bin/bash\necho dispatched-to-self\n",
            at: fixture.package.appendingPathComponent("bin/probe"), executable: true)
        let result = try Self.run(
            [
                "-c", script, fixture.package.appendingPathComponent("bin/probe").path,
                fixture.package.appendingPathComponent("bin/lib/gnusto-tooling.sh").path,
            ], cwd: fixture.directory,
            environment: ["GNUSTO_REPO": (symlink ? alias : fixture.package).path])
        #expect(result.status == 2)
        #expect(result.error.contains("same package"))
        #expect(result.output.isEmpty)
    }

    @Test func toolResolvingBackToTheInvokingScriptIsRefused() throws {
        let fixture = try Fixture()
        defer { fixture.clean() }
        let shim = fixture.package.appendingPathComponent("bin/probe")
        try fixture.write("#!/bin/bash\necho dispatched-to-self\n", at: shim, executable: true)
        try FileManager.default.createSymbolicLink(
            at: fixture.engine.appendingPathComponent("bin/probe"), withDestinationURL: shim)
        let result = try Self.run(
            [
                "-c", #"source "$1"; gnusto_exec probe"#, shim.path,
                fixture.package.appendingPathComponent("bin/lib/gnusto-tooling.sh").path,
            ], cwd: fixture.directory,
            environment: ["GNUSTO_REPO": fixture.engine.path])
        #expect(result.status == 2)
        #expect(result.error.contains("invoking shim"))
        #expect(result.output.isEmpty)
    }

    @Test func missingEngineToolHasAnActionableError() throws {
        let fixture = try Fixture()
        defer { fixture.clean() }
        let result = try Self.run(
            [fixture.package.appendingPathComponent("bin/export-game").path], cwd: fixture.directory,
            environment: ["GNUSTO_REPO": fixture.engine.path])
        #expect(result.status == 2)
        #expect(result.error.contains("bin/export-game is missing or not executable"))
    }
}
