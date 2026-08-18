import Foundation
import Testing

@testable import CloakOfDarkness
@testable import Gnusto

/// The two tools that belong to nobody's session: `replay`, which plays a
/// command list in a fresh world and adjudicates a claim about it, and
/// `vocabulary`, which is answer-key data and gated as such.
///
/// The suite's weight is on two things. ``aReplayIsByteIdenticalToASession``
/// pins the third driver in this module to the other two — the harness sells one
/// property above all others, that a command list replays to the same
/// transcript, and a replay tool that produced *nearly* the session's bytes
/// would quietly refute every finding a verifier checked with it. And
/// ``vocabularyIsRefusedByRoleAndAllowedForAHuman`` is the firewall applied to
/// the sharpest leak there is: a tester that can look up the vocabulary can
/// never again discover that a printed noun has nothing behind it.
struct PlaytestReplayTests {
    // MARK: - Harness

    /// A session registry writing into a directory of its own, on the same
    /// `GNUSTO_PLAYTEST_DIR` precedent as the rest of these suites.
    private func sessions(_ game: some Game) throws -> PlaytestSessions {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        return PlaytestSessions(
            prepared: try PreparedGame(game),
            environment: ["GNUSTO_PLAYTEST_DIR": root.path])
    }

    /// A server over one game, for the tools that are only meetable over the
    /// wire.
    private func server(_ game: some Game) throws -> MCPServer {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        return MCPServer(
            name: "gnusto-playtest", version: "test", instructions: nil,
            tools: PlaytestTools.table(
                for: try PreparedGame(game),
                environment: ["GNUSTO_PLAYTEST_DIR": root.path]))
    }

    /// A file's contents as text.
    private func text(at url: URL) throws -> String {
        String(decoding: try Data(contentsOf: url), as: UTF8.self)
    }

