import Foundation
import Testing

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Launch the real MCP wrapper and shared fingerprint builder with fake Swift. A
/// nested SwiftPM invocation would contend with the test runner's build lock.
struct MCPBuildGateTests {
    private struct Fixture {
        let root: URL
        let game: URL
        let engine: URL
        let terminal: URL

        var cache: URL { game.appendingPathComponent(".context/playtest/.bin/Zwank.path") }
        var binary: URL { generated.appendingPathComponent("scratch/products/GnustoGeneratedLauncher") }
        var generated: URL { game.appendingPathComponent(".build-launchers/Zwank/development") }
        var calls: URL { root.appendingPathComponent("swift-calls") }

        init(layout: String = "local") throws {
            // Foundation preserves /var for this temporary URL on macOS; the
            // builder uses realpath, so literal call expectations must do too.
            guard let canonical = realpath(FileManager.default.temporaryDirectory.path, nil) else {
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
            let temporaryRoot = String(cString: canonical)
            free(canonical)
            root = URL(fileURLWithPath: temporaryRoot).appendingPathComponent(UUID().uuidString)
            game = root.appendingPathComponent("game package")
            terminal = root.appendingPathComponent("terminal checkout")
            switch layout {
            case "checkout": engine = game.appendingPathComponent(".build/checkouts/gnusto")
            case "direct": engine = game
            default: engine = root.appendingPathComponent("engine checkout")
            }

            let repository = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            for package in Set([game, engine, terminal]) {
                try write("// source\n", to: package.appendingPathComponent("Sources/Example/Game.swift"))
                try write(
                    "// manifest\n.trait(name: \"Playtest\")\n", to: package.appendingPathComponent("Package.swift"))
                try write("{}\n", to: package.appendingPathComponent("Package.resolved"))
            }
            if game != engine {
                try write(
                    "// manifest\n.trait(name: \"Playtest\")\n.package(name: \"Gnusto\", path: \"\(engine.path)\")\n",
                    to: game.appendingPathComponent("Package.swift"))
            }
            try write(
                #"{"version":1,"package":"Zwank","games":[{"name":"Zwank","product":"StoryLibrary","module":"StoryModule","symbol":"game"}]}"#,
                to: game.appendingPathComponent("gnusto-games.json"))
            for tool in ["bin/gnusto-mcp", "bin/build-game", "bin/lib/game-build.mjs", "bin/lib/game-catalog.mjs"] {
                try write(
                    String(contentsOf: repository.appendingPathComponent(tool), encoding: .utf8),
                    to: engine.appendingPathComponent(tool), executable: !tool.hasSuffix(".mjs"))
            }
            try write(
                #"""
                #!/bin/sh
                printf '{"method":"ready","mode":"%s"}\n' "$1"
                """#,
                to: root.appendingPathComponent("launcher-template"), executable: true)
            try write(
                #"""
                #!/bin/sh
                printf '%s\n' "$*" >> "$FAKE_CALLS"
                if [ "$1" = --version ]; then echo 'Fake Swift 6.4'; exit 0; fi
                [ "$1" = build ] || exit 91
                shift
                show=0
                product=''
                while [ "$#" -gt 0 ]; do
                  case "$1" in
                    --package-path) package="$2"; shift 2 ;;
                    --scratch-path) scratch="$2"; shift 2 ;;
                    --configuration) [ "$2" = debug ] || exit 92; shift 2 ;;
                    --product) product="$2"; shift 2 ;;
                    --show-bin-path) show=1; shift ;;
                    *) exit 93 ;;
                  esac
                done
                [ "$package" = "$GNUSTO_PACKAGE_PATH/.build-launchers/Zwank/development/package" ] || exit 94
                [ -d "$GNUSTO_ENGINE_PATH" ] || exit 95
                if [ "$show" = 1 ]; then
                  printf '%s/products\n' "$scratch"
                else
                  [ "$product" = GnustoGeneratedLauncher ] || exit 96
                  echo 'fixture build progress'
                  [ -z "${FAKE_BUILD_FAIL:-}" ] || exit 42
                  if [ -z "${FAKE_MISSING_PRODUCT:-}" ]; then
                    mkdir -p "$scratch/products"
                    cp "$FAKE_LAUNCHER" "$scratch/products/$product"
                  fi
                fi
                """#,
                to: root.appendingPathComponent("fake-bin/swift"), executable: true)
        }

        func write(_ text: String, to path: URL, executable: Bool = false) throws {
            try FileManager.default.createDirectory(
                at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
            // Other tests launch processes while fixtures are being written.
            // Do not let a child inherit a writable script descriptor: on Linux
            // that keeps exec from opening the script (ETXTBSY) after we close it.
            let descriptor = open(path.path, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, mode_t(0o600))
            guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
            let file = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
            defer { try? file.close() }
            try file.write(contentsOf: Data(text.utf8))
            if executable {
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path.path)
            }
        }

        func date(_ path: URL, seconds: TimeInterval) throws {
            try FileManager.default.setAttributes(
                [.modificationDate: Date(timeIntervalSince1970: seconds)], ofItemAtPath: path.path)
        }

        func warm() throws {
            let built = try run()
            guard built.status == 0 else {
                throw NSError(
                    domain: "MCPBuildGateTests", code: Int(built.status),
                    userInfo: [NSLocalizedDescriptionKey: built.stderr])
            }
            try write("", to: calls)
            try date(cache, seconds: 2000)
        }

        func edit(_ path: URL) throws {
            let previous = try String(contentsOf: path, encoding: .utf8)
            try write(previous + "\n// changed input\n", to: path)
        }

        var buildCalls: [String] {
            let arguments =
                "build --package-path \(generated.appendingPathComponent("package").path) --scratch-path \(generated.appendingPathComponent("scratch").path) --configuration debug"
            return ["--version", arguments + " --product GnustoGeneratedLauncher", arguments + " --show-bin-path"]
        }

        func run(_ environment: [String: String] = [:]) throws -> (status: Int32, stdout: String, stderr: String) {
            var variables = ProcessInfo.processInfo.environment
            variables.removeValue(forKey: "GNUSTO_MCP_BUILD")
            variables["GNUSTO_PACKAGE_PATH"] = game.path
            variables["FAKE_CALLS"] = calls.path
            variables["FAKE_LAUNCHER"] = root.appendingPathComponent("launcher-template").path
            variables["GNUSTO_REPO"] = engine.path
            variables["GNUSTO_TERMINAL_PATH"] = terminal.path
            variables["GNUSTO_SWIFT"] = root.appendingPathComponent("fake-bin/swift").path
            variables["GNUSTO_SWIFT_BUILD_FLAGS"] = "[]"
            variables["PATH"] =
                root.appendingPathComponent("fake-bin").path + ":" + (variables["PATH"] ?? "/usr/bin:/bin")
            variables.merge(environment) { _, value in value }
            return try ToolProcess.run(
                engine.appendingPathComponent("bin/gnusto-mcp"), ["Zwank"], from: root,
                environment: variables)
        }

        var swiftCalls: [String] {
            ((try? String(contentsOf: calls, encoding: .utf8)) ?? "")
                .split(separator: "\n").map(String.init)
        }

        func remove() { try? FileManager.default.removeItem(at: root) }
    }

    private static let protocolOutput = "{\"method\":\"ready\",\"mode\":\"--mcp\"}\n"

    @Test(arguments: ["local", "checkout", "direct"])
    func warmLaunchSkipsEverySwiftInvocation(layout: String) throws {
        let fixture = try Fixture(layout: layout)
        defer { fixture.remove() }
        try fixture.warm()
        let result = try fixture.run()
        #expect(result.status == 0, "\(result.stderr)")
        #expect(result.stdout == Self.protocolOutput)
        #expect(result.stderr.isEmpty)
        #expect(fixture.swiftCalls.isEmpty)
    }

    @Test func coldLaunchBuildsAndRecordsTheGamesBinary() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let result = try fixture.run()
        #expect(result.status == 0, "\(result.stderr)")
        #expect(result.stdout == Self.protocolOutput)
        #expect(result.stderr.contains("fixture build progress"))
        #expect(fixture.swiftCalls == fixture.buildCalls)
        #expect(try String(contentsOf: fixture.cache, encoding: .utf8) == fixture.binary.path + "\n")
        #expect(!FileManager.default.fileExists(atPath: fixture.engine.appendingPathComponent(".context").path))
        let warm = try fixture.run()
        #expect(warm.status == 0)
        #expect(fixture.swiftCalls == fixture.buildCalls)
    }

    @Test(arguments: ["local", "checkout"], ["Sources/Example/Game.swift", "Package.swift", "Package.resolved"])
    func engineEditsRebuildTheGame(layout: String, path: String) throws {
        let fixture = try Fixture(layout: layout)
        defer { fixture.remove() }
        try fixture.warm()
        try fixture.edit(fixture.engine.appendingPathComponent(path))
        let result = try fixture.run()
        #expect(result.status == 0, "\(result.stderr)")
        #expect(result.stdout == Self.protocolOutput)
        #expect(fixture.swiftCalls == fixture.buildCalls)
        let warm = try fixture.run()
        #expect(warm.status == 0)
        #expect(fixture.swiftCalls == fixture.buildCalls)
    }

    @Test(arguments: ["Sources/Example/Game.swift", "Package.swift", "Package.resolved"])
    func gameEditsStillRebuild(path: String) throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try fixture.warm()
        try fixture.edit(fixture.game.appendingPathComponent(path))
        let result = try fixture.run()
        #expect(result.status == 0, "\(result.stderr)")
        #expect(fixture.swiftCalls == fixture.buildCalls)
    }

    @Test(arguments: ["local", "checkout"])
    func removingAnEngineSourceRebuilds(layout: String) throws {
        let fixture = try Fixture(layout: layout)
        defer { fixture.remove() }
        try fixture.warm()
        try FileManager.default.removeItem(at: fixture.engine.appendingPathComponent("Sources/Example/Game.swift"))
        let result = try fixture.run()
        #expect(result.status == 0, "\(result.stderr)")
        #expect(fixture.swiftCalls == fixture.buildCalls)
    }

    @Test func forcingAWarmBuildStillBuilds() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try fixture.warm()
        let result = try fixture.run(["GNUSTO_MCP_BUILD": "1"])
        #expect(result.status == 0, "\(result.stderr)")
        #expect(result.stdout == Self.protocolOutput)
        #expect(fixture.swiftCalls == fixture.buildCalls)
    }

    @Test func missingCachedBinaryBuildsAgain() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try fixture.warm()
        try FileManager.default.removeItem(at: fixture.binary)
        let result = try fixture.run()
        #expect(result.status == 0, "\(result.stderr)")
        #expect(fixture.swiftCalls == fixture.buildCalls)
        #expect(try String(contentsOf: fixture.cache, encoding: .utf8) == fixture.binary.path + "\n")
    }

    @Test func failedBuildNeverServesTheOldBinaryOrAdvancesItsStamp() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try fixture.warm()
        let result = try fixture.run(["GNUSTO_MCP_BUILD": "1", "FAKE_BUILD_FAIL": "1"])
        #expect(result.status == 2)
        #expect(result.stdout.isEmpty)
        #expect(result.stderr.contains("could not build game Zwank"))
        #expect(fixture.swiftCalls == Array(fixture.buildCalls.prefix(2)))
        let attributes = try FileManager.default.attributesOfItem(atPath: fixture.cache.path)
        #expect(attributes[.modificationDate] as? Date == Date(timeIntervalSince1970: 2000))
    }

    @Test func missingBuiltProductDoesNotRecordASuccess() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let result = try fixture.run(["FAKE_MISSING_PRODUCT": "1"])
        #expect(result.status == 2)
        #expect(result.stdout.isEmpty)
        #expect(result.stderr.contains("ENOENT"))
        #expect(!FileManager.default.fileExists(atPath: fixture.cache.path))
    }
}
