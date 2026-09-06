import GnustoTestSupport
import Testing

@testable import Gnusto

struct BackdropTests {
    @Test func malformedVocabularyStillFailsBootstrap() throws {
        do {
            _ = try Bootstrap.build(InvalidBackdropGame())
            Issue.record("Expected malformed backdrop vocabulary to fail bootstrap")
        } catch let error as BootstrapError {
            #expect(error.diagnostics.contains { $0.contains("wall") && $0.contains("!!!") })
        }
    }

    @Test func equivalentDeclarationsKeepTheirIdentityAndDefinition() throws {
        let game = BackdropGame(compact: true)
        let copy = game.wall
        #expect(copy == game.wall)
        #expect(game.wall != Item.backdrop("stone wall"))
        let (definition, state) = try Bootstrap.build(game)
        let wall = try #require(definition.items[EntityID("wall")])
        #expect(wall.name == "stone wall")
        #expect(!wall.isTakable)
        #expect(state.placements[EntityID("wall")] == .room(EntityID("hall")))
        #expect(definition.items[EntityID("BackdropFixtures.ceiling")] != nil)
    }

    @Test(arguments: [
        "x wall", "x rough wall", "x masonry", "x old brickwork", "x stone-wall",
        "take wall", "take all", "look", "search niche", "take coin", "x ceiling",
    ])
    func shorthandPreservesOrdinaryItemBehavior(command: String) async throws {
        let compact = try await playBackdrop(BackdropGame(compact: true), [command], seed: 0)
        let explicit = try await playBackdrop(BackdropGame(compact: false), [command], seed: 0)
        #expect(compact == explicit)
    }

    @Test func sceneryAnswersWithoutBecomingLooseLoot() async throws {
        let transcript = try await playBackdrop(
            BackdropGame(compact: true), ["look", "x old brickwork", "take wall", "take all", "i"])
        #expect(turnOutput(of: "x old brickwork", in: transcript).contains("Mortar fills the cracks."))
        #expect(!turnOutput(of: "look", in: transcript).contains("There is a stone wall here."))
        #expect(!turnOutput(of: "take wall", in: transcript).contains("Taken."))
        #expect(!turnOutput(of: "i", in: transcript).contains("stone wall"))
        #expect(turnOutput(of: "i", in: transcript).contains("coin"))
    }

    @Test func backdropScopeFollowsItsPlacement() async throws {
        let transcript = try await playBackdrop(BackdropGame(compact: true), ["north", "x wall"])
        #expect(!turnOutput(of: "x wall", in: transcript).contains("Mortar fills the cracks."))
        let explicit = try await playBackdrop(BackdropGame(compact: false), ["north", "x wall"])
        #expect(transcript == explicit)
    }

    @Test func omittedDescriptionUsesTheStockExamineLine() async throws {
        let transcript = try await playBackdrop(BackdropGame(compact: true), ["x ceiling"])
        #expect(turnOutput(of: "x ceiling", in: transcript).contains("You see nothing special about the ceiling."))
    }

    @Test func additionalTraitsAndDynamicDescriptionsStillWork() async throws {
        let transcript = try await playBackdrop(
            BackdropGame(compact: true), ["x niche", "search niche", "take coin", "examine niche"])
        #expect(turnOutput(of: "x niche", in: transcript).contains("A coin rests in the niche."))
        #expect(turnOutput(of: "search niche", in: transcript).contains("coin"))
        #expect(turnOutput(of: "take coin", in: transcript).contains("Taken."))
        #expect(turnOutput(of: "examine niche", in: transcript).contains("The niche is empty."))
    }
}

private struct BackdropFixtures: GameContent {
    let ceiling: Item

    init(compact: Bool) {
        ceiling =
            compact
            ? Item.backdrop("ceiling")
            : Item {
                name("ceiling")
                scenery
            }
    }
}

private struct BackdropGame: Game {
    let title = "Backdrop Test"
    let intro = "A quiet room."
    let yard = Location { name("Yard") }
    let hall = Location {
        name("Hall")
        description("A wall and a niche beneath a ceiling.")
    }
    let wall: Item
    let niche: Item
    let coin = Item { name("coin") }
    let fixtures: BackdropFixtures

    init() {
        self.init(compact: true)
    }

    init(compact: Bool) {
        fixtures = BackdropFixtures(compact: compact)
        if compact {
            wall = Item.backdrop(
                "stone wall", adjectives: ["rough"], synonyms: ["masonry", "old brickwork"],
                description: "Mortar fills the cracks.")
            niche = Item.backdrop("niche") { container }
        } else {
            wall = Item {
                name("stone wall")
                adjectives("rough")
                synonyms("masonry", "old brickwork")
                description("Mortar fills the cracks.")
                scenery
            }
            niche = Item {
                name("niche")
                scenery
                container
            }
        }
    }

    var content: GameContents { fixtures }

    var map: WorldMap {
        player.starts(in: hall)
        hall.north(yard)
        yard.south(hall)
        wall.starts(in: hall)
        niche.starts(in: hall)
        coin.starts(inside: niche)
        fixtures.ceiling.starts(in: hall)
    }

    var rules: Rules {
        niche.describe {
            niche.holds(coin) ? "A coin rests in the niche." : "The niche is empty."
        }
    }
}

private struct InvalidBackdropGame: Game {
    let title = "Invalid Backdrop"
    let intro = ""
    let room = Location { name("Room") }
    let wall = Item.backdrop("wall", synonyms: ["!!!"])

    var map: WorldMap {
        player.starts(in: room)
        wall.starts(in: room)
    }
}

// `play` caches by game type, but this fixture varies its declarations per
// instance. Build each world afresh so the comparison exercises both forms.
private func playBackdrop(
    _ game: BackdropGame, _ commands: [String], seed: UInt64 = 0
) async throws -> String {
    let world = try GameWorld(game: game, seed: seed)
    let io = ScriptedIOHandler(lines: commands)
    await REPL(world: world, io: io).run()
    return io.transcript
}
