import Foundation
import Testing

@testable import CloakOfDarkness
@testable import Fulminate
@testable import Gnusto

/// Play-test sessions: the driver that plays a game on an agent's behalf, and
/// the registry that keeps several of them at once.
///
/// The suite's centre of gravity is ``aSessionsTranscriptIsByteIdenticalToTheREPLs``
/// and its two siblings. Everything the harness claims rests on a tester's
/// command list *being* a regression test — `docs/playtesting.md` and
/// `bin/playtest-replay` both promise, in those words, that a recorded
/// transcript is byte-for-byte the string a transcript test asserts on — and
/// the session driver is a second producer of that string. A one-byte
/// divergence on a reachable path has already happened once here (empty output
/// at the death prompt) and cost a stage to find, so these tests compare whole
/// files rather than substrings.
struct PlaytestSessionTests {
    // MARK: - Harness

    /// A session registry over one game, writing into a directory of its own.
    ///
    /// `GNUSTO_PLAYTEST_DIR` is the injection point, on the same precedent as
    /// `GNUSTO_SAVE_DIR`: a test must never write into the developer's real
    /// `.context/playtest`, where it would collide with a play-test round's
    /// evidence.
    private struct Harness {
        let sessions: PlaytestSessions
        let root: URL

        /// The tool table over the same root, for the rows whose subject is
        /// what a *client* meets. Its registry is a second one — a table always
        /// builds its own — which costs nothing and is safe: the disk layout is
        /// the shared state, and probe allocation is a `mkdir` lock precisely so
        /// that two registries under one root cannot take the same directory.
        let tools: [PlaytestTool]

        init(_ game: some Game, maxSessions: Int? = nil) throws {
            root = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
            var environment = ["GNUSTO_PLAYTEST_DIR": root.path]
            if let maxSessions {
                environment["GNUSTO_MCP_MAX_SESSIONS"] = "\(maxSessions)"
            }
            let prepared = try PreparedGame(game)
            sessions = PlaytestSessions(prepared: prepared, environment: environment)
            tools = PlaytestTools.table(for: prepared, environment: environment)
        }
    }

    /// The same commands through a real `REPL`, with the footer a session
    /// always runs with, returning what `ScriptedIOHandler` recorded — the
    /// exact string a transcript test in this suite asserts on.
    ///
    /// - Parameters:
    ///   - game: the game to play.
    ///   - commands: the lines to feed.
    ///   - seed: the seed to pin.
    ///   - saveDirectory: where bare save names resolve.
    ///   - status: the footer, or `nil` for the plain transcript
    ///     `play(_:_:seed:)` produces — which is what `export`'s second file
    ///     has to be.
    /// - Throws: whatever building the world throws.
    /// - Returns: the transcript.
    private func replTranscript(
        _ game: some Game, _ commands: [String], seed: UInt64, saveDirectory: URL,
        status: StatusFooter? = StatusFooter.always
    ) async throws -> String {
        let world = try GameWorld(game: game, seed: seed, saveDirectory: saveDirectory)
        let io = ScriptedIOHandler(lines: commands)
        await REPL(world: world, io: io, status: status).run()
        return io.transcript
    }

    /// A file's contents as text.
    private func text(at url: URL) throws -> String {
        String(decoding: try Data(contentsOf: url), as: UTF8.self)
    }

    // MARK: - The footer a session runs with

    /// `StatusFooter.always` is built through the public initializer, so that
    /// there is one definition of what "on" means — which also means a rename
    /// of the on-words table could turn a session's footer off *silently*.
    /// Nothing else in this suite would notice: byte identity compares a
    /// session against a REPL built the same way, so both would lose the footer
    /// together.
    @Test func theFooterASessionRunsWithIsReallyInForce() {
        #expect(StatusFooter.always.inForce != nil)
        #expect(StatusFooter.always.complaint == nil)
    }

    /// The opening handed back over JSON is rendered, not raw.
    ///
    /// `<br>` is the engine's hard-break marker and `TextWrap.plain` exists so
    /// that it never reaches a reader literally. The transcript on disk gets
    /// that from `TranscriptRecorder`; the `opening` field is the same words on
    /// a different channel and has to agree.
    ///
    /// Found by a play-tester, which is the part worth keeping: it read
    /// `Dungeon<br>The Great Underground Empire` in the first thing the server
    /// ever showed it and filed the marker. A harness that manufactures its own
    /// false positives spends a verifier on itself, so this is a defect in the
    /// tool and not a curiosity.
    @Test func theOpeningHandedBackIsRenderedRatherThanRaw() async throws {
        let harness = try Harness(HardBreakGame())
        let session = try await harness.sessions.open(label: "rendered", seed: 0)
        let opening = try await session.opening()

        #expect(opening.text.contains("Chapter One\nA Beginning"))
        #expect(!opening.text.contains(TextWrap.lineBreak))
        // The actual invariant is that the two channels agree, so check the one
        // that was already right rather than only the one that was wrong.
        #expect(try text(at: session.transcriptURL).contains("Chapter One\nA Beginning"))
    }

    // MARK: - Byte identity

    /// The crown jewel. A session plays; a REPL plays the same list at the same
    /// seed; the two transcripts are the same bytes.
    ///
    /// The list is chosen to cover every branch of the loop the two drivers
    /// share: a comment (recorded, no turn), a parse failure (`frotz`, a turn
    /// that costs nothing), turns that move the player between rooms, and the
    /// `quit` that ends the game — after which both drivers must stop, not
    /// merely stop printing.
    @Test func aSessionsTranscriptIsByteIdenticalToTheREPLs() async throws {
        let harness = try Harness(OperaHouse())
        let commands = [
            "look",
            "// the cloak is the only thing here worth having",
            "x cloak",
            "west",
            "put cloak on hook",
            "east",
            "north",
            "frotz",
            "look",
            "quit",
        ]

        let session = try await harness.sessions.open(label: "identity", seed: 0)
        _ = try await session.opening()
        _ = try await session.move(commands: commands, allowPrompts: true)

        let recorded = try text(at: session.transcriptURL)
        let replayed = try await replTranscript(
            OperaHouse(), commands, seed: 0, saveDirectory: session.saveDirectory)

        #expect(recorded == replayed)
        // Guards against the two ways this could pass vacuously: an empty file
        // on both sides, or a footer that quietly wasn't in force.
        #expect(recorded.contains("[status] room="))
        #expect(recorded.contains("> // the cloak is the only thing here worth having\n"))
    }

    /// The same claim across the two-turn save interaction, where the second
    /// line is not a command at all but a filename the engine consumes before
    /// the parser is reached. A driver that treated it as a command would
    /// diverge here and nowhere else.
    @Test func byteIdentityHoldsAcrossASaveAndItsFilenamePrompt() async throws {
        let harness = try Harness(OperaHouse())
        let commands = ["look", "save", "slot-one", "x cloak", "quit"]

        let session = try await harness.sessions.open(label: "saving", seed: 0)
        _ = try await session.opening()
        _ = try await session.move(commands: commands, allowPrompts: true)

        let recorded = try text(at: session.transcriptURL)
        let replayed = try await replTranscript(
            OperaHouse(), commands, seed: 0, saveDirectory: session.saveDirectory)
        #expect(recorded == replayed)
    }

