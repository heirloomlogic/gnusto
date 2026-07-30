import Foundation
import GnustoTestSupport
import Testing

@testable import Gnusto
@testable import Zork1

/// The player is a thing in the world: an item the bootstrap synthesizes,
/// answering to `me`/`myself`/`self`, always in scope and never in a room.
struct PlayerItemTests {
    // MARK: - Examining yourself

    @Test func everySelfNounExamines() async throws {
        let commands = ["x me", "examine myself", "x self"]
        let transcript = try await play(MiniGame(), commands)
        for command in commands {
            #expect(
                turnOutput(of: command, in: transcript)
                    .contains("You look much as you always do."))
        }
        // The symptom the issue opened on: all three were unknown words.
        #expect(!transcript.contains("I don't know the word"))
    }

    @Test func theSelfNounsSurviveTheDark() async throws {
        // Held items are perceivable without light, and so is the player.
        let transcript = try await play(MiniGame(), ["down", "x me"])
        #expect(turnOutput(of: "x me", in: transcript).contains("much as you always do"))
    }

    @Test func aDemoGameAnswersXMe() async throws {
        let transcript = try await play(Zork1(), ["x me"])
        #expect(turnOutput(of: "x me", in: transcript).contains("You look much as you always do."))
    }

    // MARK: - The other things a player aims at themselves

    @Test func selfDirectedVerbsReadLikeEnglish() async throws {
        let transcript = try await play(
            MiniGame(), ["search me", "take myself", "follow me", "hello me"])
        expectInOrder(
            transcript,
            [
                "You pat yourself down and find only what you're carrying.",
                "You have yourself well in hand already.",
                "You are already right here.",
                "You and yourself have already met.",
            ])
        // None of the stock person lines, which are about somebody else.
        #expect(!transcript.contains("The yourself"))
    }

    // MARK: - Present, but never listed

    @Test func thePlayerIsInNoRoomAndNoInventory() async throws {
        let transcript = try await play(MiniGame(), ["look", "inventory", "take all"])
        #expect(!turnOutput(of: "look", in: transcript).contains("yourself"))
        #expect(!turnOutput(of: "inventory", in: transcript).contains("yourself"))
        let takeAll = turnOutput(of: "take all", in: transcript)
        #expect(takeAll.contains("dusty book"))
        #expect(!takeAll.contains("yourself"))
    }

    @Test func theBootstrapPlacesThePlayerNowhere() throws {
        let (definition, state) = try Bootstrap.build(MiniGame())
        #expect(definition.items[.player]?.isActor == true)
        #expect(state.placements[.player] == .nowhere)
        // A person, but not one of the cast — the set that answers "who else
        // is here" must not gain the player.
        #expect(!definition.castIDs.contains(.player))
    }

    // MARK: - The three override channels

    @Test func aDescribeRuleVariesWithState() async throws {
        let transcript = try await play(
            SelfAwareGame(), ["x me", "take straw hat", "wear straw hat", "x myself"])
        #expect(turnOutput(of: "x me", in: transcript).contains("Hatless."))
        #expect(
            turnOutput(of: "x myself", in: transcript)
                .contains("You are wearing a straw hat, and it suits you."))
    }

    @Test func aRuntimeAssignmentBeatsTheDescribeRule() async throws {
        let transcript = try await play(SelfAwareGame(), ["take mud", "x me"])
        #expect(turnOutput(of: "x me", in: transcript).contains("Mud to the elbows."))
        #expect(!turnOutput(of: "x me", in: transcript).contains("Hatless."))
    }

    @Test func aRuleAttachesToAnEntityTheGameNeverDeclared() async throws {
        let transcript = try await play(SelfAwareGame(), ["drop me"])
        #expect(turnOutput(of: "drop me", in: transcript).contains("You stay where you are."))
    }

    @Test func gameTextReskinsTheStockSelfLines() async throws {
        let transcript = try await play(SelfSkinGame(), ["x me", "take me"])
        expectInOrder(transcript, ["A detective, and it shows.", "You are already had."])
    }

    // MARK: - Nothing else moved

    @Test func anUnknownWordIsStillUnknown() async throws {
        let transcript = try await play(MiniGame(), ["x grue"])
        #expect(turnOutput(of: "x grue", in: transcript).contains("I don't know the word \"grue\"."))
    }

    @Test func anOutOfScopeNounStillCantBeSeen() async throws {
        // The coin is on the den's table; the study has nothing.
        let transcript = try await play(MiniGame(), ["east", "x coin"])
        #expect(turnOutput(of: "x coin", in: transcript).contains("You can't see any such thing."))
    }

    @Test func aBareHelloStillFindsTheOnePersonHere() async throws {
        // The hall holds the mule and nobody else: the player must not make
        // that a crowd, and an empty room must not become company.
        let withCompany = try await play(GuardpostGame(), ["greet"])
        #expect(turnOutput(of: "greet", in: withCompany).contains("pack mule"))
        let alone = try await play(MiniGame(), ["greet"])
        #expect(turnOutput(of: "greet", in: alone).contains("There's nobody here to greet."))
    }

    @Test func aDeclaredItemNamedMeIsStillTheParsersProblemAlone() throws {
        // The reserved ID guard still fires for an author's `player` property.
        #expect(throws: BootstrapError.self) { try Bootstrap.build(PlayerIDCollisionGame()) }
    }

    // MARK: - Saves

    @Test func aSaveCarryingThePlayerPlacementRestores() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gnusto-player-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let transcript = try await play(
            SelfAwareGame(),
            ["take mud", "save", "slot", "restore", "slot", "x me"],
            saveDirectory: dir)
        #expect(transcript.contains("Restored."))
        #expect(turnOutput(of: "x me", in: transcript).contains("Mud to the elbows."))
    }

    @Test func aSaveFromBeforeThePlayerHadAnItemStillLoads() throws {
        // Old saves have no `player` key in `placements`. Absent behaves
        // exactly like `.nowhere`, so consistency must not depend on it.
        let (definition, state) = try Bootstrap.build(MiniGame())
        let old = WorldState(
            playerLocation: state.playerLocation,
            placements: state.placements.filter { $0.key != .player })
        #expect(old.isConsistent(with: definition))
    }
}
