import Foundation
import Testing

@testable import CloakOfDarkness
@testable import Gnusto

/// The curiosity engine: the queue a session builds out of what the game showed
/// it, the firewall that keeps the answer key on the other side of a role, and
/// the two tools that write a tester's own words into the evidence.
///
/// Two of these tests carry more weight than the rest.
/// ``theQueueNamesNothingTheSessionHasNotPrinted`` is the firewall, asserted
/// against the definition the ledger is forbidden to read — it is the only
/// mechanical check that the two channels have not been crossed, and crossing
/// them would destroy two whole defect classes silently, with every test still
/// green. ``takingSomethingPutsLookingAtItBackOnTheQueue`` is the egg: the one
/// measurement this stage exists to move.
///
/// Exact-set assertions rather than counts wherever the set is small enough to
/// write down. Coverage arithmetic is the part of this server that can be subtly
/// wrong while looking right, and a count passes while naming the wrong things.
struct PlaytestCoverageTests {
    // MARK: - Harness

    /// A session registry writing into a directory of its own, on the same
    /// `GNUSTO_PLAYTEST_DIR` precedent as `PlaytestSessionTests`: a test must
    /// never write into the developer's real `.context/playtest`.
    private func sessions(_ game: some Game) throws -> PlaytestSessions {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        return PlaytestSessions(
            prepared: try PreparedGame(game),
            environment: ["GNUSTO_PLAYTEST_DIR": root.path])
    }

    /// An opened, booted session.
    private func session(
        _ game: some Game, role: PlaytestRole = .explorer,
        divergence: DivergencePolicy = .commit
    ) async throws -> PlaytestSession {
        let session = try await sessions(game).open(
            label: "queue", seed: 0, role: role, divergence: divergence)
        _ = try await session.opening()
        return session
    }

    /// The ids of a session's open queue.
    private func ids(_ session: PlaytestSession, limit: Int = 200) async throws -> Set<String> {
        Set(try await session.coverage(limit: limit).items.map(\.id))
    }

    /// A file's contents as text.
    private func text(at url: URL) throws -> String {
        String(decoding: try Data(contentsOf: url), as: UTF8.self)
    }

    // MARK: - The firewall

    /// **The firewall test.** A fresh explorer's queue, and the report it gets
    /// when it stops, name nothing the session has not itself printed.
    ///
    /// Asserted against the very `GameDefinition` the ledger is forbidden to
    /// read, so the test knows the answers and checks that the session does
    /// not: the two rooms no exit has been walked to, the two timers nothing has
    /// fired, and every item word the prose has not used. Crossing the two
    /// channels would leave every other test in this suite green while
    /// destroying two defect classes by construction — a tester told the room
    /// roster cannot *discover* an unreachable room, and one told the vocabulary
    /// cannot discover that a printed noun has nothing behind it.
    ///
    /// One carve-out, and it is not a leak: the standard verb repertoire.
    /// `take`, `look in`, `climb` and the rest are the harness's own knowledge
    /// of English, identical for every game ever written with this engine, so
    /// offering them says nothing whatever about *this* one. What is filtered
    /// against — the words the game used about a thing — is printed text.
    @Test func theQueueNamesNothingTheSessionHasNotPrinted() async throws {
        let definition = try PreparedGame(AviaryGame()).definition
        let session = try await session(AviaryGame())
        let printed = Set(CoverageLedger.words(in: try text(at: session.transcriptURL)))

        var oracle: Set<String> = []
        for room in definition.locations.values {
            oracle.formUnion(CoverageLedger.words(in: room.name ?? ""))
        }
        oracle.formUnion(definition.timers.keys.flatMap { CoverageLedger.words(in: $0) })
        for item in definition.items.values {
            oracle.formUnion(CoverageLedger.words(in: item.name ?? ""))
            oracle.formUnion(item.adjectives.flatMap { CoverageLedger.words(in: $0) })
            oracle.formUnion(item.synonyms.flatMap { CoverageLedger.words(in: $0) })
        }
        let secrets = oracle.subtracting(printed)
        // The fixture has to have secrets, or this test passes by having nothing
        // to check. These are the ones it is built to keep.
        #expect(secrets.isSuperset(of: ["shed", "lane", "bench", "bell", "wind", "tree"]))

        let coverage = try await session.coverage(limit: 200)
        let closing = try await session.finish(
            summary: "only had a look at the yard", leaving: nil, limit: 200)
        let said = Set(
            CoverageLedger.words(in: coverage.rendered(session: session.id) + closing.message))
        #expect(said.isDisjoint(with: secrets))

        // And nothing else off the definition leaked either: not the score, not
        // the count of anything the session cannot see.
        #expect(!coverage.rendered(session: session.id).contains("maxScore"))
        #expect(closing.signals.roomsVisited == 1)
    }

    /// An item is named by the word the tester typed, never by the entity the
    /// parser bound it to.
    ///
    /// Found by running the real thing against Dungeon: `take egg` raised
    /// `restate:DungeonAboveGround.egg`, and that is a bundle type and a
    /// property name — source, straight through the firewall and into an id the
    /// tester reads. A namespaced `EntityID` always carries a dot and a
    /// pasteable command never does, so a dot anywhere in an id or a `how` is
    /// the whole regression.
    @Test func noItemIsNamedAfterAnEntityRatherThanAWord() async throws {
        let session = try await session(AviaryGame())
        _ = try await session.move(
            commands: ["x nest", "take pebble", "x oak", "take all", "take it"],
            allowPrompts: false)

        for item in try await session.coverage(limit: 200).items {
            #expect(!item.id.contains("."), "item id \(item.id) looks like an EntityID")
            #expect(!item.how.contains("."), "how \(item.how) is not a command")
        }
        // A line that bound something without naming it introduces nothing: the
        // fallback that would have used the entity id is gone, not softened.
        #expect(try await ids(session).allSatisfy { !$0.contains(":it:") })
    }