    /// And across a death and the `quit` that answers its prompt — the one turn
    /// in the engine that prints *nothing*, which is where the last divergence
    /// lived. `freeReply("")` becomes a footer with no blank line above it, in
    /// both drivers or in neither.
    @Test func byteIdentityHoldsAcrossADeathPromptAnsweredWithQuit() async throws {
        let harness = try Harness(MorgueGame())
        let commands = ["look", "take poison", "quit"]

        let session = try await harness.sessions.open(label: "morgue", seed: 0)
        _ = try await session.opening()
        _ = try await session.move(commands: commands, allowPrompts: true)

        let recorded = try text(at: session.transcriptURL)
        let replayed = try await replTranscript(
            MorgueGame(), commands, seed: 0, saveDirectory: session.saveDirectory)
        #expect(recorded == replayed)
    }

    // MARK: - Exporting

    /// `export` is the byte-identity invariant turned into a tool: it replays
    /// the session's own command list through a fresh `REPL` and refuses to
    /// hand back a citable path unless the bytes match.
    ///
    /// The second file is the other half of the point. A finding's excerpt gets
    /// lifted into a suite test as an `expectInOrder` needle, and the suite never
    /// prints a `[status]` line — an excerpt carrying one would fail against a
    /// green suite and look like the game's fault. So the footer-free transcript
    /// is written too, and it is asserted here to be exactly what a REPL with no
    /// footer writes rather than the recorded file with lines filtered out of it.
    @Test func exportWritesBothTranscriptsAndProvesTheyReplay() async throws {
        let harness = try Harness(OperaHouse())
        let commands = ["look", "x cloak", "// worth having", "west", "put cloak on hook"]
        let session = try await harness.sessions.open(label: "exporting", seed: 0)
        _ = try await session.opening()
        _ = try await session.move(commands: commands, allowPrompts: false)

        let exported = try await session.export()
        #expect(exported.verified)
        #expect(exported.lines == commands.count)
        #expect(exported.message.contains("verified"))

        let footered = try text(at: URL(fileURLWithPath: exported.transcript))
        let plain = try text(at: URL(fileURLWithPath: exported.transcriptWithoutStatus))
        #expect(footered.contains("[status] room="))
        #expect(!plain.contains("[status]"))
        #expect(
            footered
                == (try await replTranscript(
                    OperaHouse(), commands, seed: 0, saveDirectory: session.saveDirectory)))
        #expect(
            plain
                == (try await replTranscript(
                    OperaHouse(), commands, seed: 0, saveDirectory: session.saveDirectory,
                    status: nil)))
        // The same prose in both, so an excerpt taken from either names the same
        // turn.
        #expect(plain.contains("You put the velvet cloak on the small brass hook."))
        #expect(footered.contains("You put the velvet cloak on the small brass hook."))

        #expect(try text(at: URL(fileURLWithPath: exported.commands)) == commands.joined(separator: "\n") + "\n")
        let summary = try text(at: URL(fileURLWithPath: exported.summary))
        #expect(summary.contains("byte identity: verified"))
        #expect(summary.contains("lines recorded: 5 (4 commands, 1 comment)"))
        #expect(summary.contains("transcript-without-status.txt"))
    }

    /// Exporting closes the recording; playing on reopens it and rewrites the
    /// file from the blocks in hand, so a tester that thinks of one more thing
    /// after it exported loses neither the old turns nor the new one.
    @Test func aSessionCarriesOnAfterAnExport() async throws {
        let harness = try Harness(OperaHouse())
        let session = try await harness.sessions.open(label: "reopening", seed: 0)
        _ = try await session.opening()
        _ = try await session.move(commands: ["look"], allowPrompts: false)
        _ = try await session.export()

        _ = try await session.move(commands: ["x cloak"], allowPrompts: false)
        let again = try await session.export()
        #expect(again.verified)
        #expect(again.lines == 2)
        #expect(
            try text(at: session.transcriptURL)
                == (try await replTranscript(
                    OperaHouse(), ["look", "x cloak"], seed: 0,
                    saveDirectory: session.saveDirectory)))
    }

    // MARK: - Checkpoints, restores and rewinds

    /// A checkpoint is an index into the command list, so coming back to it
    /// **truncates the record**. That is the design and not an omission: the
    /// invariant sold here is that `commands.txt` replays to `transcript.txt`,
    /// and a restore that rewound the world while leaving the record alone would
    /// break it on the spot — every reproducer filed afterwards would be a list
    /// of commands that does not produce the quoted line.
    ///
    /// What that would otherwise cost is the branch nobody took, so the
    /// discarded turns are kept beside the transcript as evidence. Nothing is
    /// lost; it stops being canonical.
    @Test func restoringACheckpointTruncatesTheRecordSoItStillReplays() async throws {
        let harness = try Harness(OperaHouse())
        let session = try await harness.sessions.open(label: "branching", seed: 0)
        _ = try await session.opening()
        _ = try await session.move(commands: ["x cloak", "west"], allowPrompts: false)

        let marked = try await session.checkpoint("in the cloakroom")
        #expect(marked.line == 2)
        #expect(marked.room == "Cloakroom")

        _ = try await session.move(commands: ["put cloak on hook", "east"], allowPrompts: false)
        let back = try await session.restore(checkpoint: "in the cloakroom")
        #expect(back.name == "in the cloakroom")
        #expect(back.line == 2)
        #expect(back.discarded == 2)
        #expect(back.room == "Cloakroom")

        // Both files are the prefix, and the prefix replays to exactly them.
        #expect(try text(at: session.commandsURL) == "x cloak\nwest\n")
        #expect(
            try text(at: session.transcriptURL)
                == (try await replTranscript(
                    OperaHouse(), ["x cloak", "west"], seed: 0,
                    saveDirectory: session.saveDirectory)))

        // The world really went back: the cloak is in hand again, so hanging it
        // is a thing that can still be done.
        let after = try await session.move(commands: ["put cloak on hook"], allowPrompts: false)
        #expect(after.contains("You put the velvet cloak on the small brass hook."))

        // And the branch survives as evidence, marked as not canonical.
        let branch = try text(at: URL(fileURLWithPath: try #require(back.branch)))
        #expect(branch.contains("[branch] 2 lines rewound out of session branching/probe-001"))
        #expect(branch.contains("> east"))
    }

    /// A rewind takes the world, the record and the queue back. It does **not**
    /// take back the fact that the tester read a room's prose.
    ///
    /// The 2026-08-17 round reported Vane's Study as never entered after a
    /// tester worked it for ten turns and rewound out; six branch files that
    /// round held 102 real engine turns the coverage denominator could not see,
    /// and a next-round planner handed that list spends its budget re-walking a
    /// walked room. Coverage is what the session *saw*, so it is kept where a
    /// rewind cannot reach it — and both ways back are checked here, because the
    /// ring path restores a held ledger and the replay path rebuilds one from
    /// nothing, and only one of those would have been caught by testing either
    /// alone.
    ///
    /// `signals.roomsVisited` stays canonical and is asserted as such: the
    /// signals beside it are ratios over the commands that survived, and pairing
    /// a rewound command count with a room count that was not would report a
    /// session as skimming for having gone back.
    @Test func coverageKeepsARoomThatARewindWroteOff() async throws {
        let harness = try Harness(OperaHouse())
        let session = try await harness.sessions.open(label: "rewound-rooms", seed: 0)
        _ = try await session.opening()
        _ = try await session.move(commands: ["x cloak"], allowPrompts: false)
        _ = try await session.checkpoint("the foyer")

        // Out to the Cloakroom and back, from inside the snapshot ring.
        _ = try await session.move(commands: ["west", "x hook"], allowPrompts: false)
        #expect(
            try await session.restore(checkpoint: "the foyer").room
                == "Foyer of the Opera House")

        let afterRing = try await session.finish(
            summary: "went west and came back", leaving: nil, limit: 3)
        #expect(afterRing.roomsVisited.map(\.id.raw) == ["foyer", "cloakroom"])
        #expect(afterRing.roomsVisited.map(\.name) == ["Foyer of the Opera House", "Cloakroom"])
        #expect(afterRing.roomsOnlyInBranches.map(\.raw) == ["cloakroom"])
        #expect(afterRing.signals.roomsVisited == 1)

        // And again from past the ring, which drops the world and the ledger and
        // replays the retained prefix — a prefix that never leaves the Foyer.
        _ = try await session.move(
            commands: ["west"] + Array(repeating: "look", count: PlaytestSession.snapshotRing + 4),
            allowPrompts: false)
        _ = try await session.restore(checkpoint: "the foyer")
        #expect(try text(at: session.commandsURL) == "x cloak\n")

        let afterReplay = try await session.finish(
            summary: "and again, from further out", leaving: nil, limit: 3)
        #expect(afterReplay.roomsVisited.map(\.id.raw) == ["foyer", "cloakroom"])
        #expect(afterReplay.roomsOnlyInBranches.map(\.raw) == ["cloakroom"])
        #expect(afterReplay.signals.roomsVisited == 1)
    }

    /// A turn can put the player in a room and take them out of it again, and
    /// the room is still one the tester read.
    ///
    /// Fulminate's 5:52 clock is the case in the wild, and the reason this test
    /// plays a real game rather than a fixture: walk north into the wreckage on
    /// the turn the radio car arrives and the patrolman walks you straight back
    /// out of it, so the transcript carries the whole Carriage House
    /// description under a status line that says Back Yard. The status line was
    /// the session's only record of where it had been, so the room could not be
    /// represented at all — the 2026-08-26 round duly reported the Carriage
    /// House as having taken zero commands in 1,288 turns, about a room three
    /// moves from the start that holds the victim.
    ///
    /// The room is entered and not *worked*, and both halves are asserted: a
    /// player who is walked out of a room never gets to type a line in it, so
    /// the stricter count is right to leave it out.
    @Test func coverageKeepsARoomTheTurnItselfWalkedThePlayerOutOf() async throws {
        let harness = try Harness(Fulminate())
        let session = try await harness.sessions.open(label: "evicted", seed: 0)
        _ = try await session.opening()

        // Two minutes to the turn from 5:30 pm, and an alarm fires at the end of
        // the first turn on or after its time, so the radio car ends turn 12 —
        // which is the turn this walks north on.
        let played = try await session.move(
            commands: ["south", "west"] + Array(repeating: "wait", count: 9) + ["north"],
            allowPrompts: false)
        #expect(played.contains("The roof is in the yard."))
        #expect(played.contains("walks you out of the wreckage"))
        #expect(played.contains("room=Back Yard | moves=12"))

        let closing = try await session.finish(
            summary: "walked in as the police arrived", leaving: nil, limit: 3)
        #expect(
            closing.roomsVisited.contains(
                .init(id: EntityID("carriageHouse"), name: "Carriage House")))
        // Its prose is in `transcript.txt`, and nothing here rewound, so the
        // pointer to the branch files must stay empty.
        #expect(closing.roomsOnlyInBranches.isEmpty)
        #expect(try text(at: session.transcriptURL).contains("The roof is in the yard."))
        #expect(!closing.roomsWorked.map(\.raw).contains("carriageHouse"))
    }

    /// A rewind does not unhappen a timer either, and the replay path is the
    /// one that would have lost it.
    ///
    /// Same argument as ``coverageKeepsARoomThatARewindWroteOff`` and the same
    /// two paths, because they fail differently: the ring hands the world back
    /// its state and `GameWorld.firedTimers` is deliberately untouched by that,
    /// while the replay path boots a **fresh** world whose tally starts at
    /// nothing. A round that lost a fire that way would report a live timer as
    /// never exercised, which is the one direction of error the closing record
    /// exists to rule out.
    @Test func theFiredTimerTallySurvivesBothWaysBackFromARewind() async throws {
        let harness = try Harness(HeartbeatGame())

        // Waits one line, checkpoints, waits `turns` more, rewinds to the
        // checkpoint and reports the tally. Whether that rewind comes back
        // through the ring or through a replay is decided by `turns` alone,
        // which is the whole point of running it twice.
        //
        // The checkpoint is at line 1 rather than at the opening so the replay
        // path has a **non-empty** prefix to re-play. That is what makes the
        // `max` merge load-bearing: the fresh world re-fires the one retained
        // line and reports 1, and a merge that took the newer value would throw
        // away everything the branch did.
        func waitedThenRewound(_ turns: Int, label: String) async throws -> [String: Int] {
            let session = try await harness.sessions.open(label: label, seed: 0)
            _ = try await session.opening()
            _ = try await session.move(commands: ["z"], allowPrompts: false)
            _ = try await session.checkpoint("one in")
            _ = try await session.move(
                commands: Array(repeating: "z", count: turns), allowPrompts: false)
            _ = try await session.restore(checkpoint: "one in")
            let closing = try await session.finish(
                summary: "waited, then went back", leaving: nil, limit: 3)
            // The canonical record really is one line long, so nothing below is
            // the signals' doing.
            #expect(closing.signals.commands == 1)
            return closing.firedTimers
        }

        // Inside the ring: the world is handed its old state back, and
        // `GameWorld.firedTimers` is deliberately not part of that state.
        let afterRing = try await waitedThenRewound(3, label: "rewound-in-ring")
        #expect(afterRing["heartbeat"] == 4)
        #expect(afterRing["dawn"] == 1)

        // Past it: the world is dropped and a fresh one replays the one retained
        // line, so a tally read off that world alone would report 1.
        let past = PlaytestSession.snapshotRing + 4
        let afterReplay = try await waitedThenRewound(past, label: "rewound-past-ring")
        #expect(afterReplay["heartbeat"] == past + 1)
        #expect(afterReplay["dawn"] == 1)
        // Declared and never started, either way round.
        #expect(afterRing["doom"] == nil)
        #expect(afterReplay["doom"] == nil)
    }

    /// A rewind takes the queue back with the world. A restore that put the
    /// world back and left the ledger where it was would re-offer every item the
    /// discarded turns closed and hide every one they raised — the queue would be
    /// describing a session that no longer exists.
    @Test func aRewindTakesTheQueueBackWithTheWorld() async throws {
        let harness = try Harness(AviaryGame())
        let session = try await harness.sessions.open(
            label: "rewinding", seed: 0, role: .explorer)
        _ = try await session.opening()
        _ = try await session.move(
            commands: ["x nest", "x pebble", "take pebble"], allowPrompts: false)
        #expect(try await session.coverage(limit: 200).items.contains { $0.id == "restate:pebble" })

        let back = try await session.rewind(turns: 1)
        #expect(back.name == nil)
        #expect(back.line == 2)
        #expect(back.discarded == 1)
        // The take is gone from the record, from the world, and from the queue.
        #expect(try text(at: session.commandsURL) == "x nest\nx pebble\n")
        #expect(!(try await session.coverage(limit: 200).items.contains { $0.id == "restate:pebble" }))
        let inventory = try await session.move(commands: ["i"], allowPrompts: false)
        #expect(!inventory.contains("pebble"))
    }

    /// Going back further than the ring reaches is a replay of the retained
    /// prefix — the same machinery an eviction uses, and exact for the same
    /// reason. The ring is a fast path, not the only one, which is what lets it
    /// be bounded.
    @Test func aRestoreOlderThanTheRingReplaysThePrefix() async throws {
        let harness = try Harness(OperaHouse())
        let session = try await harness.sessions.open(label: "deep", seed: 0)
        _ = try await session.opening()
        _ = try await session.move(commands: ["x cloak"], allowPrompts: false)
        _ = try await session.checkpoint("start")
        _ = try await session.move(
            commands: Array(repeating: "look", count: PlaytestSession.snapshotRing + 4),
            allowPrompts: false)

        let back = try await session.restore(checkpoint: "start")
        #expect(back.line == 1)
        #expect(back.discarded == PlaytestSession.snapshotRing + 4)
        #expect(try text(at: session.commandsURL) == "x cloak\n")
        #expect(
            try text(at: session.transcriptURL)
                == (try await replTranscript(
                    OperaHouse(), ["x cloak"], seed: 0,
                    saveDirectory: session.saveDirectory)))
    }

    /// A rewind onto a turn that opened a question replays rather than
    /// snapshotting, because `GameWorld.restore(_:)` closes questions on purpose
    /// and a session that came back to a line with a clarification armed has to
    /// find it armed — otherwise the next line means something different than it
    /// would in a replay, and the transcript stops being reproducible.
    @Test func aRewindOntoAnOpenQuestionReplaysAndTheQuestionIsStillThere() async throws {
        let harness = try Harness(LanternShopGame())
        let session = try await harness.sessions.open(label: "asked", seed: 0)
        _ = try await session.opening()
        _ = try await session.move(commands: ["take lantern"], allowPrompts: false)
        _ = try await session.checkpoint("asked")
        _ = try await session.move(commands: ["brass", "look"], allowPrompts: true)

        _ = try await session.restore(checkpoint: "asked")
        // The clarification is open again, so the next line is read as its
        // answer — which only happens if the rewind went through the replay.
        let answer = try await session.move(commands: ["brass"], allowPrompts: true)
        #expect(answer.contains("ran=1/1"))
        #expect(!answer.contains("don't know the word"))
    }

    /// The one refusal. Replay is exact only while the run depends on nothing
    /// outside it, and a save slot is outside it — so a session that used the
    /// player's own `save` cannot be put back to a line the ring no longer
    /// holds. Refused as a tool error naming the command list, rather than
    /// silently landing in a world that never happened.
    @Test func aSessionThatSavedCannotRewindPastTheRing() async throws {
        let harness = try Harness(OperaHouse())
        let session = try await harness.sessions.open(label: "saved", seed: 0)
        _ = try await session.opening()
        // The batch halts on the armed filename prompt, so the checkpoint stands
        // at a line whose snapshot is unusable — `GameWorld.restore(_:)` closes
        // questions on purpose — and the only way back is a replay, which this
        // session may not do.
        _ = try await session.move(commands: ["save"], allowPrompts: false)
        #expect(await session.isPinned())
        _ = try await session.checkpoint("armed")
        _ = try await session.move(commands: ["slot", "look"], allowPrompts: true)

        let refusal = await #expect(throws: PlaytestError.self) {
            try await session.restore(checkpoint: "armed")
        }
        #expect(refusal?.description.contains("save or restore") == true)
        #expect(refusal?.description.contains("Nothing moved") == true)
        // Nothing moved: the record is whole.
        #expect(try text(at: session.commandsURL) == "save\nslot\nlook\n")
    }

    /// The refusals that are about arithmetic rather than about safety.
    @Test func rewindAndRestoreRefuseLegibly() async throws {
        let harness = try Harness(OperaHouse())
        let session = try await harness.sessions.open(label: "refusing", seed: 0)
        _ = try await session.opening()
        _ = try await session.move(commands: ["look"], allowPrompts: false)

        let tooFar = await #expect(throws: PlaytestError.self) {
            try await session.rewind(turns: PlaytestSession.snapshotRing + 1)
        }
        #expect(tooFar?.description.contains("at most \(PlaytestSession.snapshotRing)") == true)
        #expect(tooFar?.description.contains("checkpoint") == true)

        let tooMany = await #expect(throws: PlaytestError.self) {
            try await session.rewind(turns: 4)
        }
        #expect(tooMany?.description.contains("has only 1") == true)

        let unknown = await #expect(throws: PlaytestError.self) {
            try await session.restore(checkpoint: "nowhere")
        }
        #expect(unknown?.description.contains("has none") == true)

        _ = try await session.checkpoint("here")
        let missing = await #expect(throws: PlaytestError.self) {
            try await session.restore(checkpoint: "elsewhere")
        }
        #expect(missing?.description.contains("This session has: here") == true)
    }

    // MARK: - Halting on a question

    /// A `save` mid-batch arms a filename prompt, so the next line would be
    /// eaten as a filename rather than parsed. The batch stops there and says
    /// what is pending and what did not run — which is the state
    /// `bin/playtest-replay` cannot see and papers over with a spare `quit`.
    @Test func aPromptArmingMidBatchHaltsTheBatch() async throws {
        let harness = try Harness(OperaHouse())
        let session = try await harness.sessions.open(label: "halting", seed: 0)
        _ = try await session.opening()

        let report = try await session.move(
            commands: ["look", "save", "north", "x cloak"], allowPrompts: false)

        #expect(report.contains("awaiting=saveFilename"))
        #expect(report.contains("ran=2/4"))
        #expect(report.contains("2 commands did not run: `north`, `x cloak`"))
        #expect(report.contains("allowPrompts=true"))
        // The unrun commands really did not run: nothing after the prompt is in
        // the transcript.
        #expect(!(try text(at: session.transcriptURL).contains("> north")))
    }

    /// `allowPrompts` is the tester saying "the next line is the answer".
    @Test func allowPromptsRunsTheWholeBatchThroughAPrompt() async throws {
        let harness = try Harness(OperaHouse())
        let session = try await harness.sessions.open(label: "answering", seed: 0)
        _ = try await session.opening()

        let report = try await session.move(
            commands: ["save", "autumn", "look"], allowPrompts: true)

        #expect(report.contains("ran=3/3"))
        #expect(report.contains("awaiting=none"))
        #expect(!report.contains("did not run"))
        #expect(
            SaveStore.existingSaveNames(in: session.saveDirectory) == ["autumn"])
    }

    /// The death prompt is the same mechanism with the highest stakes: while it
    /// is armed *every* line is an answer, so a batch that kept going would
    /// spend its remaining commands on "I don't understand" and look like a
    /// game that had stopped responding.
    @Test func aDeathPromptHaltsTheBatchAndNamesItself() async throws {
        let harness = try Harness(MorgueGame())
        let session = try await harness.sessions.open(label: "poison", seed: 0)
        _ = try await session.opening()

        let report = try await session.move(
            commands: ["take poison", "look", "x table"], allowPrompts: false)

        #expect(report.contains("The world goes dark."))
        #expect(report.contains("awaiting=deathChoice"))
        #expect(report.contains("finished=false"))
        #expect(report.contains("RESTART, RESTORE, UNDO or QUIT"))
        #expect(report.contains("2 commands did not run"))
    }

    /// A clarifying question counts too. "Which do you mean, the brass lantern
    /// or the small brass lantern?" makes the next line an answer first and a
    /// command second, and a tester whose remaining batch was written for the
    /// parser wants to know before it is spent.
    @Test func aClarifyingQuestionAlsoHaltsTheBatch() async throws {
        let harness = try Harness(LanternShopGame())
        let session = try await harness.sessions.open(label: "lanterns", seed: 0)
        _ = try await session.opening()

        let report = try await session.move(
            commands: ["take lantern", "look"], allowPrompts: false)

        #expect(report.contains("awaiting=clarification"))
        #expect(report.contains("ran=1/2"))
    }

    /// A finished game halts whatever the caller asked for: `allowPrompts` is
    /// about questions, not about resurrection.
    @Test func aFinishedGameStopsTheBatchAndThenRefusesTheNextOne() async throws {
        let harness = try Harness(OperaHouse())
        let session = try await harness.sessions.open(label: "over", seed: 0)
        _ = try await session.opening()

        let report = try await session.move(
            commands: ["quit", "look"], allowPrompts: true)
        #expect(report.contains("finished=true"))
        #expect(report.contains("the game has ended"))
        #expect(report.contains("1 command did not run"))

        let refusal = await #expect(throws: PlaytestError.self) {
            try await session.move(commands: ["look"], allowPrompts: false)
        }
        #expect(refusal?.description.contains("has finished") == true)
    }

    // MARK: - Comments

    /// A comment is recorded and costs nothing: no turn, no clock tick. Proven
    /// against a game with a clock, because the move counter alone would not
    /// catch a driver that ran the comment through a *free* path — the hour is
    /// a function of the counter, so both fields have to stand still.
    @Test func aCommentIsRecordedAndCostsNoTurnAndNoClockTick() async throws {
        let harness = try Harness(ClockLab())
        let session = try await harness.sessions.open(label: "clock", seed: 0)
        _ = try await session.opening()

        let report = try await session.move(
            commands: ["look", "// nothing has moved", "take coin"], allowPrompts: false)

        // The comment sits in the transcript with no output block of its own,
        // so the next command's echo follows it immediately.
        #expect(report.contains("> // nothing has moved\n> take coin\n"))
        // The hours are the ones each turn was written at, not the ones its
        // counter left behind — see `Scratch.statusFieldState`. What this test
        // is about survives that unchanged: two cost turns exactly one minute
        // apart, with the comment between them adding nothing to either.
        #expect(report.contains("moves=1 | score=0 | turn=cost | time=8:00 pm"))
        #expect(report.contains("moves=2 | score=0 | turn=cost | time=8:01 pm"))
        #expect(!report.contains("moves=3"))
        #expect(report.contains("ran=3/3"))
    }

    // MARK: - script / unscript

    /// A session has been recording since it opened, so a second recorder over
    /// the same session is a trap: two files, each missing what the other has,
    /// and a finding citing whichever the tester opened. Refused as a tool
    /// error — and refused before anything runs, so the batch is all-or-nothing
    /// rather than half-played behind a failed call.
    @Test func scriptAndUnscriptAreRefusedWithAnExplanation() async throws {
        let harness = try Harness(OperaHouse())
        let session = try await harness.sessions.open(label: "scripting", seed: 0)
        _ = try await session.opening()

        for line in ["script", "script mine", "unscript"] {
            let refusal = await #expect(throws: PlaytestError.self) {
                try await session.move(commands: ["look", line], allowPrompts: false)
            }
            #expect(refusal?.description.contains("transcript command") == true)
            #expect(refusal?.description.contains("recall") == true)
        }
        // Nothing ran, three times over: the `look` in front of the refused
        // line never reached the world.
        #expect(!(try text(at: session.transcriptURL).contains("> look")))
    }

    // MARK: - Isolation between sessions

    /// `SaveStore.defaultDirectory(forGameTitled:)` is per *title*, so left
    /// alone every session in the process would share one slot namespace and
    /// the restore prompt would read every tester's saves back to whoever
    /// asked. Each session gets its label's directory instead.
    @Test func twoSessionsDoNotSeeEachOthersSaveSlots() async throws {
        let harness = try Harness(OperaHouse())
        let mine = try await harness.sessions.open(label: "tester-a", seed: 0)
        let yours = try await harness.sessions.open(label: "tester-b", seed: 0)
        _ = try await mine.opening()
        _ = try await yours.opening()

        _ = try await mine.move(commands: ["save", "mine-only"], allowPrompts: true)

        // The restore prompt lists the slots in the saves directory, so it is
        // the player-visible proof of who can see what.
        let hers = try await yours.move(commands: ["restore"], allowPrompts: true)
        #expect(!hers.contains("mine-only"))
        let his = try await mine.move(commands: ["restore"], allowPrompts: true)
        #expect(his.contains("mine-only"))

        #expect(mine.saveDirectory != yours.saveDirectory)
        #expect(SaveStore.existingSaveNames(in: yours.saveDirectory).isEmpty)
    }

    /// Two sessions each get a probe directory of their own, allocated with
    /// `mkdir` as the lock, so neither can overwrite the other's evidence.
    @Test func everySessionGetsItsOwnProbeDirectory() async throws {
        let harness = try Harness(OperaHouse())
        let first = try await harness.sessions.open(label: "shared", seed: 0)
        let second = try await harness.sessions.open(label: "shared", seed: 0)

        #expect(first.probe == "probe-001")
        #expect(second.probe == "probe-002")
        #expect(first.id == "shared/probe-001")
        #expect(first.transcriptURL != second.transcriptURL)
        // Probes under one label share the label's saves, which is what makes a
        // save in one probe restorable in the next.
        #expect(first.saveDirectory == second.saveDirectory)
    }

    // MARK: - Opening onto somebody else's saves

    /// A session under its own label, walked into the Cloakroom and saved
    /// there, for the staging rows below to copy out of.
    ///
    /// The player's own `save` verb through `move`, as in
    /// `PlaytestReplayTests.keeper`: what these rows are about is what the
    /// *game* can read back, not what a fixture wrote.
    private func keeper(
        _ registry: PlaytestSessions, label: String = "keeper", slot: String = "deep"
    ) async throws -> PlaytestSession {
        let session = try await registry.open(label: label, seed: 0)
        _ = try await session.opening()
        _ = try await session.move(commands: ["west"], allowPrompts: false)
        _ = try await session.move(commands: ["save", slot], allowPrompts: true)
        return session
    }

    /// `savesFrom` names a label, and the slots arrive in the opener's own
    /// label — with a receipt that says so.
    ///
    /// This is the door the sessionless `replay` has had all along and the
    /// session path had not. Without it a round shipping a pre-cut save had to
    /// have its operator hand-copy each `.gnusto` into every session's saves
    /// directory before dispatch, which means knowing the workflow's label
    /// scheme in advance; the 2026-08-25 Dungeon round did exactly that.
    @Test func openingWithASavesFromLabelStagesItsSlotsUnderTheNewLabel() async throws {
        let harness = try Harness(OperaHouse())
        let keeper = try await keeper(harness.sessions)
        let open = try #require(harness.tools.first { $0.name == "open" })

        let result = try await open.call(["label": "reader", "savesFrom": "keeper"])

        // The receipt is the point: a tester told to `restore deep` has to see
        // that `deep` arrived, or the only way to find out costs a turn.
        let structured = try #require(result.structured)
        #expect(structured["savesStaged"] == .array([.string("deep")]))
        #expect(structured["savesFrom"]?.stringValue == keeper.saveDirectory.path)

        // Under the reader's label, not the keeper's: probes under one label
        // share its saves, so every later probe the tester opens can restore
        // these too.
        #expect(
            SaveStore.existingSaveNames(
                in: harness.root.appendingPathComponent("reader/saves")) == ["deep"])
        #expect(SaveStore.existingSaveNames(in: keeper.saveDirectory) == ["deep"])
    }

    /// `savesFrom` naming a path stages a directory that is no label at all.
    ///
    /// The branch `SaveStore.isExplicitPath` picks, and the one a round
    /// actually uses: a cut save is a directory somebody kept, outside the
    /// play-test root, and by the time it is handed out the label that wrote it
    /// is usually gone.
    @Test func aSavesFromPathStagesADirectoryThatIsNoLabel() async throws {
        let harness = try Harness(OperaHouse())
        let keeper = try await keeper(harness.sessions)
        let open = try #require(harness.tools.first { $0.name == "open" })

        // The round's cut save, under the name its brief will tell the tester
        // to ask for, in a directory nothing could reach as a label.
        let cut = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: cut, withIntermediateDirectories: true)
        try FileManager.default.copyItem(
            at: keeper.saveDirectory.appendingPathComponent("deep.gnusto"),
            to: cut.appendingPathComponent("z-1.gnusto"))

        let result = try await open.call(
            ["label": "reader", "savesFrom": .string(cut.path)])

        let structured = try #require(result.structured)
        #expect(structured["savesStaged"] == .array([.string("z-1")]))
        #expect(structured["savesFrom"]?.stringValue == cut.path)
        #expect(
            SaveStore.existingSaveNames(
                in: harness.root.appendingPathComponent("reader/saves")) == ["z-1"])
    }

    /// The whole point, played out: a session opened onto a staged slot
    /// restores it and stands where the save was written.
    ///
    /// The rows above prove the bytes moved. This one proves the game can read
    /// them — the keeper saved in the Cloakroom, so a reader that answers the
    /// restore prompt with `deep` is looking at the Cloakroom and not at the
    /// Foyer it opened in.
    @Test func aSessionRestoresTheSlotItWasOpenedWith() async throws {
        let harness = try Harness(OperaHouse())
        let keeper = try await keeper(harness.sessions)

        let reader = try await harness.sessions.open(
            label: "reader", seed: 0, savesFrom: keeper.saveDirectory)
        _ = try await reader.opening()
        let restored = try await reader.move(
            commands: ["restore", "deep", "look"], allowPrompts: true)

        #expect(!restored.contains("Restore failed"))
        #expect(restored.contains("Cloakroom"))
        #expect(reader.staged?.copied == ["deep"])
        #expect(reader.staged?.from == keeper.saveDirectory)
    }

    /// A `savesFrom` holding no slots refuses in the sentence the replay path
    /// has always used, and opens nothing.
    ///
    /// The refusal comes before the probe is allocated, so a mistyped or
    /// already-cleaned source leaves no directory pretending to be a session
    /// that never opened.
    @Test func aSavesFromWithNoSlotsRefusesAndLeavesNoSession() async throws {
        let harness = try Harness(OperaHouse())
        let empty = try await harness.sessions.open(label: "empty-handed", seed: 0)

        let refusal = await #expect(throws: PlaytestError.self) {
            try await harness.sessions.open(
                label: "reader", seed: 0, savesFrom: empty.saveDirectory)
        }

        #expect(refusal?.description.contains("holds no saved games") == true)
        let opened = await harness.sessions.count()
        #expect(opened == 1)
        #expect(
            !FileManager.default.fileExists(
                atPath: harness.root.appendingPathComponent("reader/probe-001").path))
    }

    /// A second `open` under one label with the same `savesFrom` succeeds, and
    /// leaves the tester's own slot exactly where it was.
    ///
    /// A label's `saves/` outlives every probe under it, so the second probe
    /// stages onto a directory that already holds those names — where the
    /// replay path, staging into a fresh throwaway every time, could never
    /// collide. Copying over the name would be worse than failing: by the
    /// second `open` the slot standing there may be the tester's own game,
    /// saved under the name the round happened to choose.
    @Test func aSecondOpenUnderOneLabelKeepsTheTestersOwnSlot() async throws {
        let harness = try Harness(OperaHouse())
        let keeper = try await keeper(harness.sessions)

        let first = try await harness.sessions.open(
            label: "reader", seed: 0, savesFrom: keeper.saveDirectory)
        _ = try await first.opening()
        // The tester saves over the staged name from the room it opened in, so
        // `deep` under `reader` is now the reader's game and not the round's.
        _ = try await first.move(commands: ["save", "deep"], allowPrompts: true)
        let slot = first.saveDirectory.appendingPathComponent("deep.gnusto")
        let mine = try Data(contentsOf: slot)

        let second = try await harness.sessions.open(
            label: "reader", seed: 0, savesFrom: keeper.saveDirectory)

        #expect(second.staged?.copied.isEmpty == true)
        #expect(second.staged?.kept == ["deep"])
        // Still restorable, which is the only thing the receipt promises.
        #expect(second.staged?.restorable == ["deep"])
        #expect(try Data(contentsOf: slot) == mine)
    }

    // MARK: - Durability

    /// `commands.txt` is what makes the accepted crash risk survivable: a
    /// `fatalError` in any game rule takes down every session in the process,
    /// and recovery is a re-`open` plus a replay — which is only a recovery if
    /// the list is on disk. So it is written after every move, and it is
    /// exactly what was sent, comments included.
    @Test func theCommandListIsOnDiskAfterEveryMove() async throws {
        let harness = try Harness(OperaHouse())
        let session = try await harness.sessions.open(label: "durable", seed: 0)
        _ = try await session.opening()

        _ = try await session.move(commands: ["look", "// a note"], allowPrompts: false)
        #expect(try text(at: session.commandsURL) == "look\n// a note\n")

        _ = try await session.move(commands: ["x cloak"], allowPrompts: false)
        #expect(try text(at: session.commandsURL) == "look\n// a note\nx cloak\n")

        // The layout is bin/playtest-replay's, so a citation from either
        // harness looks the same to whoever follows it.
        #expect(session.directory.lastPathComponent == "probe-001")
        #expect(session.directory.deletingLastPathComponent().lastPathComponent == "durable")
        #expect(session.saveDirectory.lastPathComponent == "saves")
        #expect(FileManager.default.fileExists(atPath: session.transcriptURL.path))
    }

    // MARK: - Eviction

    /// Over the cap, the least recently used session drops its world — and the
    /// agent never learns. The next call replays the command list at the same
    /// seed, which is only sound because the game is deterministic, and answers
    /// as though nothing had happened. The transcript it rewrites is the
    /// transcript that was there.
    @Test func anEvictedSessionRehydratesToTheIdenticalState() async throws {
        let harness = try Harness(OperaHouse(), maxSessions: 1)
        let first = try await harness.sessions.open(label: "evicted", seed: 0)
        _ = try await first.opening()
        _ = try await first.move(commands: ["look", "x cloak"], allowPrompts: false)
        let before = try text(at: first.transcriptURL)
        #expect(await first.isLive())

        // Opening a second session puts the process over the cap of one.
        let second = try await harness.sessions.open(label: "survivor", seed: 0)
        _ = try await second.opening()
        #expect(!(await first.isLive()))

        // Used again, it comes back on its own, with no error surfaced.
        let recalled = try await first.recall(from: 0, to: 99, grep: nil)
        #expect(await first.isLive())
        #expect(recalled.contains("Foyer of the Opera House"))
        #expect(try text(at: first.transcriptURL) == before)

        // And it is a *world*, not a recording: play continues from where it
        // left off, and the whole transcript is still the REPL's.
        _ = try await first.move(commands: ["west"], allowPrompts: false)
        let continued = try text(at: first.transcriptURL)
        let replayed = try await replTranscript(
            OperaHouse(), ["look", "x cloak", "west"], seed: 0,
            saveDirectory: first.saveDirectory)
        #expect(continued == replayed)
    }

    /// Eviction drops the world, and the tally is not the world's to lose.
    ///
    /// The agent never learns it was evicted and neither should the round: a
    /// session that played thirty turns, lost its world to another session's
    /// arrival and then called `finish` would otherwise account for no timer at
    /// all — and "no timer fired" is exactly the sentence this field exists to
    /// let a round say truthfully. Nothing in `evict()` is involved, which is
    /// the point of folding the tally as each line is recorded rather than at
    /// the seams that drop a world.
    @Test func anEvictedSessionKeepsItsFiredTimerTally() async throws {
        let harness = try Harness(HeartbeatGame(), maxSessions: 1)
        let first = try await harness.sessions.open(label: "evicted-timers", seed: 0)
        _ = try await first.opening()
        _ = try await first.move(commands: ["z", "z", "z"], allowPrompts: false)

        // Opening a second session puts the process over the cap of one.
        let second = try await harness.sessions.open(label: "survivor", seed: 0)
        _ = try await second.opening()
        #expect(!(await first.isLive()))

        let closing = try await first.finish(summary: "waited", leaving: nil, limit: 3)
        #expect(closing.firedTimers["heartbeat"] == 3)
        #expect(closing.firedTimers["dawn"] == 1)
    }

    /// A session that used `save` or `restore` may not be evicted. Replay is
    /// exact only while the run depends on nothing outside it, and a save slot
    /// is outside it: another probe under the same label may have rewritten it,
    /// so a replay could restore a different world and record a transcript that
    /// never happened. The cap is exceeded instead, out loud.
    @Test func aSessionThatSavedIsPinnedAgainstEviction() async throws {
        let harness = try Harness(OperaHouse(), maxSessions: 1)
        let saver = try await harness.sessions.open(label: "pinned", seed: 0)
        _ = try await saver.opening()
        _ = try await saver.move(commands: ["save", "keepsake"], allowPrompts: true)
        #expect(await saver.isPinned())

        let other = try await harness.sessions.open(label: "other", seed: 0)
        _ = try await other.opening()

        #expect(await saver.isLive())
        #expect(await other.isLive())
    }

    /// A restore reached from the death prompt pins the session too, even
    /// though no `restore` verb was ever parsed — the line was an answer, not a
    /// command, so the intent is not where the fact lives.
    @Test func aRestoreAnsweredAtTheDeathPromptAlsoPins() async throws {
        let harness = try Harness(MorgueGame())
        let session = try await harness.sessions.open(label: "revive", seed: 0)
        _ = try await session.opening()

        _ = try await session.move(
            commands: ["take poison", "restore"], allowPrompts: true)

        #expect(await session.isPinned())
    }

    // MARK: - Result size

    /// A tool built to make the next look cheap must not be able to answer with
    /// 40 KB. Over the cap, whole commands are dropped from the front and the
    /// marker names the `recall` range that reads them back — so nothing is
    /// lost, only deferred to a call the agent makes when it wants it.
    @Test func aLongBatchIsTruncatedWithAMarkerPointingAtRecall() async throws {
        let harness = try Harness(OperaHouse())
        let session = try await harness.sessions.open(label: "verbose", seed: 0)
        _ = try await session.opening()

        let report = try await session.move(
            commands: Array(repeating: "look", count: 80), allowPrompts: false)

        #expect(report.contains("[truncated "))
        #expect(report.contains("use recall(from: 1, to: "))
        #expect(report.count < PlaytestSession.resultCharacterCap + 500)
        // The tail survives: the last turn is the one the next command depends
        // on.
        #expect(report.contains("ran=80/80"))

        // And the dropped turns really are readable.
        let recalled = try await session.recall(from: 1, to: 3, grep: nil)
        #expect(recalled.contains("Foyer of the Opera House"))
        #expect(recalled.contains("recalled=3 of 80 lines"))
    }

    // MARK: - recall

    @Test func recallFiltersToTheTurnsThatMentionSomething() async throws {
        let harness = try Harness(OperaHouse())
        let session = try await harness.sessions.open(label: "recalling", seed: 0)
        _ = try await session.opening()
        _ = try await session.move(
            commands: ["x cloak", "west", "x hook"], allowPrompts: false)

        let hooks = try await session.recall(from: 1, to: 3, grep: "hook")
        #expect(hooks.contains("> x hook"))
        #expect(!hooks.contains("> x cloak"))

        // A range with nothing in it says so rather than returning a blank.
        let empty = try await session.recall(from: 50, to: 60, grep: nil)
        #expect(empty.contains("nothing in lines 50–60"))
        #expect(empty.contains("3 recorded lines"))
    }

    @Test func recallRefusesABackwardsRange() async throws {
        let harness = try Harness(OperaHouse())
        let session = try await harness.sessions.open(label: "backwards", seed: 0)
        _ = try await session.opening()

        let refusal = await #expect(throws: PlaytestError.self) {
            try await session.recall(from: 9, to: 2, grep: nil)
        }
        #expect(refusal?.description.contains("from ≤ to") == true)
    }

    // MARK: - The registry refuses legibly

    /// A mistyped session id is an error the caller can act on, not a trap.
    /// Nothing in the MCP layer may `fatalError`, and this is the input most
    /// likely to be wrong: it comes from a language model copying an id.
    @Test func anUnknownSessionIdIsAReadableToolError() async throws {
        let harness = try Harness(OperaHouse())

        let cold = await #expect(throws: PlaytestError.self) {
            try await harness.sessions.session("nope")
        }
        #expect(cold?.description.contains("none are open") == true)

        _ = try await harness.sessions.open(label: "known", seed: 0)
        let warm = await #expect(throws: PlaytestError.self) {
            try await harness.sessions.session("nope")
        }
        #expect(warm?.description.contains("known/probe-001") == true)
    }

    /// A label becomes a directory name, so it keeps to the alphabet
    /// `bin/playtest-replay`'s `plain_name` enforces — and in particular may
    /// not start with a dot or climb out of the play-test root.
    @Test func aBadLabelIsRefusedBeforeAnythingIsCreated() async throws {
        let harness = try Harness(OperaHouse())

        for label in ["../escape", ".bin", "has space", "", "sla/sh"] {
            let refusal = await #expect(throws: PlaytestError.self) {
                try await harness.sessions.open(label: label, seed: 0)
            }
            #expect(refusal?.description.contains("Bad label") == true)
        }
        #expect(!FileManager.default.fileExists(atPath: harness.root.path))
    }

    // MARK: - Seeds

    /// A seed belongs to the session, arrives with the request that opens one,
    /// and defaults to 0 — matching `bin/playtest-replay --seed 0`, so a
    /// finding from either harness names the same run.
    @Test func twoSeedsPlayTwoDifferentGamesAndEachIsReproducible() async throws {
        let harness = try Harness(MorgueGame())
        let commands = ["look", "beckon", "wait"]

        let zero = try await harness.sessions.open(label: "seed-zero", seed: 0)
        _ = try await zero.opening()
        _ = try await zero.move(commands: commands, allowPrompts: true)

        let seven = try await harness.sessions.open(label: "seed-seven", seed: 7)
        _ = try await seven.opening()
        _ = try await seven.move(commands: commands, allowPrompts: true)

        #expect(zero.seed == 0)
        #expect(seven.seed == 7)
        let atZero = try text(at: zero.transcriptURL)
        let atSeven = try text(at: seven.transcriptURL)
        let replayedZero = try await replTranscript(
            MorgueGame(), commands, seed: 0, saveDirectory: zero.saveDirectory)
        let replayedSeven = try await replTranscript(
            MorgueGame(), commands, seed: 7, saveDirectory: seven.saveDirectory)
        #expect(atZero == replayedZero)
        #expect(atSeven == replayedSeven)
    }

    // MARK: - Over the wire

    /// The three tools end to end through `MCPServer.handle(line:)`, because
    /// the schemas and the handlers are what a client actually meets — and a
    /// tool whose arguments are read wrong fails identically to one that isn't
    /// there.
    @Test func theSessionToolsWorkOverTheProtocol() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let server = MCPServer(
            name: "gnusto-playtest", version: "test", instructions: nil,
            tools: PlaytestTools.table(
                for: try PreparedGame(OperaHouse()),
                environment: ["GNUSTO_PLAYTEST_DIR": root.path]))

        let opened = try JSONValue(
            text: try #require(
                await server.handle(
                    line: """
                        {"jsonrpc":"2.0","id":1,"method":"tools/call","params":\
                        {"name":"open","arguments":{"label":"wire","seed":0}}}
                        """)))
        #expect(opened["result"]?["isError"] == .bool(false))
        let session = try #require(
            opened["result"]?["structuredContent"]?["session"]?.stringValue)
        #expect(session == "wire/probe-001")
        #expect(
            opened["result"]?["structuredContent"]?["opening"]?.stringValue?
                .contains("Foyer of the Opera House") == true)
        #expect(
            opened["result"]?["structuredContent"]?["status"]?.stringValue?
                .hasPrefix("[status] room=") == true)
        #expect(opened["result"]?["structuredContent"]?["awaiting"]?.stringValue == "none")

        let moved = try JSONValue(
            text: try #require(
                await server.handle(
                    line: """
                        {"jsonrpc":"2.0","id":2,"method":"tools/call","params":\
                        {"name":"move","arguments":{"session":"\(session)",\
                        "commands":["look","x cloak"]}}}
                        """)))
        let transcript = try #require(
            moved["result"]?["content"]?.arrayValue?.first?["text"]?.stringValue)
        // Prose, not JSON: a move result has no structuredContent, because
        // escaping a multi-line quote-heavy transcript into a JSON string
        // inflates it and makes it unreadable to its one reader.
        #expect(moved["result"]?["structuredContent"] == nil)
        #expect(transcript.contains("> x cloak"))
        #expect(transcript.contains("ran=2/2"))

        let recalled = try JSONValue(
            text: try #require(
                await server.handle(
                    line: """
                        {"jsonrpc":"2.0","id":3,"method":"tools/call","params":\
                        {"name":"recall","arguments":{"session":"\(session)",\
                        "from":0,"to":1}}}
                        """)))
        #expect(
            recalled["result"]?["content"]?.arrayValue?.first?["text"]?.stringValue?
                .contains("Foyer of the Opera House") == true)

        // A bad session id is a tool error the agent can read, never a trap and
        // never a protocol error.
        let missing = try JSONValue(
            text: try #require(
                await server.handle(
                    line: """
                        {"jsonrpc":"2.0","id":4,"method":"tools/call","params":\
                        {"name":"move","arguments":{"session":"ghost",\
                        "commands":["look"]}}}
                        """)))
        #expect(missing["error"] == nil)
        #expect(missing["result"]?["isError"] == .bool(true))
        #expect(
            missing["result"]?["content"]?.arrayValue?.first?["text"]?.stringValue?
                .contains("No session \"ghost\"") == true)
    }
}
