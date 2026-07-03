import Foundation
import Testing

@testable import Gnusto

struct TimerTests {
    // MARK: - Fuses

    @Test func fuseFiresExactlyOnceAfterItsCount() async throws {
        let transcript = try await play(
            ClockGame(),
            ["prime", "look", "look", "look", "look"])
        // Primed at the end of turn 1; ticks 2, 1, 0 → fires at the end of
        // the third turn after priming... but the prime turn itself ticks
        // too, so: prime (3→2), look (2→1), look (1→0, fires).
        let looks = transcript.components(separatedBy: "> look")
        #expect(!looks[0].contains("The bomb goes off!"))
        #expect(!looks[1].contains("The bomb goes off!"))
        #expect(looks[2].contains("The bomb goes off!"))
        #expect(!looks[3].contains("The bomb goes off!"))
        #expect(!looks[4].contains("The bomb goes off!"))
    }

    @Test func fuseRemainingCountsDown() async throws {
        let transcript = try await play(
            ClockGame(),
            ["probe", "prime", "probe", "probe", "defuse", "probe"])
        let probes = transcript.components(separatedBy: "> probe")
        #expect(probes[1].contains("Remaining: none"))
        // After the prime turn's tick: 2. After another (probe) turn: 1.
        #expect(probes[2].contains("Remaining: 2"))
        #expect(probes[3].contains("Remaining: 1"))
        // Defused: gone.
        #expect(probes[4].contains("Remaining: none"))
    }

    @Test func defusedFuseNeverFires() async throws {
        let transcript = try await play(
            ClockGame(),
            ["prime", "defuse", "look", "look", "look", "look"])
        #expect(!transcript.contains("The bomb goes off!"))
    }

    @Test func restartingAFuseResetsItsCount() async throws {
        let transcript = try await play(
            ClockGame(),
            ["prime", "look", "prime", "look", "look", "look"])
        // Without the re-prime the bomb would fire at the end of turn 3
        // (3→2, 2→1, 1→0). Re-priming on turn 3 resets the count before that
        // turn's tick (3→2 again), pushing the firing to turn 5 — once.
        let turns = transcript.components(separatedBy: "> ")
        #expect(!turns[3].contains("The bomb goes off!"))
        #expect(turns[5].contains("The bomb goes off!"))
        #expect(transcript.components(separatedBy: "The bomb goes off!").count == 2)
    }

    @Test func fuseStartedMidTurnTicksThatSameTurn() async throws {
        // startFuse("bomb", after: 1) inside the command's rule: the end of
        // that same turn decrements 1 → 0 and fires.
        let transcript = try await play(ClockGame(), ["shortprime"])
        let turn = turnOutput(of: "shortprime", in: transcript)
        #expect(turn.contains("You prime the bomb on a short fuse."))
        #expect(turn.contains("The bomb goes off!"))
    }

    // MARK: - Daemons

    @Test func daemonRunsFromItsStartTurnUntilStopped() async throws {
        let transcript = try await play(
            ClockGame(),
            ["summon", "look", "banish", "look"])
        // Started mid-turn: first runs at the end of that same turn.
        #expect(turnOutput(of: "summon", in: transcript).contains("Drip."))
        #expect(turnOutput(of: "look", in: transcript).contains("Drip."))
        // The banish turn: the daemon was stopped before the tick — silent.
        #expect(!turnOutput(of: "banish", in: transcript).contains("Drip."))
        let looks = transcript.components(separatedBy: "> look")
        #expect(!looks[2].contains("Drip."))
    }

    @Test func daemonTicksOnRefusedTurnsButNotParseErrors() async throws {
        let transcript = try await play(
            ClockGame(),
            ["summon", "take boulder", "xyzzy"])
        // Refused turn (scenery take): world time passes, the drip arrives.
        let refused = turnOutput(of: "take boulder", in: transcript)
        #expect(refused.contains("You can't take that."))
        #expect(refused.contains("Drip."))
        // Parse error: free, no tick.
        let error = turnOutput(of: "xyzzy", in: transcript)
        #expect(!error.contains("Drip."))
    }

    @Test func takeAllTicksOnce() async throws {
        let transcript = try await play(ClockGame(), ["summon", "take all"])
        let turn = turnOutput(of: "take all", in: transcript)
        // Three objects, one drip.
        #expect(turn.contains("brass cog: Taken."))
        #expect(turn.components(separatedBy: "Drip.").count == 2)
    }

    // MARK: - Autostart

    @Test func autostartTimersRunWithNoRuleInvolved() async throws {
        let transcript = try await play(HeartbeatGame(), ["look", "look", "look"])
        // The heartbeat runs from turn 1; the dawn fuse (after: 2) fires at
        // the end of turn 2 and never again.
        let looks = transcript.components(separatedBy: "> look")
        #expect(looks[1].contains("Thump."))
        #expect(looks[2].contains("Thump."))
        #expect(looks[3].contains("Thump."))
        #expect(!looks[1].contains("Dawn breaks."))
        #expect(looks[2].contains("Dawn breaks."))
        #expect(!looks[3].contains("Dawn breaks."))
    }

    @Test func fatalFuseStopsLaterTimersThatTurn() async throws {
        // "doom" (fires end of the doom turn) ends the game; the heartbeat
        // daemon — alphabetically after the doom fuse — must not run that
        // turn, and the game is over.
        let transcript = try await play(HeartbeatGame(), ["doom"])
        let turn = turnOutput(of: "doom", in: transcript)
        #expect(turn.contains("Doom arrives."))
        #expect(!turn.contains("Thump."))
    }

    // MARK: - Bootstrap validation

    @Test func duplicateNamesAndZeroCountsReportTogether() {
        #expect {
            try Bootstrap.build(BadTimersGame())
        } throws: { error in
            guard let bootstrapError = error as? BootstrapError else { return false }
            let text = bootstrapError.description
            return text.contains("dup") && text.contains("zero")
        }
    }

    // MARK: - Schedule state round-trips (consumed by save/restore)

    @Test func scheduleLivesInWorldState() throws {
        let (definition, state) = try Bootstrap.build(HeartbeatGame())
        #expect(state.activeDaemons == ["heartbeat"])
        #expect(state.activeFuses == ["dawn": 2])
        #expect(definition.timers.count == 3)
    }
}
