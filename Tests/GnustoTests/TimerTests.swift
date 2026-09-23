import Foundation
import GnustoTestSupport
import Testing

@testable import Gnusto

private func temporarySavePath(_ label: String) -> String {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("gnusto-\(label)-\(UUID().uuidString).sav").path
}

/// A fuse whose declared count stands past what a save may carry.
///
/// The declaration is ordinary arithmetic and the game would play. A running
/// fuse's count rides in every save, so a declared count this large is either
/// carried into a save no restore will accept, or overridden at every start
/// and never used at all. Neither is what the author meant, and the first case
/// would reach them as a bare "Restore failed." on a file their own game
/// wrote. Bootstrap says so at the declaration instead.
private struct OverlongFuseGame: Game {
    let title = "Overlong Fuse"
    let intro = "Should never boot."

    let room = Location { name("Room") }

    var map: WorldMap {
        player.starts(in: room)
    }

    var timers: [TimedEvent] {
        fuse("eon", after: WorldState.counterLimit + 1) {}
    }
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

    @Test func timersStartedInsideATickBodyFirstTickNextTurn() async throws {
        // `chain` lights a 1-turn fuse from a rule, so it fires at the end of
        // that turn (the rule above). Its body starts a 1-turn fuse and a
        // daemon — but the tick reads the schedule once, before any body runs,
        // so both wait for the next turn's tick. Fuses and daemons alike: one
        // sentence, not one per kind.
        let transcript = try await play(ClockGame(), ["chain", "look"])
        let chain = turnOutput(of: "chain", in: transcript)
        #expect(chain.contains("The link burns through."))
        #expect(!chain.contains("The bomb goes off!"))
        #expect(!chain.contains("Drip."))
        let look = turnOutput(of: "look", in: transcript)
        #expect(look.contains("The bomb goes off!"))
        #expect(look.contains("Drip."))
    }

    @Test func aFuseRestartedInsideATickWaitsForTheNextTickWhateverItsName() async throws {
        // `a` restarts `b` (which sorts after it) and `c` restarts `a2`
        // (which sorts before it), both `after: 2`, on the same tick. Neither
        // restarted fuse is counted down again on that tick, so both fire at
        // the end of the third turn.
        let transcript = try await play(RestartTickGame(), ["wait", "look", "wait"])
        let first = turnOutput(of: "wait", in: transcript)
        #expect(first.contains("A restarts b."))
        #expect(first.contains("C restarts a2 and the pulse."))
        let second = turnOutput(of: "look", in: transcript)
        #expect(!second.contains("B fires."))
        #expect(!second.contains("A2 fires."))
        let third = turnOutput(ofLast: "wait", in: transcript)
        #expect(third.contains("B fires."))
        #expect(third.contains("A2 fires."))
    }

    @Test func aDaemonRestartedInsideATickWaitsForTheNextTick() async throws {
        // `c` stops and restarts the running `pulse` daemon. A timer a body
        // starts first runs on the next tick, so the pulse skips this one.
        let transcript = try await play(RestartTickGame(), ["wait", "look"])
        let first = turnOutput(of: "wait", in: transcript)
        #expect(first.contains("C restarts a2 and the pulse."))
        #expect(!first.contains("Pulse."))
        #expect(turnOutput(of: "look", in: transcript).contains("Pulse."))
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

    /// A fuse count a restore would refuse is named at bootstrap.
    ///
    /// `WorldState.counterLimit` bounds every whole number a save carries, and
    /// a running fuse's count is one of them. What this proves is that the
    /// declaration alone is enough: the count is refused where it is written,
    /// in a diagnostic naming the fuse and the bound, rather than left for a
    /// "Restore failed." that names neither.
    @Test func aFuseCountPastTheSaveBoundIsRefusedAtBootstrap() {
        #expect {
            try Bootstrap.build(OverlongFuseGame())
        } throws: { error in
            guard let bootstrapError = error as? BootstrapError else { return false }
            let text = bootstrapError.description
            return text.contains("fuse \"eon\"")
                && text.contains("carried by every save")
                && text.contains("\(WorldState.counterLimit)")
        }
    }

    /// A bare declaration whose name equals the qualified key another
    /// owner's namespaced declaration produces is fatal — the second write
    /// would otherwise silently take the schedule slot.
    @Test func aBareNameMayNotCollideWithANamespacedKey() {
        #expect {
            try Bootstrap.build(NamespacedClashGame())
        } throws: { error in
            guard let bootstrapError = error as? BootstrapError else { return false }
            return bootstrapError.description.contains(
                "two timers both resolve to \"AlphaRoamBundle.roam\"")
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

    @Test("an invalid runtime fuse override names the declared-fuse rule", arguments: InvalidFuseOverride.allCases)
    func invalidRuntimeFuseOverrideNamesTheDeclaredFuseRule(_ misuse: InvalidFuseOverride) async throws {
        let parser = StandardParser(vocabulary: Vocabulary(), syntaxRules: [])
        #expect(parser.tokenize(misuse.command) == [misuse.command])
        let result = await #expect(
            processExitsWith: .failure, observing: [\.standardErrorContent]
        ) {
            [misuse = misuse as InvalidFuseOverride] in
            _ = try await play(TimerMisuseGame(), [misuse.command])
        }
        expectTrap(result, says: misuse.call, "a fuse needs at least one turn")
    }

    #endif
}
