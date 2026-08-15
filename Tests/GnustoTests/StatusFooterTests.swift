import Foundation
import Gnusto
import GnustoTestSupport
import Testing

@testable import CloakOfDarkness
@testable import Fulminate

/// The `[status]` footer: one out-of-fiction line per turn saying where the
/// player is standing, what the move counter reads, and whether the command
/// they just typed cost a turn — the three things a transcript never says and a
/// reader always has to reconstruct.
///
/// The load-bearing test here is ``noFooterLeavesTheTranscriptExactlyAsItWas``.
/// Every other assertion in the suite is a substring lifted from the prose, so
/// a footer that leaked onto the default path would break hundreds of tests at
/// once — or, worse, break none of them and quietly change what the harness
/// claims a recorded transcript is.
struct StatusFooterTests {
    /// A fresh, isolated save directory, so a test's `save` slots can't be seen
    /// by another test or by the developer's real ones.
    private func tempDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
    }

    /// The footer a `GNUSTO_STATUS=1` environment produces.
    private var footer: StatusFooter {
        get throws {
            let request = StatusFooter(environment: ["GNUSTO_STATUS": "1"])
            #expect(request.complaint == nil)
            return try #require(request.inForce)
        }
    }

    /// Runs a game through a REPL with the footer in force and returns the
    /// transcript.
    private func playWithFooter(
        _ game: some Game, _ commands: [String], seed: UInt64 = 1
    ) async throws -> String {
        let world = try GameWorld(game: game, seed: seed, saveDirectory: tempDirectory())
        let io = ScriptedIOHandler(lines: commands)
        await REPL(world: world, io: io, status: try footer).run()
        return io.transcript
    }

    // MARK: - The line itself

    /// The exact shape, spelled out rather than probed field by field: this is
    /// the format the play-test briefs quote and a driver parses, so a change to
    /// it should have to be typed here too.
    @Test func theFooterRendersTheFourStandardFieldsInOrder() async throws {
        let transcript = try await playWithFooter(OperaHouse(), ["look", "frotz", "quit"])

        // The opening is not a turn and the counter stands at zero.
        #expect(
            transcript.contains(
                "[status] room=Foyer of the Opera House | moves=0 | score=0 | turn=free"))
        // A real command moves the world's clock on.
        #expect(
            turnOutput(of: "look", in: transcript).contains(
                "[status] room=Foyer of the Opera House | moves=1 | score=0 | turn=cost"))
        // A parse error costs nothing — the case that makes counting commands
        // as turns wrong, and the reason `turn=` exists at all.
        #expect(
            turnOutput(of: "frotz", in: transcript).contains(
                "[status] room=Foyer of the Opera House | moves=1 | score=0 | turn=free"))
    }

    /// `room=` follows the player, which is the other half of what a reader has
    /// to reconstruct by hand.
    @Test func theFooterNamesTheRoomThePlayerIsStandingIn() async throws {
        let transcript = try await playWithFooter(OperaHouse(), ["south", "north", "quit"])

        #expect(turnOutput(of: "south", in: transcript).contains("room=Foyer Bar"))
        #expect(
            turnOutput(of: "north", in: transcript).contains("room=Foyer of the Opera House"))
    }

    /// A meta verb is free, and the footer says so even though the command
    /// parsed perfectly well. `inventory` deliberately is not one — it costs a
    /// turn in this engine, and the footer is how a reader finds that out
    /// instead of assuming.
    @Test func aMetaVerbIsReportedFree() async throws {
        let transcript = try await playWithFooter(
            OperaHouse(), ["look", "score", "inventory", "quit"])

        #expect(turnOutput(of: "look", in: transcript).contains("moves=1 | score=0 | turn=cost"))
        #expect(turnOutput(of: "score", in: transcript).contains("moves=1 | score=0 | turn=free"))
        #expect(
            turnOutput(of: "inventory", in: transcript).contains(
                "moves=2 | score=0 | turn=cost"))
    }

    // MARK: - Opt-in by construction

    /// The regression guard, and the reason the `status:` parameter defaults to
    /// `nil` instead of consulting the environment: a REPL built the way
    /// `play(_:_:)` builds one produces the transcript it always did, whatever
    /// `GNUSTO_STATUS` happens to say in the shell running the suite.
    @Test func noFooterLeavesTheTranscriptExactlyAsItWas() async throws {
        let commands = ["look", "south", "north", "frotz", "quit"]
        let expected = try await play(OperaHouse(), commands, seed: 1)

        let world = try GameWorld(game: OperaHouse(), seed: 1, saveDirectory: tempDirectory())
        let io = ScriptedIOHandler(lines: commands)
        await REPL(world: world, io: io).run()

        #expect(io.transcript == expected)
        #expect(!io.transcript.contains("[status]"))
    }

    /// The console and the recorded file are one string, computed once — so a
    /// transcript lifted off disk and asserted on in a test is the transcript
    /// the tester read. Stage 0 landed this contract for the plain path; the
    /// footer must not be the thing that breaks it again.
    @Test func theRecordedTranscriptCarriesTheSameFooterBytes() async throws {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("session.txt")
        let world = try GameWorld(
            game: OperaHouse(), seed: 1, saveDirectory: tempDirectory())
        let io = ScriptedIOHandler(lines: ["look", "// a tester note", "south", "quit"])
        await REPL(world: world, io: io, transcriptURL: file, status: try footer).run()

        let recorded = try String(contentsOf: file, encoding: .utf8)
        #expect(recorded == io.transcript)
        #expect(recorded.contains("[status] room=Foyer Bar"))
    }

    // MARK: - Reading the environment

    @Test func theEnvironmentDecidesWhetherAFooterIsInForce() {
        #expect(StatusFooter(environment: [:]).inForce == nil)
        #expect(StatusFooter(environment: ["GNUSTO_STATUS": ""]).inForce == nil)
        #expect(StatusFooter(environment: ["GNUSTO_STATUS": "0"]).inForce == nil)
        #expect(StatusFooter(environment: ["GNUSTO_STATUS": "off"]).inForce == nil)
        #expect(StatusFooter(environment: ["GNUSTO_STATUS": " YES "]).inForce != nil)
        #expect(StatusFooter(environment: ["GNUSTO_STATUS": "true"]).inForce != nil)
    }

    /// A value nobody can read is reported rather than guessed at, the same
    /// policy `SeedRequest` follows — and the footer stays off, which is the
    /// default it would have had anyway.
    @Test func anUnreadableValueComplainsAndStaysOff() {
        let request = StatusFooter(environment: ["GNUSTO_STATUS": "maybe"])
        #expect(request.inForce == nil)
        #expect(request.complaint?.contains("GNUSTO_STATUS=maybe") == true)
        #expect(StatusFooter(environment: ["GNUSTO_STATUS": "1"]).complaint == nil)
    }

    // MARK: - Contributed fields

    /// A bundle's fields land after the four standard ones, in declaration
    /// order — and they are evaluated live, in a turn frame: `weather` reads a
    /// `@Global`, which would trap at bootstrap.
    @Test func aBundleContributesFieldsToTheFooter() async throws {
        let transcript = try await playWithFooter(WeatherStation(), ["look", "dig", "look at me"])

        #expect(
            transcript.contains(
                "[status] room=Observation Deck | moves=0 | score=0 | turn=free "
                    + "| weather=fair | readings=1"))
        // The needle moved this turn, and the footer read it after the turn ran.
        #expect(turnOutput(of: "dig", in: transcript).contains("weather=foul"))
    }

    /// The documented consequence of a field that writes: the frame it ran in is
    /// discarded, so `readings` counts to one on every turn forever instead of
    /// climbing. Pinned here because the contract is a comment otherwise.
    @Test func aMutatingFieldLosesItsWrite() async throws {
        let transcript = try await playWithFooter(WeatherStation(), ["look", "wait", "look at me"])

        #expect(occurrences(of: "readings=1", in: transcript) == 4)
        #expect(!transcript.contains("readings=2"))
    }

    /// A plugin the host merely stores is found too. Nothing else a plugin
    /// contributes works that way, so this is the seam worth a test.
    @Test func aStoredPluginContributesFieldsToTheFooter() async throws {
        let transcript = try await playWithFooter(WeatherStation(), ["look"])

        #expect(transcript.contains("| weather=fair | readings=1 | lamp=trimmed"))
    }

    /// The end the whole contribution point was built for: `GnustoClock` cannot
    /// be reached from the engine (it depends on it), so a timed game's hour got
    /// into the footer by being handed up. Fulminate opens at half past five and
    /// spends two minutes a turn.
    @Test func aClockGameShowsTheHour() async throws {
        let transcript = try await playWithFooter(
            Fulminate(), ["look", "wait", "wait"], seed: 0)

        #expect(transcript.contains("| turn=free | time=5:30 pm"))
        #expect(turnOutput(of: "look", in: transcript).contains("| time=5:32 pm"))
    }
}
