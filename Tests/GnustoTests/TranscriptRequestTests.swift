import Foundation
import Gnusto
import Testing

/// A launcher reads `GNUSTO_TRANSCRIPT` through `TranscriptRequest`,
/// which actually opens the resolved file so a bad path is caught at launch —
/// see #494. This exercises the value type directly, the way
/// `SeedRequestTests` and `StatusFooterTests` exercise their siblings: `main()`
/// itself needs a live console and can't be driven from a test.
struct TranscriptRequestTests {
    private func tempDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
    }

    @Test func anAbsentVariableIsUnset() throws {
        let request = TranscriptRequest(gameTitled: "Cloak of Darkness", environment: [:])
        #expect(request.url == nil)
        #expect(request.complaint == nil)
    }

    @Test func anEmptyVariableIsUnset() throws {
        let request = TranscriptRequest(
            gameTitled: "Cloak of Darkness", environment: ["GNUSTO_TRANSCRIPT": ""])
        #expect(request.url == nil)
        #expect(request.complaint == nil)
    }

    @Test func aWritablePathOpensCleanlyAndComplainsNotAtAll() throws {
        let directory = tempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("session.txt")
        let request = TranscriptRequest(
            gameTitled: "Cloak of Darkness", environment: ["GNUSTO_TRANSCRIPT": file.path])
        #expect(request.url == file)
        #expect(request.complaint == nil)
    }

    /// The repro from #494: pointing `GNUSTO_TRANSCRIPT` at a directory (an
    /// unwritable path stands in the same way) can't be opened as a file, and
    /// used to be swallowed by `transcriptURL.flatMap { try? ... }` with no
    /// word on stderr and no transcript on disk.
    @Test func aPathThatCannotBeOpenedComplainsAndRecordsNothing() throws {
        let directory = tempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true)
        let request = TranscriptRequest(
            gameTitled: "Cloak of Darkness", environment: ["GNUSTO_TRANSCRIPT": directory.path])
        #expect(request.url == nil)
        let complaint = try #require(request.complaint)
        #expect(complaint.contains("GNUSTO_TRANSCRIPT"))
        #expect(complaint.contains(directory.path))
        #expect(complaint.contains("without a transcript"))
    }

    @Test func aBareFlagRecordsToTheGamesDefaultTranscriptsDirectory() throws {
        let directory = tempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let request = TranscriptRequest(
            gameTitled: "Cloak of Darkness",
            environment: [
                "GNUSTO_TRANSCRIPT": "1",
                "GNUSTO_TRANSCRIPT_DIR": directory.path,
            ])
        let url = try #require(request.url)
        #expect(url.deletingLastPathComponent().path == directory.path)
        #expect(url.lastPathComponent.hasPrefix("Cloak-of-Darkness-"))
        #expect(url.pathExtension == "txt")
        #expect(request.complaint == nil)
    }
}