    /// A tool table over a root the test can then read, for the rows whose
    /// subject is what they left on disk.
    private func table(_ game: some Game) throws -> (root: URL, tools: [PlaytestTool]) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        return (
            root,
            PlaytestTools.table(
                for: try PreparedGame(game),
                environment: ["GNUSTO_PLAYTEST_DIR": root.path])
        )
    }

    // MARK: - The claim a finding makes

    /// A claim that holds up comes back with the frame: which line printed it,
    /// which room, which move count, and the whole turn around it.
    ///
    /// This is the single most expensive step of the old verify checklist —
    /// *"replay the reproducer yourself and confirm the excerpt appears verbatim
    /// in the frame claimed"* — done as a call.
    @Test func anExcerptThatPrintedComesBackWithItsFrame() async throws {
        let outcome = try await PlaytestReplay.run(
            prepared: try PreparedGame(OperaHouse()),
            commands: ["x cloak", "west", "put cloak on hook"],
            seed: 0,
            expect: "You put the velvet cloak on the small brass hook.")

        let verdict = try #require(outcome.verdict)
        #expect(verdict.found)
        #expect(verdict.turn == 3)
        #expect(verdict.room == "Cloakroom")
        #expect(verdict.command == "put cloak on hook")
        #expect(verdict.context.hasPrefix("> put cloak on hook\n"))
        #expect(verdict.context.contains("[status] room=Cloakroom"))
        #expect(outcome.lines == 3)
        #expect(!outcome.finished)
    }

    /// A claim that does not hold up says so, and hands back what was really
    /// there rather than a bare `false`.
    @Test func anExcerptThatNeverPrintedSaysSoAndShowsTheLastFrame() async throws {
        let outcome = try await PlaytestReplay.run(
            prepared: try PreparedGame(OperaHouse()),
            commands: ["x cloak", "west"],
            seed: 0,
            expect: "A badger blocks the way.")

        let verdict = try #require(outcome.verdict)
        #expect(!verdict.found)
        #expect(verdict.turn == 2)
        #expect(verdict.command == "west")
        #expect(verdict.context.contains("> west"))
        #expect(outcome.rendered.contains("found=false"))
        #expect(outcome.rendered.contains("printed nowhere in this replay"))
    }

    /// Whitespace is collapsed before matching, and the `[status]` footers are
    /// not searched. Both are about what an excerpt *is*: a quotation lifted out
    /// of a report, re-wrapped on the way, of prose the suite sees without a
    /// footer in it. Requiring the bytes to line up would refuse true claims for
    /// reasons that have nothing to do with the game — and searching the footer
    /// would confirm claims about the harness's own scaffolding.
    @Test func matchingIgnoresWrappingAndNeverSearchesTheFooter() async throws {
        let prepared = try PreparedGame(OperaHouse())
        let rewrapped = try await PlaytestReplay.run(
            prepared: prepared, commands: ["west", "put cloak on hook"], seed: 0,
            expect: "You put the velvet cloak\n     on the small\tbrass hook.")
        #expect(rewrapped.verdict?.found == true)

        let footer = try await PlaytestReplay.run(
            prepared: prepared, commands: ["west"], seed: 0, expect: "room=Cloakroom")
        #expect(footer.verdict?.found == false)
    }

    /// The opening is line 0, numbered the way a session numbers it, so a
    /// verdict and a `recall` agree about what turn 1 is. An empty command list
    /// is legal for exactly this: a claim about the game's first words needs no
    /// commands to check.
    @Test func aClaimAboutTheOpeningIsATurnZeroVerdict() async throws {
        let outcome = try await PlaytestReplay.run(
            prepared: try PreparedGame(OperaHouse()), commands: [], seed: 0,
            expect: "Foyer of the Opera House")

        let verdict = try #require(outcome.verdict)
        #expect(verdict.found)
        #expect(verdict.turn == 0)
        #expect(verdict.command == nil)
        #expect(outcome.lines == 0)
    }

    // MARK: - It is the REPL

    /// **The third driver, pinned to the other two.** A replay's transcript is
    /// byte-for-byte a session's for the same commands at the same seed — which
    /// it is by construction, because it hands the list to a real `REPL` through
    /// `ScriptedIOHandler` and reads the result off the handler.
    ///
    /// Asserted anyway, because "by construction" is a claim about today's code
    /// and this is the property the whole harness is sold on. If a verifier's
    /// replay and a tester's session could differ by one byte, every excerpt
    /// check between them would be a guess.
    @Test func aReplayIsByteIdenticalToASession() async throws {
        let commands = ["look", "// nothing here but the cloak", "x cloak", "west", "frotz"]
        let session = try await sessions(OperaHouse()).open(label: "compare", seed: 0)
        _ = try await session.opening()
        _ = try await session.move(commands: commands, allowPrompts: false)

        let outcome = try await PlaytestReplay.run(
            prepared: try PreparedGame(OperaHouse()), commands: commands, seed: 0, expect: nil)

        #expect(outcome.transcript == (try text(at: session.transcriptURL)))
        #expect(outcome.rendered.contains("[playtest] replay lines=5 finished=false"))
    }

    /// The seed a finding names is the seed the replay pins, and the same seed
    /// twice is the same transcript twice.
    ///
    /// Checked against a *session* opened at the same non-zero seed rather than
    /// against a second replay alone: that is the pairing a verifier actually
    /// makes — a tester's session at seed 7 and a verifier's replay of its
    /// command list at seed 7 — and it is the one that would break if the
    /// argument were dropped on the way to `GameWorld`.
    @Test func theSeedIsTheOneTheFindingNames() async throws {
        let commands = ["look", "beckon", "wait"]
        let session = try await sessions(MorgueGame()).open(label: "seeded", seed: 7)
        _ = try await session.opening()
        _ = try await session.move(commands: commands, allowPrompts: true)

        let prepared = try PreparedGame(MorgueGame())
        let seven = try await PlaytestReplay.run(
            prepared: prepared, commands: commands, seed: 7, expect: nil)
        let again = try await PlaytestReplay.run(
            prepared: prepared, commands: commands, seed: 7, expect: nil)

        #expect(seven.transcript == (try text(at: session.transcriptURL)))
        #expect(seven.transcript == again.transcript)
    }

    /// It ends when the game does, and says so — a fact no reader could recover
    /// from the transcript, since a list that ran out and a list cut short by a
    /// death both simply stop.
    @Test func aReplayReportsThatTheGameEnded() async throws {
        let outcome = try await PlaytestReplay.run(
            prepared: try PreparedGame(OperaHouse()), commands: ["quit", "look"], seed: 0,
            expect: nil)
        #expect(outcome.finished)
    }

    /// Nothing a replay does reaches a session — not the session's world, not
    /// its queue, not its files. Two verifiers checking two findings while a
    /// tester plays is the ordinary case, and the reason `replay` is classified
    /// as a reader.
    @Test func aReplayLeavesEverySessionAlone() async throws {
        let session = try await sessions(AviaryGame()).open(
            label: "undisturbed", seed: 0, role: .explorer)
        _ = try await session.opening()
        _ = try await session.move(commands: ["x oak"], allowPrompts: false)
        let before = try await session.coverage(limit: 200).items.map(\.id).sorted()
        let recorded = try text(at: session.transcriptURL)

        _ = try await PlaytestReplay.run(
            prepared: try PreparedGame(AviaryGame()),
            commands: ["x oak", "x nest", "take pebble", "north", "south"],
            seed: 0, expect: nil)

        #expect(try await session.coverage(limit: 200).items.map(\.id).sorted() == before)
        #expect(try text(at: session.transcriptURL) == recorded)
        #expect(try text(at: session.commandsURL) == "x oak\n")
    }

    // MARK: - The receipt

    /// A replay leaves a probe directory, and the path is in the first line of
    /// what the caller reads.
    ///
    /// The 2026-08-17 round is why. Three charters reported load-bearing frames
    /// read from free replays, and one whole ending branch that the report
    /// asserts appears in **no file in the tree** — a claim nobody who was not
    /// there can check, which is exactly what the cite-the-probe rule exists to
    /// prevent. The files are the fix and the path on the header line is what
    /// makes citing it the path of least resistance.
    @Test func aReplayLeavesAProbeDirectoryAndSaysWhere() async throws {
        let (root, tools) = try table(OperaHouse())
        let replay = try #require(tools.first { $0.name == "replay" })

        let result = try await replay.handler(["commands": ["look", "west"]])

        let probe = root.appendingPathComponent(PlaytestSessions.replayLabel)
            .appendingPathComponent("probe-001")
        let transcript = probe.appendingPathComponent("transcript.txt")
        #expect(result.text.hasPrefix("[playtest] replay lines=2 finished=false transcript="))
        #expect(result.text.contains(transcript.path))
        let structured = try #require(result.structured)
        #expect(structured["transcriptPath"]?.stringValue == transcript.path)
        #expect(
            structured["commandsPath"]?.stringValue
                == probe.appendingPathComponent("commands.txt").path)
        #expect(try text(at: transcript).contains("Cloakroom"))
        #expect(try text(at: probe.appendingPathComponent("commands.txt")) == "look\nwest\n")
        #expect(
            try text(at: probe.appendingPathComponent("summary.txt"))
                .hasPrefix("[playtest] replay seed=0 commands=2\n"))
    }

    /// The file a finding cites replays to the transcript beside it, byte for
    /// byte.
    ///
    /// This is ``aReplayIsByteIdenticalToASession`` applied to the *written*
    /// evidence rather than to the value in memory, and it is the reason the
    /// seed is recorded in `summary.txt` rather than as a comment at the head of
    /// the command list: `ScriptedIOHandler` echoes every line it is fed,
    /// comments included, so a list carrying its own header would not reproduce
    /// the transcript filed next to it.
    @Test func theWrittenCommandListReplaysToTheWrittenTranscript() async throws {
        let (root, tools) = try table(OperaHouse())
        let replay = try #require(tools.first { $0.name == "replay" })

        _ = try await replay.handler(
            ["commands": ["look", "// the cloak is the point", "x cloak", "west"]])

        let probe = root.appendingPathComponent(PlaytestSessions.replayLabel)
            .appendingPathComponent("probe-001")
        let commands = try text(at: probe.appendingPathComponent("commands.txt"))
            .split(separator: "\n", omittingEmptySubsequences: false)
            .dropLast()
            .map(String.init)

        let again = try await PlaytestReplay.run(
            prepared: try PreparedGame(OperaHouse()), commands: commands, seed: 0, expect: nil)
        #expect(again.transcript == (try text(at: probe.appendingPathComponent("transcript.txt"))))
    }

    /// Two replays cannot take the same probe, and a replay cannot land in a
    /// tester's label.
    ///
    /// The leading dot is the whole guard: `isPlainName` refuses a label that
    /// starts with one, so no session can be opened into `.replays` and no
    /// collision check is needed to say so.
    @Test func replayProbesAreAllocatedApartFromEverySession() async throws {
        let (root, tools) = try table(OperaHouse())
        let replay = try #require(tools.first { $0.name == "replay" })
        let open = try #require(tools.first { $0.name == "open" })

        _ = try await open.handler(["label": "tester", "seed": 0])
        _ = try await replay.handler(["commands": ["look"]])
        _ = try await replay.handler(["commands": ["west"]])

        let replays = root.appendingPathComponent(PlaytestSessions.replayLabel)
        #expect(
            try text(at: replays.appendingPathComponent("probe-001/commands.txt")) == "look\n")
        #expect(
            try text(at: replays.appendingPathComponent("probe-002/commands.txt")) == "west\n")
        // The tester's own probe-001 is a different directory entirely, and the
        // round's `<game>-r*-session-*` glob reaches neither of the replays.
        #expect(
            FileManager.default.fileExists(
                atPath: root.appendingPathComponent("tester/probe-001").path))
        await #expect(throws: PlaytestError.self) {
            _ = try await open.handler(
                ["label": .string(PlaytestSessions.replayLabel), "seed": 0])
        }
    }

    /// The two refusals, each of which runs nothing.
    ///
    /// `script` matters more than it looks: it would start a second recording in
    /// the game's own transcripts directory, outside this harness entirely, and
    /// the file nobody knows about is the one a finding ends up citing.
    @Test func aReplayRefusesAScriptLineAndAnEndlessList() async throws {
        let prepared = try PreparedGame(OperaHouse())

        let scripted = await #expect(throws: PlaytestError.self) {
            try await PlaytestReplay.run(
                prepared: prepared, commands: ["look", "script mine"], seed: 0, expect: nil)
        }
        #expect(scripted?.description.contains("transcript command") == true)
        #expect(scripted?.description.contains("nothing ran") == true)

        let endless = await #expect(throws: PlaytestError.self) {
            try await PlaytestReplay.run(
                prepared: prepared,
                commands: Array(repeating: "look", count: PlaytestReplay.commandLimit + 1),
                seed: 0, expect: nil)
        }
        #expect(endless?.description.contains("runs at most") == true)
    }

    // MARK: - Over the wire

    /// `replay` end to end, in both channels, with and without a claim to judge.
    @Test func theReplayToolWorksOverTheProtocol() async throws {
        let server = try server(OperaHouse())

        func call(_ arguments: String) async throws -> JSONValue {
            try JSONValue(
                text: try #require(
                    await server.handle(
                        line: """
                            {"jsonrpc":"2.0","id":1,"method":"tools/call","params":\
                            {"name":"replay","arguments":\(arguments)}}
                            """)))
        }

        let judged = try await call(
            #"{"commands":["west","put cloak on hook"],"seed":0,"#
                + #""expect":"You put the velvet cloak on the small brass hook."}"#)
        #expect(judged["result"]?["isError"] == .bool(false))
        let verdict = try #require(judged["result"]?["structuredContent"])
        #expect(verdict["found"] == .bool(true))
        #expect(verdict["turn"]?.intValue == 2)
        #expect(verdict["room"]?.stringValue == "Cloakroom")
        #expect(verdict["actualContext"]?.stringValue?.contains("> put cloak on hook") == true)

        let read = try await call(#"{"commands":["look"]}"#)
        let whole = try #require(read["result"]?["structuredContent"]?["transcript"]?.stringValue)
        #expect(whole.contains("Foyer of the Opera House"))
        #expect(read["result"]?["structuredContent"]?["found"] == nil)

        // A refusal is a tool error the agent can read, never a protocol error.
        let refused = try await call(#"{"commands":["script"]}"#)
        #expect(refused["error"] == nil)
        #expect(refused["result"]?["isError"] == .bool(true))
    }

    // MARK: - Vocabulary is the answer key

    /// `vocabulary` is oracle data and gated exactly like `survey`, and this is
    /// the leak that matters most: a tester told which words the parser knows can
    /// never discover that a room description prints a noun with nothing behind
    /// it, which is the commonest defect class every round finds. The Yard says
    /// *grout* and no item answers to it — a fact this tool would hand over for
    /// free.
    @Test func vocabularyIsRefusedByRoleAndAllowedForAHuman() async throws {
        let server = try server(AviaryGame())

        func open(_ label: String, role: String) async throws -> String {
            let response = try JSONValue(
                text: try #require(
                    await server.handle(
                        line: """
                            {"jsonrpc":"2.0","id":1,"method":"tools/call","params":\
                            {"name":"open","arguments":{"label":"\(label)",\
                            "role":"\(role)"}}}
                            """)))
            return try #require(
                response["result"]?["structuredContent"]?["session"]?.stringValue)
        }

        func vocabulary(_ id: String, _ words: String) async throws -> JSONValue {
            try JSONValue(
                text: try #require(
                    await server.handle(
                        line: """
                            {"jsonrpc":"2.0","id":2,"method":"tools/call","params":\
                            {"name":"vocabulary","arguments":{"session":"\(id)",\
                            "words":\(words)}}}
                            """)))
        }

        let blind = try await open("blind", role: "explorer")
        let refused = try await vocabulary(blind, #"["grout"]"#)
        #expect(refused["error"] == nil)
        #expect(refused["result"]?["isError"] == .bool(true))
        let complaint = try #require(
            refused["result"]?["content"]?.arrayValue?.first?["text"]?.stringValue)
        #expect(complaint.contains("oracle data"))
        #expect(complaint.contains("explorer"))
        // The refusal must not answer the question it refused.
        #expect(!complaint.contains("NOT KNOWN"))

        let author = try await open("author", role: "unrestricted")
        let allowed = try await vocabulary(author, #"["oak","nest","grout","brickwork"]"#)
        #expect(allowed["result"]?["isError"] == .bool(false))
        let answers = try #require(allowed["result"]?["structuredContent"])
        #expect(
            answers["unknown"]?.arrayValue?.compactMap(\.stringValue).sorted()
                == ["brickwork", "grout"])
        let known = try #require(answers["words"]?.arrayValue)
        #expect(known.count == 4)
        #expect(known.first?["word"]?.stringValue == "oak")
        #expect(known.first?["known"] == .bool(true))
        // Both channels say the same thing, and the prose one is readable.
        let listing = try #require(
            allowed["result"]?["content"]?.arrayValue?.first?["text"]?.stringValue)
        #expect(listing.contains("oak: known"))
        #expect(listing.contains("grout: NOT KNOWN"))
    }

    /// A word is split the way the parser splits it, so a caller handing over
    /// `master's` gets the answer for the token the parser would make of it
    /// rather than a guaranteed no. One splitter, both sides —
    /// `Vocabulary.words(in:)`.
    @Test func aWordIsAskedAsTheParserWouldTokenizeIt() throws {
        let definition = try PreparedGame(AviaryGame()).definition
        #expect(definition.knows(["pale pebble"]).first?.known == true)
        #expect(definition.knows(["oak's"]).first?.known == true)
        #expect(definition.knows([""]).first?.known == false)
        #expect(definition.knows(["!!!"]).first?.known == false)
    }
}
