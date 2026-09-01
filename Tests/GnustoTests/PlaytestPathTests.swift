import Foundation
import Testing

/// What a relative path means to `bin/playtest-replay`, exercised by running it.
///
/// The script `cd`s to its own repository root before it reads a single
/// argument, so every path-taking flag has to be resolved against the directory
/// the caller stood in or it silently names a file in the Gnusto checkout
/// instead. That is invisible in this repository, where the harness always runs
/// from the package root and every flag happens to work; it bites the audience
/// `bin/new-game` exists for, driving a generated package by hand (#382).
///
/// **Nothing here runs `swift`, and that is a hard constraint rather than a
/// preference.** `swift package describe` took 89 seconds on a warm tree on
/// this machine, queued behind the seven MCP servers contending for SwiftPM's
/// `.build` lock. So each test drives the script only as far as one of its own
/// refusals or receipts — with a recorded binary that is `/bin/echo` — and
/// reads the answer off stderr. The script's exit status is beside the point:
/// every case here is *meant* to fail, and what is asserted is **which**
/// failure, because that is what says where the path was resolved.
struct PlaytestPathTests {
    /// The package root, found relative to this file rather than to the working
    /// directory, which a test process does not control.
    private static let packageRoot =
        URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // GnustoTests
        .deletingLastPathComponent()  // Tests
        .deletingLastPathComponent()  // the package

    /// Run `bin/playtest-replay` from `currentDirectory`, returning its exit
    /// status and the two streams. A non-zero exit is a result this suite
    /// asserts against, never an error.
    @discardableResult
    private static func replay(
        _ arguments: [String],
        from currentDirectory: URL
    ) throws -> (status: Int32, stdout: String, stderr: String) {
        let process = Process()
        process.executableURL = packageRoot.appendingPathComponent("bin/playtest-replay")
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

    /// A fresh directory that is not the repository root, standing in for the
    /// generated package somebody is driving by hand.
    ///
    /// The path is the *physical* one, because every path this suite matches on
    /// is one the script derived from `pwd`, and macOS hangs its temporary
    /// directory off a symlinked `/var`. `realpath` rather than
    /// `resolvingSymlinksInPath`, which on Darwin deliberately strips a leading
    /// `/private` and so hands back exactly the spelling the shell will not use.
    private static func scratch() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true)
        guard let resolved = realpath(directory.path, nil) else { return directory }
        defer { free(resolved) }
        return URL(fileURLWithPath: String(cString: resolved))
    }

    /// Make `directory` look like a package `bin/playtest-replay --build` has
    /// already been run in, without building anything: the script reads the
    /// recorded path and asks only that it be executable.
    private static func recordBinary(_ game: String, in directory: URL) throws {
        let cache = directory.appendingPathComponent(".context/playtest/.bin")
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        try "/bin/echo\n".write(
            to: cache.appendingPathComponent("\(game).path"), atomically: true, encoding: .utf8)
    }

    // MARK: - --package-path

    @Test func aRelativePackagePathNamesTheCallersPackage() throws {
        let here = try Self.scratch()
        defer { try? FileManager.default.removeItem(at: here) }
        try FileManager.default.createDirectory(
            at: here.appendingPathComponent("Zwank"), withIntermediateDirectories: true)

        // No --commands, so the run stops at the first check *after* the
        // package path is validated. Reaching that complaint is the proof the
        // directory check passed, and it passed against `here`.
        let result = try Self.replay(
            ["Zwank", "--package-path", "Zwank"], from: here)
        #expect(
            result.stderr.contains("--commands FILE is required"),
            "expected the run to get past --package-path; it said: \(result.stderr)")
    }

    @Test func aRelativePackagePathIsNotReadAgainstTheGnustoCheckout() throws {
        let here = try Self.scratch()
        defer { try? FileManager.default.removeItem(at: here) }

        // `Sources` exists in the Gnusto checkout and not here. Before #382 the
        // script accepted it and quietly built the caller's game inside Gnusto.
        // The refusal names the resolved path rather than the word typed,
        // because "relative to what?" is the whole question the flag got wrong.
        let result = try Self.replay(
            ["Zwank", "--package-path", "Sources"], from: here)
        #expect(
            result.stderr.contains("--package-path '\(here.path)/Sources' is not a directory"),
            "expected 'Sources' to be read against \(here.path); it said: \(result.stderr)")
    }

    // MARK: - --saves-from

    @Test func aRelativeSavesFromPathNamesTheCallersDirectory() throws {
        let here = try Self.scratch()
        defer { try? FileManager.default.removeItem(at: here) }
        try Self.recordBinary("Zwank", in: here)

        let deep = here.appendingPathComponent("deep")
        try FileManager.default.createDirectory(at: deep, withIntermediateDirectories: true)
        try "slot".write(
            to: deep.appendingPathComponent("one.gnusto"), atomically: true, encoding: .utf8)
        try "look\n".write(
            to: here.appendingPathComponent("probe.txt"), atomically: true, encoding: .utf8)

        // The receipt names the directory the slots came from, which is the one
        // thing in this script that says out loud where a path was resolved.
        let result = try Self.replay(
            ["Zwank", "--commands", "probe.txt", "--saves-from", "./deep"], from: here)
        #expect(
            result.stderr.contains("staged 1 slot(s) from './deep' (\(deep.path))"),
            "expected './deep' to be read against \(here.path); it said: \(result.stderr)")
    }

    @Test func aBareSavesFromNameIsStillALabel() throws {
        let here = try Self.scratch()
        defer { try? FileManager.default.removeItem(at: here) }
        try Self.recordBinary("Zwank", in: here)
        try "look\n".write(
            to: here.appendingPathComponent("probe.txt"), atomically: true, encoding: .utf8)

        // No slash, so this is a sibling label under the package's playtest
        // tree — not a path, and so not something the invocation directory has
        // any say over.
        let result = try Self.replay(
            ["Zwank", "--commands", "probe.txt", "--saves-from", "earlier"], from: here)
        #expect(
            result.stderr.contains(
                "holds no .gnusto slots in \(here.path)/.context/playtest/earlier/saves"),
            "expected a bare name to stay a label; it said: \(result.stderr)")
    }

    // MARK: - --commands

    @Test func aRelativeCommandFileNamesTheCallersFile() throws {
        let here = try Self.scratch()
        defer { try? FileManager.default.removeItem(at: here) }
        try Self.recordBinary("Zwank", in: here)

        // Named for a file the Gnusto checkout really has at its root, so a
        // regression would read *that* one and never complain (#384).
        try "look\n".write(
            to: here.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        let readme = try Self.replay(["Zwank", "--commands", "README.md"], from: here)
        #expect(
            !readme.stderr.contains("no such command file"),
            "expected README.md to be read from \(here.path); it said: \(readme.stderr)")

        let missing = try Self.replay(["Zwank", "--commands", "CONTRIBUTING.md"], from: here)
        #expect(
            missing.stderr.contains("no such command file: \(here.path)/CONTRIBUTING.md"),
            "expected the complaint to name \(here.path); it said: \(missing.stderr)")
    }
}
