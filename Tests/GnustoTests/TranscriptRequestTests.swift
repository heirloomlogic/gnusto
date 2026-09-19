import Foundation
import GnustoTestSupport
import Testing

@testable import CloakOfDarkness
@testable import Gnusto

/// `GameMain.main()` reads `GNUSTO_TRANSCRIPT` through `TranscriptRequest`,
/// which actually opens the resolved file so a bad path is caught at launch —
/// see #494. This exercises the value type directly, the way
/// `SeedRequestTests` and `StatusFooterTests` exercise their siblings: `main()`
/// itself needs a live console and can't be driven from a test.
struct TranscriptRequestTests {
    private func tempDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
    }

    @Test func anAbsentVariableIsUnset() async throws {
        let world = try cachedWorld(OperaHouse())
        let request = TranscriptRequest(world: world, environment: [:])
        #expect(request.url == nil)
        #expect(request.complaint == nil)
    }

    @Test func anEmptyVariableIsUnset() async throws {
        let world = try cachedWorld(OperaHouse())
        let request = TranscriptRequest(
            world: world, environment: ["GNUSTO_TRANSCRIPT": ""])
        #expect(request.url == nil)
        #expect(request.complaint == nil)
    }

    @Test func aWritablePathOpensCleanlyAndComplainsNotAtAll() async throws {
        let world = try cachedWorld(OperaHouse())
        let file = tempDirectory().appendingPathComponent("session.txt")
        let request = TranscriptRequest(
            world: world, environment: ["GNUSTO_TRANSCRIPT": file.path])
        #expect(request.url == file)
        #expect(request.complaint == nil)
    }

    /// The repro from #494: pointing `GNUSTO_TRANSCRIPT` at a directory (an
    /// unwritable path stands in the same way) can't be opened as a file, and
    /// used to be swallowed by `transcriptURL.flatMap { try? ... }` with no
    /// word on stderr and no transcript on disk.
    @Test func aPathThatCannotBeOpenedComplainsAndRecordsNothing() async throws {
        let world = try cachedWorld(OperaHouse())
        let directory = tempDirectory()
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true)
        let request = TranscriptRequest(
            world: world, environment: ["GNUSTO_TRANSCRIPT": directory.path])
        #expect(request.url == nil)
        let complaint = try #require(request.complaint)
        #expect(complaint.contains("GNUSTO_TRANSCRIPT"))
        #expect(complaint.contains(directory.path))
        #expect(complaint.contains("without a transcript"))
    }

    @Test func aBareFlagRecordsToTheGamesDefaultTranscriptsDirectory() async throws {
        let world = try cachedWorld(OperaHouse())
        let directory = tempDirectory()
        let request = TranscriptRequest(
            world: world,
            environment: [
                "GNUSTO_TRANSCRIPT": "1",
                "GNUSTO_TRANSCRIPT_DIR": directory.path,
            ])
        let url = try #require(request.url)
        #expect(url.path.hasPrefix(directory.path))
        #expect(request.complaint == nil)
    }
}