    /// `survey` is the answer key, so a play-testing role is refused it and a
    /// person driving their own game is not. Over the wire, because the schema
    /// and the handler are what a client actually meets.
    @Test func surveyIsRefusedByRoleAndAllowedForAHuman() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let server = MCPServer(
            name: "gnusto-playtest", version: "test", instructions: nil,
            tools: PlaytestTools.table(
                for: try PreparedGame(AviaryGame()),
                environment: ["GNUSTO_PLAYTEST_DIR": root.path]))

        func open(_ label: String, role: String) async throws -> String {
            let response = try JSONValue(
                text: try #require(
                    await server.handle(
                        line: """
                            {"jsonrpc":"2.0","id":1,"method":"tools/call","params":\
                            {"name":"open","arguments":{"label":"\(label)",\
                            "role":"\(role)"}}}
                            """)))
            #expect(response["result"]?["isError"] == .bool(false))
            #expect(response["result"]?["structuredContent"]?["role"]?.stringValue == role)
            return try #require(
                response["result"]?["structuredContent"]?["session"]?.stringValue)
        }

        func survey(_ id: String) async throws -> JSONValue {
            try JSONValue(
                text: try #require(
                    await server.handle(
                        line: """
                            {"jsonrpc":"2.0","id":2,"method":"tools/call","params":\
                            {"name":"survey","arguments":{"session":"\(id)"}}}
                            """)))
        }

        let blind = try await open("blind", role: "explorer")
        let refused = try await survey(blind)
        // A tool error the agent can read, never a protocol error and never a
        // trap.
        #expect(refused["error"] == nil)
        #expect(refused["result"]?["isError"] == .bool(true))
        let complaint = try #require(
            refused["result"]?["content"]?.arrayValue?.first?["text"]?.stringValue)
        #expect(complaint.contains("oracle data"))
        #expect(complaint.contains("explorer"))
        #expect(complaint.contains("coverage"))
        // The refusal must not itself leak the thing it refuses.
        #expect(!complaint.contains("Shed"))

        let author = try await open("author", role: "unrestricted")
        let allowed = try await survey(author)
        #expect(allowed["result"]?["isError"] == .bool(false))
        let rooms = try #require(
            allowed["result"]?["structuredContent"]?["rooms"]?.arrayValue)
        #expect(rooms.compactMap { $0["name"]?.stringValue }.sorted() == ["Lane", "Shed", "Yard"])
    }

    /// Every play-testing role plays blind; the default does not. Written as a
    /// sweep over `allCases` so a role added later has to decide.
    @Test func onlyTheHumanRoleSeesTheOracle() {
        #expect(
            Set(PlaytestRole.allCases.filter(\.seesOracleData)) == [.unrestricted])
        #expect(PlaytestRole(rawValue: "wrong-footer") == .wrongFooter)
    }

    /// A role nobody has heard of is refused rather than guessed at. Either
    /// guess is wrong in a way nobody would notice: down, it silently blinds a
    /// game author; up, it silently hands a tester the answer key and
    /// invalidates the round it was part of.
    @Test func anUnknownRoleIsRefusedRatherThanGuessedAt() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let server = MCPServer(
            name: "gnusto-playtest", version: "test", instructions: nil,
            tools: PlaytestTools.table(
                for: try PreparedGame(AviaryGame()),
                environment: ["GNUSTO_PLAYTEST_DIR": root.path]))
        let response = try JSONValue(
            text: try #require(
                await server.handle(
                    line: """
                        {"jsonrpc":"2.0","id":1,"method":"tools/call","params":\
                        {"name":"open","arguments":{"label":"typo","role":"explore"}}}
                        """)))
        #expect(response["result"]?["isError"] == .bool(true))
        #expect(
            response["result"]?["content"]?.arrayValue?.first?["text"]?.stringValue?
                .contains("wrong-footer") == true)
    }

    // MARK: - The opening queue

    /// The queue exists before the first move, and it is exactly the loose ends
    /// of the opening: the two directions the Yard's description named, and the
    /// head noun of every noun phrase in it.
    ///
    /// An exact set, so both failure directions are caught: a noun the
    /// extraction stops finding, and an adjective or a verb it starts finding.
    /// The second is the one that matters — `x walled`, `x crumbling`, `x
    /// stands` are turns spent on grammar, and a queue that spends them teaches
    /// the tester that the queue is noise.
    @Test func theOpeningQueueIsExactlyWhatTheOpeningPrinted() async throws {
        let session = try await session(AviaryGame())

        #expect(
            try await ids(session) == [
                "exit:north@Yard", "exit:south@Yard",
                "noun:yard@Yard", "noun:brickwork@Yard", "noun:grout@Yard",
                "noun:bricks@Yard", "noun:oak@Yard", "noun:wall@Yard",
                "noun:gap@Yard", "noun:nest@Yard", "noun:pebble@Yard",
            ])
    }

    /// The queue comes back with the opening, so the tester plans from it rather
    /// than forming a plan and then being told what it missed.
    @Test func openHandsBackTheQueueWithTheOpeningText() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let server = MCPServer(
            name: "gnusto-playtest", version: "test", instructions: nil,
            tools: PlaytestTools.table(
                for: try PreparedGame(AviaryGame()),
                environment: ["GNUSTO_PLAYTEST_DIR": root.path]))
        let response = try JSONValue(
            text: try #require(
                await server.handle(
                    line: """
                        {"jsonrpc":"2.0","id":1,"method":"tools/call","params":\
                        {"name":"open","arguments":{"label":"planning","role":"explorer"}}}
                        """)))
        let opened = try #require(response["result"]?["structuredContent"])
        #expect(opened["open"]?.intValue == 11)
        let queue = try #require(opened["queue"]?.arrayValue)
        #expect(queue.count == 11)  // fewer than the limit: that is all there is yet
        let first = try #require(queue.first)
        #expect(first["how"]?.stringValue?.isEmpty == false)
        #expect(first["closedByLooking"] == .bool(true))
    }

    // MARK: - Nouns

    /// A noun the prose printed with nothing behind it is discoverable, and only
    /// discoverable this way.
    ///
    /// This is the argument for the firewall reduced to one assertion. The Yard
    /// says *grout*; no item answers to the word; a tester handed the vocabulary
    /// would never type it, and one going by the prose types it and gets *I
    /// don't know the word "grout"* — which is a defect in the room description,
    /// not in the tester.
    @Test func aPrintedNounWithNothingBehindItReachesTheQueue() async throws {
        let session = try await session(AviaryGame())
        #expect(try await ids(session).contains("noun:grout@Yard"))

        let report = try await session.move(commands: ["x grout"], allowPrompts: false)
        #expect(report.contains("don't know the word \"grout\""))
        // Named, so it is no longer unfollowed — the tester's finding, not the
        // queue's, from here on.
        #expect(!(try await ids(session).contains("noun:grout@Yard")))
    }

    /// The frontier grows as it is read: a noun an examine printed enters the
    /// queue at once, and the object it belonged to brings its own repertoire.
    @Test func examiningSomethingAddsWhatItsDescriptionNamed() async throws {
        let session = try await session(AviaryGame())
        _ = try await session.move(commands: ["x oak"], allowPrompts: false)

        let open = try await ids(session)
        // The oak's description names a crook and a branch, and neither was in
        // the room's own paragraph.
        #expect(open.contains("noun:crook@Yard"))
        #expect(open.contains("noun:branch@Yard"))
        #expect(!open.contains("noun:oak@Yard"))
    }

    /// A parse failure is the *engine* talking, not the game, so its words are
    /// not things to examine. Without this, `I don't know the word "grout"`
    /// queues `x word`.
    @Test func aParseFailuresOwnWordsDoNotBecomeObligations() async throws {
        let session = try await session(AviaryGame())
        _ = try await session.move(commands: ["frotz"], allowPrompts: false)
        #expect(try await ids(session).allSatisfy { !$0.contains("word") })
    }

    // MARK: - Exits

    /// A direction a room described and nobody took is an item, and going that
    /// way closes it. The Lane names no way out at all, which is why nothing
    /// there enters the queue — and why "the tester never found the Shed" can be
    /// reported as a fact about discoverability rather than a coverage gap it
    /// was handed the answer to.
    @Test func aDirectionTheProseNamedIsAnItemUntilItIsTaken() async throws {
        let session = try await session(AviaryGame())
        #expect(try await ids(session).contains("exit:south@Yard"))

        _ = try await session.move(commands: ["south"], allowPrompts: false)
        let open = try await ids(session)
        #expect(!open.contains("exit:south@Yard"))
        #expect(open.contains("exit:north@Yard"))
        #expect(open.contains("noun:lane@Lane"))
        #expect(open.allSatisfy { !$0.hasPrefix("exit:") || $0.hasSuffix("@Yard") })
    }

    /// One step of routing, from the map the session has walked itself. An item
    /// in the room next door is still a command to paste, because the tester has
    /// already been through that door once and the server watched them do it.
    @Test func anItemNextDoorCarriesTheStepThatGetsThere() async throws {
        let session = try await session(AviaryGame())
        _ = try await session.move(commands: ["south", "north"], allowPrompts: false)

        let lane = try #require(
            try await session.coverage(limit: 200).items.first { $0.id == "noun:lane@Lane" })
        #expect(lane.how == "south, then: x lane")
    }

    // MARK: - The interaction matrix

    /// The repertoire is filtered to what the game said about the thing, and
    /// nothing else. The oak reads as climbable and burnable because its
    /// description says *climb* and *branch*; the pebble does not, because
    /// nothing about it does.
    @Test func theInteractionMatrixFitsWhatWasDescribed() async throws {
        let session = try await session(AviaryGame())
        _ = try await session.move(commands: ["x oak", "x pebble"], allowPrompts: false)

        let open = try await ids(session)
        #expect(
            Set(open.filter { $0.hasPrefix("object:oak:") }) == [
                "object:oak:take", "object:oak:touch", "object:oak:lookIn",
                "object:oak:climb", "object:oak:burn",
            ])
        #expect(!open.contains("object:pebble:climb"))
        #expect(!open.contains("object:pebble:burn"))
        // And a cell closes when the verb is tried, whatever the game says back.
        _ = try await session.move(commands: ["climb oak"], allowPrompts: false)
        #expect(!(try await ids(session).contains("object:oak:climb")))
    }

    /// A cell closes by *intent*, not by spelling, so the three ways to say
    /// "look at" count once — and `search X`, which the engine reads as
    /// ``Intent/lookIn``, closes the `look in` cell rather than sitting beside
    /// it asking for the same turn twice.
    @Test func aMatrixCellClosesByIntentRatherThanBySpelling() async throws {
        let session = try await session(AviaryGame())
        _ = try await session.move(
            commands: ["examine nest", "search nest"], allowPrompts: false)

        let open = try await ids(session)
        #expect(!open.contains("object:nest:examine"))
        #expect(!open.contains("object:nest:lookIn"))
    }

    /// Carrying something unlocks the cells that need it, and putting it down
    /// takes them away again. `drop` before you have the thing is a turn spent
    /// on a refusal.
    @Test func holdingSomethingUnlocksTheCellsThatNeedIt() async throws {
        let session = try await session(AviaryGame())
        _ = try await session.move(commands: ["x nest", "x pebble"], allowPrompts: false)
        #expect(!(try await ids(session).contains("object:pebble:drop")))

        _ = try await session.move(commands: ["take pebble"], allowPrompts: false)
        #expect(try await ids(session).contains("object:pebble:drop"))
    }

    // MARK: - Divergence

    /// **The fork.** `commit` is offered the irreversible move; `abstain` is not
    /// asked for it at all.
    ///
    /// The oak's description says *branch*, which is enough for the repertoire
    /// to offer `burn` — and burning is the shape of thing a whole round can
    /// lose by accident, because every tester left to itself burns it. An
    /// `abstain` session does not carry that as an obligation it is forbidden to
    /// discharge; the item is closed on sight, and the fork record says it was
    /// left rather than taken.
    @Test func abstainIsNotEvenAskedForTheIrreversibleMove() async throws {
        let committed = try await session(AviaryGame(), divergence: .commit)
        _ = try await committed.move(commands: ["x oak"], allowPrompts: false)
        #expect(try await ids(committed).contains("object:oak:burn"))

        let abstained = try await session(AviaryGame(), divergence: .abstain)
        _ = try await abstained.move(commands: ["x oak"], allowPrompts: false)
        #expect(!(try await ids(abstained).contains("object:oak:burn")))

        // Closed, but recorded: a fork nobody was offered and a fork somebody
        // was told to leave are different gaps, and only the ledger knows which.
        let closing = try await abstained.finish(
            summary: "left it as I found it", leaving: nil, limit: 200)
        let fork = try #require(closing.forks.first { $0.id == "object:oak:burn" })
        #expect(fork.taken == false)
        #expect(fork.command == "burn oak")
    }

    /// A fork the session actually took comes back `taken`.
    ///
    /// Which is the half that makes the round's arithmetic work: a fork reported
    /// `taken: false` by *every* tester is a branch nothing tested, and that
    /// claim is only worth making if a taken one says so.
    @Test func aForkTheSessionTookIsReportedTaken() async throws {
        let session = try await session(AviaryGame(), divergence: .commit)
        _ = try await session.move(commands: ["x oak", "burn oak"], allowPrompts: false)

        let closing = try await session.finish(
            summary: "burned it", leaving: nil, limit: 200)
        let fork = try #require(closing.forks.first { $0.id == "object:oak:burn" })
        #expect(fork.taken)
    }

    /// `defer` sinks a fork below everything, including items in other rooms.
    ///
    /// "Come back to it last" means last in the session, not last in the room —
    /// so the check is ahead of room proximity, and this asserts the strong
    /// version: with a queue holding items from two rooms, the fork is still
    /// bottom.
    @Test func deferSinksAForkBelowEvenAnotherRoomsWork() async throws {
        let session = try await session(AviaryGame(), divergence: .defer)
        _ = try await session.move(
            commands: ["x oak", "north", "x bench"], allowPrompts: false)

        let queue = try await session.coverage(limit: 200).items
        let burn = try #require(queue.firstIndex { $0.id == "object:oak:burn" })
        #expect(burn == queue.count - 1)
        // And it really is competing against work elsewhere, or the assertion
        // above would hold for a one-room queue by default.
        #expect(Set(queue.map(\.room)).count > 1)
    }

    /// The default policy leaves the queue exactly as it was.
    ///
    /// The ranking is measured, and every recorded number was taken against the
    /// `commit` ordering — so the fork rule has to be inert unless a round asks
    /// for it. Same commands, two sessions, one of them saying nothing about
    /// divergence: the same items in the same order.
    @Test func theDefaultPolicyChangesNothingAboutTheQueue() async throws {
        let quiet = try await sessions(AviaryGame()).open(label: "queue", seed: 0, role: .explorer)
        _ = try await quiet.opening()
        _ = try await quiet.move(commands: ["x oak", "x nest"], allowPrompts: false)

        let asked = try await session(AviaryGame(), divergence: .commit)
        _ = try await asked.move(commands: ["x oak", "x nest"], allowPrompts: false)

        let left = try await quiet.coverage(limit: 200).items.map(\.id)
        let right = try await asked.coverage(limit: 200).items.map(\.id)
        #expect(left == right)
        #expect(left.contains("object:oak:burn"))
    }

    /// Over the wire: a policy comes back with the instruction that goes with
    /// it, and a policy nobody has heard of is refused rather than guessed at.
    ///
    /// The refusal matters more than it looks. A round hands these out so two
    /// testers cover both sides of a fork between them; a typo quietly
    /// downgraded to `commit` would leave the report claiming a branch was left
    /// alone when in fact every tester took it.
    @Test func aDivergencePolicyArrivesWithItsInstructionOrIsRefused() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let server = MCPServer(
            name: "gnusto-playtest", version: "test", instructions: nil,
            tools: PlaytestTools.table(
                for: try PreparedGame(AviaryGame()),
                environment: ["GNUSTO_PLAYTEST_DIR": root.path]))

        func open(_ label: String, divergence: String) async throws -> JSONValue {
            try JSONValue(
                text: try #require(
                    await server.handle(
                        line: """
                            {"jsonrpc":"2.0","id":1,"method":"tools/call","params":\
                            {"name":"open","arguments":{"label":"\(label)",\
                            "role":"explorer","divergence":"\(divergence)"}}}
                            """)))
        }

        let abstaining = try await open("abstaining", divergence: "abstain")
        let structured = try #require(abstaining["result"]?["structuredContent"])
        #expect(structured["divergence"]?.stringValue == "abstain")
        let instruction = try #require(structured["instruction"]?.stringValue)
        #expect(instruction.contains("leave it as you"))
        #expect(instruction.contains("already off your queue"))

        let nonsense = try await open("nonsense", divergence: "whatever")
        #expect(nonsense["error"] == nil)
        #expect(nonsense["result"]?["isError"] == .bool(true))
        let complaint = try #require(
            nonsense["result"]?["content"]?.arrayValue?.first?["text"]?.stringValue)
        #expect(complaint.contains("commit"))
        #expect(complaint.contains("abstain"))
        #expect(complaint.contains("defer"))
    }

    /// An abstain session that takes the fork anyway is recorded as having
    /// taken it.
    ///
    /// The policy is an instruction and not a lock — a tester that reaches a
    /// fork while doing something else has discovered something, and the ledger
    /// records rather than forbids it. But then the record has to be *true*: a
    /// round reads these to decide which branches went untested, so a fork this
    /// session actually took must never come back as one it left alone.
    @Test func anAbstainSessionThatTakesTheForkAnywaySaysSo() async throws {
        let session = try await session(AviaryGame(), divergence: .abstain)
        _ = try await session.move(commands: ["x oak"], allowPrompts: false)
        #expect(!(try await ids(session).contains("object:oak:burn")))

        _ = try await session.move(commands: ["burn oak"], allowPrompts: false)

        let closing = try await session.finish(
            summary: "burned it despite orders", leaving: nil, limit: 200)
        let fork = try #require(closing.forks.first { $0.id == "object:oak:burn" })
        #expect(fork.taken)
    }

    // MARK: - The egg

    /// **The egg.** Anything that changes a thing puts looking at it back on the
    /// queue, and the second look is what reads the stale sentence.
    ///
    /// The fixture's pebble describes itself as *tucked into the nest* whatever
    /// has happened to it, which is the two-channel defect in miniature. A
    /// tester that examines it, takes it and walks away never sees the lie; the
    /// baseline measured exactly that, twice on Fulminate against fifteen on
    /// Dungeon. `restate:` is the difference, so this test asserts the whole
    /// arc: raised by the take, closed by the look, and the look prints the
    /// sentence the finding is about.
    @Test func takingSomethingPutsLookingAtItBackOnTheQueue() async throws {
        let session = try await session(AviaryGame())
        _ = try await session.move(
            commands: ["x nest", "x pebble", "take pebble"], allowPrompts: false)

        // And at the *top* of the queue, not below the ambient scenery. The
        // real thing put `restate:egg` twelfth on Dungeon before the
        // perishability tier existed, behind *branch*, *reach* and *chirping* —
        // the one item the stage exists to raise, below the fold.
        let queue = try await session.coverage(limit: 200).items
        #expect(queue.first?.id == "restate:pebble")

        let restate = try #require(queue.first { $0.id == "restate:pebble" })
        #expect(restate.how == "x pebble")
        #expect(restate.why.contains("`take` changed it"))
        #expect(restate.kind == .restate)

        let second = try await session.move(commands: ["x pebble"], allowPrompts: false)
        #expect(second.contains("It is tucked into the nest."))
        #expect(!(try await ids(session).contains("restate:pebble")))
    }

    /// A second change re-opens it. One look answers one change, and a thing
    /// that has been moved again is a thing nobody has looked at since.
    @Test func aSecondChangeReopensTheObligation() async throws {
        let session = try await session(AviaryGame())
        _ = try await session.move(
            commands: ["x nest", "take pebble", "x pebble", "drop pebble"],
            allowPrompts: false)
        #expect(try await ids(session).contains("restate:pebble"))
    }

    // MARK: - Timers, and the guard that survived

    /// The same do-nothing probe printing differently at two moments, with
    /// nothing the tester typed in between to explain it, is what a fuse looks
    /// like from the player's chair.
    ///
    /// And it is **not** closed by looking. That is the one guard kept from the
    /// enforcement design this stage otherwise dropped, and it is kept because
    /// it is about quality rather than compulsion: the class of defect this
    /// names cannot be settled by looking once, so it wants a second frame and a
    /// verdict — which is a note, in the evidence, quoting the line.
    @Test func aChangeNothingYouTypedExplainsRaisesATimerItem() async throws {
        let session = try await session(AviaryGame())
        _ = try await session.move(
            commands: ["wait", "wait", "wait"], allowPrompts: false)

        let timer = try #require(
            try await session.coverage(limit: 200).items.first { $0.id == "timer:Yard" })
        #expect(timer.kind == .timer)
        #expect(!timer.kind.closedByLooking)
        #expect(timer.why.contains("A bell rings somewhere behind the wall"))
        #expect(timer.how.contains("wait a few turns, look again"))

        // Looking again is necessary and not sufficient.
        _ = try await session.move(commands: ["look"], allowPrompts: false)
        #expect(try await ids(session).contains("timer:Yard"))

        _ = try await session.note("the bell rang once and then never again", suspicious: false)
        #expect(!(try await ids(session).contains("timer:Yard")))
    }

    /// A change the tester's own commands explain is not a timer. Cloak of
    /// Darkness is the case: hanging the cloak lights the bar and changes what a
    /// `look` prints, and every word of the difference is a word the tester
    /// typed.
    @Test func aChangeYouCausedYourselfIsNotATimer() async throws {
        let session = try await session(OperaHouse())
        _ = try await session.move(
            commands: ["look", "west", "put cloak on hook", "look", "east", "look"],
            allowPrompts: false)
        #expect(try await ids(session).allSatisfy { !$0.hasPrefix("timer:") })
    }

    /// Something named in one room and then in another, with nobody having
    /// touched it, is a wandering thing. Something the tester has been handling
    /// is a thing the tester moved — which is why Cloak of Darkness, whose
    /// player starts out *wearing* the cloak, raises nothing here.
    @Test func aThingYouCarriedYourselfIsNotDisplaced() async throws {
        let session = try await session(OperaHouse())
        _ = try await session.move(
            commands: ["x cloak", "west", "x hook", "put cloak on hook", "east"],
            allowPrompts: false)
        #expect(try await ids(session).allSatisfy { !$0.hasPrefix("displacement:") })
    }

    // MARK: - Notes and hunches

    /// A note is written where the tester saw the thing, costs no turn and no
    /// clock tick, and lands in the evidence rather than in a tool result
    /// nobody kept.
    @Test func aNoteCostsNoTurnAndLandsInTheTranscript() async throws {
        let session = try await session(AviaryGame())
        _ = try await session.move(commands: ["x oak"], allowPrompts: false)

        let receipt = try await session.note("the oak names a nest", suspicious: false)
        #expect(receipt.contains("> // the oak names a nest"))
        #expect(receipt.contains("noted at line 2"))
        #expect(receipt.contains("no turn passed"))
        #expect(try text(at: session.transcriptURL).contains("> // the oak names a nest\n"))
        #expect(try text(at: session.commandsURL) == "x oak\n// the oak names a nest\n")

        // One line, whatever was handed over: a comment is one transcript line
        // by construction, and a second one would not carry the `>` echo.
        _ = try await session.note("first\nsecond", suspicious: false)
        #expect(try text(at: session.transcriptURL).contains("> // first second\n"))

        // A tester that wrote its own marker does not get two.
        _ = try await session.note("// already marked", suspicious: false)
        #expect(try text(at: session.transcriptURL).contains("> // already marked\n"))
    }

    /// A suspicion is an obligation, not a feeling: it goes on the queue and
    /// stays there until the tester comes back to it from a different frame.
    /// The loss this closes is the one the round reports named — four
    /// refutations that handed over a better claim than the one they killed,
    /// and nobody filed any of them.
    @Test func aSuspiciousNoteBecomesAHunchOwedASecondFrame() async throws {
        let session = try await session(AviaryGame())
        _ = try await session.note("the bell has no source", suspicious: true)

        let hunch = try #require(
            try await session.coverage(limit: 200).items.first { $0.id == "hunch:1" })
        #expect(hunch.kind == .hunch)
        #expect(hunch.why.contains("[suspicious] the bell has no source"))
        #expect(try text(at: session.transcriptURL).contains("[suspicious]"))

        // Naming it again in the same breath is not a second frame.
        _ = try await session.move(commands: ["x bell"], allowPrompts: false)
        #expect(try await ids(session).contains("hunch:1"))

        // From another room, it is.
        _ = try await session.move(
            commands: ["north", "x bell"], allowPrompts: false)
        #expect(!(try await ids(session).contains("hunch:1")))
    }

    /// A note is written through `TranscriptRecorder` like every other line, so
    /// the byte identity the whole harness rests on survives it: a session that
    /// annotated itself still records what a `REPL` records for the same lines.
    @Test func aSessionWithNotesIsStillByteIdenticalToTheREPL() async throws {
        let session = try await session(OperaHouse(), role: .unrestricted)
        _ = try await session.move(commands: ["x cloak"], allowPrompts: false)
        _ = try await session.note("worn, and the bar is dark", suspicious: true)
        _ = try await session.move(commands: ["west", "put cloak on hook"], allowPrompts: false)
        _ = try await session.finish(summary: "hung the cloak", leaving: "done", limit: 4)

        let commands = try text(at: session.commandsURL)
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
        let world = try GameWorld(
            game: OperaHouse(), seed: 0, saveDirectory: session.saveDirectory)
        let io = ScriptedIOHandler(lines: commands)
        await REPL(world: world, io: io, status: StatusFooter.always).run()

        #expect(try text(at: session.transcriptURL) == io.transcript)
        #expect(commands.contains("// [suspicious] worn, and the bar is dark"))
        #expect(commands.contains("// [finish] hung the cloak"))
        #expect(commands.contains("// [leaving] done"))
    }

    // MARK: - Stopping

    /// `finish` reports and accepts. There is no minimum on the reason, no cap
    /// on what may be left, and no escalation — two agents played the bare
    /// session surface with no queue and no enforcement at all and both
    /// volunteered honest gap lists, so this asks rather than extracts. What
    /// survives is the accounting: the open list *is* the round's coverage gap,
    /// itemised, and it goes into the report whether or not it is explained.
    @Test func finishReportsWhatIsOpenAndAcceptsAnyway() async throws {
        let session = try await session(AviaryGame())
        _ = try await session.move(commands: ["x oak"], allowPrompts: false)

        let closing = try await session.finish(summary: "no", leaving: nil, limit: 3)
        #expect(closing.accepted)
        #expect(closing.open > 0)
        #expect(closing.items.count == 3)
        #expect(closing.message.hasPrefix("Noted. Still open when you stopped:"))
        #expect(closing.message.contains("Say why in `leaving`"))
        #expect(closing.message.contains("still counted as a gap"))
        // A one-word summary is accepted, and so is playing on afterwards.
        let after = try await session.move(commands: ["x nest"], allowPrompts: false)
        #expect(after.contains("ran=1/1"))
    }

    /// A reason given is a reason not asked for again.
    @Test func aStatedReasonReplacesTheInvitation() async throws {
        let session = try await session(AviaryGame())
        let closing = try await session.finish(
            summary: "walled yard, one oak", leaving: "out of budget", limit: 2)
        #expect(!closing.message.contains("Say why in `leaving`"))
        #expect(try text(at: session.transcriptURL).contains("// [leaving] out of budget"))
    }

    /// An empty summary is the one thing `finish` refuses, and it refuses as a
    /// tool error rather than a trap. Nothing in the MCP layer may `fatalError`.
    @Test func finishNeedsSomethingToSay() async throws {
        let session = try await session(AviaryGame())
        let refusal = await #expect(throws: PlaytestError.self) {
            try await session.finish(summary: "   ", leaving: nil, limit: 4)
        }
        #expect(refusal?.description.contains("needs a summary") == true)
    }

    /// The closing record is written beside the transcript, so a round can read
    /// what a session did instead of interviewing the agent that played it.
    ///
    /// This is the file that retires the two censuses. The orchestration script
    /// has no filesystem and never sees a tool result, so a round's room count
    /// used to be either self-reported — 112 claimed against 155 walked — or
    /// reconstructed by grepping transcripts for the engine's own prose, which
    /// stops working the moment a game re-voices that line. Neither failure is
    /// available to a file the server writes.
    @Test func finishWritesTheClosingRecordBesideTheTranscript() async throws {
        let session = try await session(AviaryGame())
        _ = try await session.move(commands: ["x oak", "north"], allowPrompts: false)

        let closing = try await session.finish(
            summary: "the yard and the shed", leaving: "out of budget", limit: 3)

        // Counted off the status line, in first-seen order, and not asked.
        #expect(closing.roomsVisited == ["Yard", "Shed"])

        let written = try text(at: session.closingURL)
        #expect(written.contains("\"roomsVisited\":[\"Yard\",\"Shed\"]"))
        #expect(written.contains("\"open\":\(closing.open)"))
        #expect(written.contains("\"accepted\":true"))
        // The record sits in the probe directory the transcript is in, so one
        // path finds both.
        #expect(
            session.closingURL.deletingLastPathComponent()
                == session.transcriptURL.deletingLastPathComponent())
    }

    /// Unknown words are counted off the **parse record**, not off the prose.
    ///
    /// `TurnAudit.unknownWords` is every token the vocabulary failed to consume,
    /// which is what the round actually wants to know. The alternative the
    /// harness used for two rounds — grepping the transcript for `I don't know
    /// the word` — reads the engine's own sentence to find out something the
    /// engine already knew, disagreed with the testers' tally by two orders of
    /// magnitude, and would go silent for any game that re-voices
    /// ``GameText/unknownWord``.
    @Test func theClosingRecordCountsUnknownWordsOffTheParseRecord() async throws {
        let session = try await session(AviaryGame())
        _ = try await session.move(
            commands: ["frotz", "frotz", "x oak"], allowPrompts: false)

        let closing = try await session.finish(summary: "tried a word", leaving: nil, limit: 3)
        #expect(closing.unknownWords["frotz"] == 2)
        // A word the game does know is not in the tally at all.
        #expect(closing.unknownWords["oak"] == nil)
        #expect(try text(at: session.closingURL).contains("\"frotz\":2"))
    }

    /// A queue that has run dry says so in player-visible terms — how many
    /// rooms the tester stood in that described a way out, all of them used —
    /// and never *"you never entered the Shed."*
    @Test func anEmptyQueueGetsAFrontierHintAndNotAMap() async throws {
        let session = try await session(AviaryGame())
        let coverage = try await session.coverage(limit: 4)
        #expect(coverage.hint == nil)

        // Nothing in the Lane's description names a way on, so a session that
        // walks there and looks around has a frontier and no map to read it by.
        let closing = try await session.finish(summary: "a look round", leaving: nil, limit: 4)
        #expect(closing.hint == nil)
        #expect(!closing.message.contains("Shed"))
    }

    // MARK: - Signals

    /// The signals are measured off the session's own record, never asked of the
    /// agent. The two census agents in the old harness exist because an agent
    /// asked how much it had covered answered 2 when the truth was 261.
    @Test func theSignalsAreMeasuredAndNotSelfReported() async throws {
        let session = try await session(AviaryGame())
        _ = try await session.move(
            commands: ["x oak", "x nest", "x nest", "south", "look"], allowPrompts: false)

        let signals = await session.stats()
        #expect(signals.commands == 5)
        #expect(signals.roomsVisited == 2)
        #expect(signals.roomDwell == 2.5)
        // Four distinct commands out of five: `x nest` twice.
        #expect(signals.novelCommandRatio == 0.8)
        #expect(signals.objectsBound == 2)
        #expect(signals.nounsPrintedByExamines > 0)
        #expect(signals.openItems > 0)
        #expect(signals.line.contains("rooms=2"))
        #expect(signals.line.contains("noun-follow="))
    }

    /// The one tier of intervention: an inline `harness:` line on a `move`
    /// result when a threshold trips, and nothing else. No hard stop, no
    /// re-dispatch — a number an agent can see is enough for an agent that was
    /// already going to look, and the numbers' real consumer is the round
    /// report.
    @Test func aTrippedThresholdIsANoteAndNotAStop() async throws {
        let session = try await session(AviaryGame())
        let quiet = try await session.move(
            commands: Array(repeating: "wait", count: 10), allowPrompts: false)
        #expect(!quiet.contains("harness:"))

        // Forty examines of the same thing: plenty of nouns printed, none of
        // them followed, and nothing blocked.
        let report = try await session.move(
            commands: ["x oak", "x nest"] + Array(repeating: "x nest", count: 30),
            allowPrompts: false)
        #expect(report.contains("[playtest] harness: "))
        #expect(report.contains("ran=32/32"))
        #expect(report.contains("novel-command ratio"))
    }

    // MARK: - Over the wire

    /// The three new rows end to end, because the schemas and the handlers are
    /// what a client meets and a tool whose arguments are read wrong fails
    /// identically to one that isn't there.
    @Test func theCoverageNoteAndFinishToolsWorkOverTheProtocol() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let server = MCPServer(
            name: "gnusto-playtest", version: "test", instructions: nil,
            tools: PlaytestTools.table(
                for: try PreparedGame(AviaryGame()),
                environment: ["GNUSTO_PLAYTEST_DIR": root.path]))

        func call(_ name: String, _ arguments: String) async throws -> JSONValue {
            try JSONValue(
                text: try #require(
                    await server.handle(
                        line: """
                            {"jsonrpc":"2.0","id":1,"method":"tools/call","params":\
                            {"name":"\(name)","arguments":\(arguments)}}
                            """)))
        }

        let opened = try await call("open", #"{"label":"wire","role":"explorer"}"#)
        let id = try #require(opened["result"]?["structuredContent"]?["session"]?.stringValue)

        let coverage = try await call("coverage", #"{"session":"\#(id)","limit":3}"#)
        #expect(coverage["result"]?["isError"] == .bool(false))
        let queue = try #require(
            coverage["result"]?["structuredContent"]?["items"]?.arrayValue)
        #expect(queue.count == 3)
        // Both channels: prose for the reader that has to choose a command, and
        // fields for anything counting them.
        let listing = try #require(
            coverage["result"]?["content"]?.arrayValue?.first?["text"]?.stringValue)
        #expect(listing.contains("open=11"))
        #expect(listing.contains("room=Yard"))

        let noted = try await call(
            "note", #"{"session":"\#(id)","text":"the grout is unanswerable","suspicious":true}"#)
        #expect(noted["result"]?["isError"] == .bool(false))
        #expect(noted["result"]?["structuredContent"] == nil)

        let finished = try await call(
            "finish", #"{"session":"\#(id)","summary":"one room only","leaving":"time"}"#)
        let closing = try #require(finished["result"]?["structuredContent"])
        #expect(closing["accepted"] == .bool(true))
        #expect(closing["open"]?.intValue ?? 0 > 0)
        #expect(closing["signals"]?["roomsVisited"]?.intValue == 1)
        #expect(closing["transcript"]?.stringValue?.hasSuffix("transcript.txt") == true)
    }

    /// Every row is classified for ordering deliberately, and the ones that
    /// write the transcript say so. A row added later without a thought about it
    /// should fail here rather than race in the field.
    @Test func theWritingRowsDeclareThatTheyMutate() throws {
        let table = PlaytestTools.table(for: try PreparedGame(AviaryGame()), environment: [:])
        #expect(
            Set(table.filter(\.mutatesState).map(\.name)) == [
                "open", "move", "note", "finish", "checkpoint", "restore", "rewind", "export",
            ])
        #expect(
            Set(table.filter { !$0.mutatesState }.map(\.name)) == [
                "survey", "vocabulary", "recall", "coverage", "replay",
            ])
    }
}
