import Foundation
import Testing

/// Launch the real MCP wrapper against a fake Swift command and product. A
/// nested SwiftPM invocation would contend with the test runner's build lock.
struct MCPBuildGateTests {
    private struct Fixture {
        let root: URL
        let game: URL
        let engine: URL

        var cache: URL { game.appendingPathComponent(".context/playtest/.bin/Zwank.path") }
        var binary: URL { game.appendingPathComponent("products/Zwank") }
        var calls: URL { root.appendingPathComponent("swift-calls") }

        init(layout: String = "local") throws {
            root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            game = root.appendingPathComponent("game package")
            switch layout {
            case "checkout": engine = game.appendingPathComponent(".build/checkouts/gnusto")
            case "direct": engine = game
            default: engine = root.appendingPathComponent("engine checkout")
            }

            let repository = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            for package in Set([game, engine]) {
                try write("// source\n", to: package.appendingPathComponent("Sources/Example/Game.swift"))
                try write("// manifest\n", to: package.appendingPathComponent("Package.swift"))
                try write("{}\n", to: package.appendingPathComponent("Package.resolved"))
            }
            try write(
                String(contentsOf: repository.appendingPathComponent("bin/gnusto-mcp"), encoding: .utf8),
                to: engine.appendingPathComponent("bin/gnusto-mcp"), executable: true)
            try write(
                #"""
                #!/bin/sh
                printf '{"method":"ready","mode":"%s"}\n' "$1"
                """#,
                to: binary, executable: true)
            try write(
                #"""
                #!/bin/sh
                printf '%s\n' "$*" >> "$FAKE_CALLS"
                [ "$1" = build ] || exit 91
                [ "$2" = --product ] && [ "$3" = Zwank ] || exit 92
                [ "$PWD" -ef "$GNUSTO_PACKAGE_PATH" ] || exit 93
                if [ "${4:-}" = --show-bin-path ]; then
                  printf '%s\n' "$GNUSTO_PACKAGE_PATH/products"
                else
                  echo 'fixture build progress'
                  [ -z "${FAKE_BUILD_FAIL:-}" ] || exit 42
                fi
                """#,
                to: root.appendingPathComponent("fake-bin/swift"), executable: true)

            // Known, separated timestamps keep these checks independent of the
            // machine's clock resolution and avoid sleeping between launches.
            for package in Set([game, engine]) {
                for path in [
                    "Sources", "Sources/Example", "Sources/Example/Game.swift", "Package.swift", "Package.resolved",
                ] {
                    try date(package.appendingPathComponent(path), seconds: 1000)
                }
            }
        }

        func write(_ text: String, to path: URL, executable: Bool = false) throws {
            try FileManager.default.createDirectory(
                at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: path, atomically: true, encoding: .utf8)
            if executable {
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path.path)
            }
        }

        func date(_ path: URL, seconds: TimeInterval) throws {
            try FileManager.default.setAttributes(
                [.modificationDate: Date(timeIntervalSince1970: seconds)], ofItemAtPath: path.path)
        }

        func warm() throws {
            try write(binary.path + "\n", to: cache)
            try date(cache, seconds: 2000)
        }

        func run(_ environment: [String: String] = [:]) throws -> (status: Int32, stdout: String, stderr: String) {
            var variables = ProcessInfo.processInfo.environment
            variables.removeValue(forKey: "GNUSTO_MCP_BUILD")
            variables["GNUSTO_PACKAGE_PATH"] = game.path
            variables["FAKE_CALLS"] = calls.path
            variables["PATH"] = root.appendingPathComponent("fake-bin").path + ":/usr/bin:/bin"
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
    private static let buildCalls = ["build --product Zwank", "build --product Zwank --show-bin-path"]

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
        #expect(fixture.swiftCalls == Self.buildCalls)
        #expect(try String(contentsOf: fixture.cache, encoding: .utf8) == fixture.binary.path + "\n")
        #expect(!FileManager.default.fileExists(atPath: fixture.engine.appendingPathComponent(".context").path))
        let warm = try fixture.run()
        #expect(warm.status == 0)
        #expect(fixture.swiftCalls == Self.buildCalls)
    }

    @Test(arguments: ["local", "checkout"], ["Sources/Example/Game.swift", "Package.swift", "Package.resolved"])
    func engineEditsRebuildTheGame(layout: String, path: String) throws {
        let fixture = try Fixture(layout: layout)
        defer { fixture.remove() }
        try fixture.warm()
        try fixture.date(fixture.engine.appendingPathComponent(path), seconds: 3000)
        let result = try fixture.run()
        #expect(result.status == 0, "\(result.stderr)")
        #expect(result.stdout == Self.protocolOutput)
        #expect(fixture.swiftCalls == Self.buildCalls)
        let warm = try fixture.run()
        #expect(warm.status == 0)
        #expect(fixture.swiftCalls == Self.buildCalls)
    }

    @Test(arguments: ["Sources/Example/Game.swift", "Package.swift", "Package.resolved"])
    func gameEditsStillRebuild(path: String) throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try fixture.warm()
        try fixture.date(fixture.game.appendingPathComponent(path), seconds: 3000)
        let result = try fixture.run()
        #expect(result.status == 0, "\(result.stderr)")
        #expect(fixture.swiftCalls == Self.buildCalls)
    }

    @Test(arguments: ["local", "checkout"])
    func removingAnEngineSourceRebuilds(layout: String) throws {
        let fixture = try Fixture(layout: layout)
        defer { fixture.remove() }
        try fixture.warm()
        try FileManager.default.removeItem(at: fixture.engine.appendingPathComponent("Sources/Example/Game.swift"))
        try fixture.date(fixture.engine.appendingPathComponent("Sources/Example"), seconds: 3000)
        let result = try fixture.run()
        #expect(result.status == 0, "\(result.stderr)")
        #expect(fixture.swiftCalls == Self.buildCalls)
    }

    @Test func forcingAWarmBuildStillBuilds() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try fixture.warm()
        let result = try fixture.run(["GNUSTO_MCP_BUILD": "1"])
        #expect(result.status == 0, "\(result.stderr)")
        #expect(result.stdout == Self.protocolOutput)
        #expect(fixture.swiftCalls == Self.buildCalls)
    }

    @Test func missingCachedBinaryBuildsAgain() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try fixture.write("/no/such/game\n", to: fixture.cache)
        let result = try fixture.run()
        #expect(result.status == 0, "\(result.stderr)")
        #expect(fixture.swiftCalls == Self.buildCalls)
        #expect(try String(contentsOf: fixture.cache, encoding: .utf8) == fixture.binary.path + "\n")
    }

    @Test func failedBuildNeverServesTheOldBinaryOrAdvancesItsStamp() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try fixture.warm()
        let result = try fixture.run(["GNUSTO_MCP_BUILD": "1", "FAKE_BUILD_FAIL": "1"])
        #expect(result.status == 2)
        #expect(result.stdout.isEmpty)
        #expect(result.stderr.contains("could not build Zwank"))
        #expect(fixture.swiftCalls == ["build --product Zwank"])
        let attributes = try FileManager.default.attributesOfItem(atPath: fixture.cache.path)
        #expect(attributes[.modificationDate] as? Date == Date(timeIntervalSince1970: 2000))
    }

    @Test func missingBuiltProductDoesNotRecordASuccess() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try FileManager.default.removeItem(at: fixture.binary)
        let result = try fixture.run()
        #expect(result.status == 2)
        #expect(result.stdout.isEmpty)
        #expect(result.stderr.contains("found no executable"))
        #expect(!FileManager.default.fileExists(atPath: fixture.cache.path))
    }
}
