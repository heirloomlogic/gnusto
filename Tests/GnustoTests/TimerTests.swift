import Foundation
import GnustoTestSupport
import Testing

@testable import Gnusto

private func temporarySavePath(_ label: String) -> String {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("gnusto-\(label)-\(UUID().uuidString).sav").path
}

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
            ["summon", "take boulder", "sing", "frotz"])
        // Refused turn (scenery take): world time passes, the drip arrives.
        let refused = turnOutput(of: "take boulder", in: transcript)
        #expect(refused.contains("You can't take that."))
        #expect(refused.contains("Drip."))
        // Stub verb: an ordinary turn, so the drip arrives here too.
        #expect(turnOutput(of: "sing", in: transcript).contains("Drip."))
        // Parse error: free, no tick. `frotz` is nonsense rather than a stub
        // verb, which would tick — that contrast is the point.
        let error = turnOutput(of: "frotz", in: transcript)
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

    // MARK: - Namespacing (issue #403)

    /// Two bundles that both name a daemon `roam` load together, and the
    /// host's own `roam` daemon is untouched by either.
    @Test func twoBundlesAndTheGameMayShareADaemonName() async throws {
        let (definition, state) = try Bootstrap.build(RoamGame())
        #expect(
            definition.timers.keys.sorted() == [
                "AlphaRoamBundle.roam", "BetaRoamBundle.roam", "roam",
            ])
        // The game's own autostarted daemon is the bare key; the bundles'
        // daemons wait for their starting rules.
        #expect(state.activeDaemons == ["roam"])

        let transcript = try await play(RoamGame(), ["look", "look"])
        // The game's own daemon runs from turn one; neither bundle's has
        // been started.
        #expect(transcript.contains("[game] Something roams."))
        #expect(!transcript.contains("[alpha] Something roams."))
        #expect(!transcript.contains("[beta] Something roams."))
    }

    /// Each bundle's rule starts its own daemon by the bare literal it
    /// declared, even though the name is now three ways ambiguous in the
    /// schedule — the owner context decides.
    @Test func aBundleRuleStartsItsOwnDaemonByBareName() async throws {
        let transcript = try await play(RoamGame(), ["rousea", "look"])
        let wake = turnOutput(of: "rousea", in: transcript)
        #expect(wake.contains("[alpha] Something roams."))
        #expect(!wake.contains("[beta] Something roams."))
        let look = turnOutput(of: "look", in: transcript)
        #expect(look.contains("[alpha] Something roams."))
        #expect(!look.contains("[beta] Something roams."))
    }

    /// The host game reaches a bundle's collided daemon only by its qualified
    /// name — and the qualified name stops exactly that one.
    @Test func theGameAddressesACollidingDaemonByQualifiedName() async throws {
        let transcript = try await play(
            RoamGame(), ["rousea", "rouseb", "hushalpha", "look"])
        let hush = turnOutput(of: "hushalpha", in: transcript)
        #expect(hush.contains("[beta] Something roams."))
        #expect(!hush.contains("[alpha] Something roams."))
        let look = turnOutput(of: "look", in: transcript)
        #expect(look.contains("[beta] Something roams."))
        #expect(!look.contains("[alpha] Something roams."))
    }

    /// A namespaced schedule key saves, restores, and re-binds to the right
    /// bundle's body.
    @Test func aCollidedDaemonScheduleRoundTripsThroughSaveAndRestore() async throws {
        let path = temporarySavePath("roam")
        defer { try? FileManager.default.removeItem(atPath: path) }
        let transcript = try await play(
            RoamGame(),
            [
                "rouseb", "save", path,
                "look",
                "restore", path,
                "look", "hushbeta", "look",
            ])
        // The beta roam runs on the rouseb turn, the pre-save look, the
        // restore turn itself, and the first look after it; the hush turn
        // stops it before its tick, so the final look is silent.
        #expect(transcript.components(separatedBy: "[beta] Something roams.").count == 4)
        #expect(!transcript.contains("[alpha] Something roams."))
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

    // MARK: - Naming a timer wrongly

    // The platform policy for exit tests is in `Package.swift`.
    #if GNUSTO_EXIT_TESTS

    /// The seven timer traps, run for real. Bootstrap catches a bad *declaration*
    /// (`duplicateNamesAndZeroCountsReportTogether` above); these are the ones
    /// only a live rule body can commit — a fuse helper handed a daemon's name,
    /// or a name no `timers` block declares.
    ///
    /// What is under test is the *advice*, not the complaint. Each message
    /// quotes the offending call and then names the helper the author meant,
    /// and the second half is what turns a crash into a fix. Asserting it
    /// caught one that had lost its advice: `fuseRemaining` on a daemon used to
    /// say only "names a daemon", leaving the author to guess
    /// `isDaemonActive(_:)`.
    ///
    /// A child process apiece — see ``expectTrap(_:says:sourceLocation:)`` for
    /// when that is worth spending. Issue #227.
    @Test("every timer misuse names the helper the author meant", arguments: TimerMisuse.allCases)
    func timerMisuseNamesTheRightHelper(_ misuse: TimerMisuse) async throws {
        let result = await #expect(
            processExitsWith: .failure, observing: [\.standardErrorContent]
        ) {
            // Explicit capture, spelled with its type: an exit test's body runs
            // in a fresh process, so it takes only values it can encode across,
            // and the macro has to see what type to decode on the far side.
            [misuse = misuse as TimerMisuse] in
            _ = try await play(TimerMisuseGame(), [misuse.command])
        }
        let spec = misuse.spec
        expectTrap(result, says: spec.namesTheCall, spec.saysUse)
    }

    #endif
}
