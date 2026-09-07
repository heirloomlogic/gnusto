import GnustoTestSupport
import Testing

@testable import Gnusto

struct CannedReplyTests {
    @Test(arguments: [
        "burn lamp", "take chest", "pour can", "empty can", "climb ladder", "take rails",
        "greet keeper", "attack keeper", "smell", "swim", "take beam", "burn beam",
        "take lamp", "x lamp",
    ])
    func shorthandProducesTheSameTurnAsTheClosure(command: String) async throws {
        let compact = try await playCannedReply(CannedReplyGame(compact: true), [command])
        let explicit = try await playCannedReply(CannedReplyGame(compact: false), [command])
        #expect(compact == explicit)
    }

    @Test func replyAndRefuseBothAnswerAndSkipTheDefault() async throws {
        let transcript = try await playCannedReply(
            CannedReplyGame(compact: true), ["burn lamp", "take chest", "i"])
        #expect(turnOutput(of: "burn lamp", in: transcript).contains("That is what it is for."))
        #expect(!turnOutput(of: "take chest", in: transcript).contains("Taken."))
        #expect(!turnOutput(of: "i", in: transcript).contains("chest"))
    }

    @Test func oneRuleAnswersEveryIntentItNames() async throws {
        let transcript = try await playCannedReply(
            CannedReplyGame(compact: true), ["pour can", "empty can"])
        for command in ["pour can", "empty can"] {
            #expect(turnOutput(of: command, in: transcript).contains("one place to go tonight"))
        }
    }

    @Test func namingRendersTheEntitysArticleAndNumber() async throws {
        let transcript = try await playCannedReply(
            CannedReplyGame(compact: true), ["climb ladder", "take rails", "greet keeper"])
        #expect(turnOutput(of: "climb ladder", in: transcript).contains("onto the ladder"))
        // `plural` picks the agreement, so a template cannot hard-code "is".
        #expect(turnOutput(of: "take rails", in: transcript).contains("The rails are bolted down."))
        // `properName` drops the article the engine would otherwise supply.
        #expect(turnOutput(of: "greet keeper", in: transcript).contains("Mr. Vane says nothing."))
        #expect(!turnOutput(of: "greet keeper", in: transcript).contains("the Mr. Vane"))
    }

    @Test func aRoomsLineIsHandedNothingAndStillPrints() async throws {
        let transcript = try await playCannedReply(
            CannedReplyGame(compact: true), ["smell", "swim"])
        #expect(turnOutput(of: "smell", in: transcript).contains("Salt, and lamp oil."))
        #expect(turnOutput(of: "swim", in: transcript).contains("save it the trip"))
    }

    @Test func itIsAnOrdinaryBeforeRuleAndStacksInDeclarationOrder() async throws {
        let transcript = try await playCannedReply(
            CannedReplyGame(compact: true), ["burn beam", "take beam"])
        // The shorthand is declared first, so it throws first.
        #expect(turnOutput(of: "burn beam", in: transcript).contains("Salt-soaked and green."))
        #expect(!turnOutput(of: "burn beam", in: transcript).contains("never reached"))
        // And a closure declared first still wins over a shorthand behind it.
        #expect(turnOutput(of: "take beam", in: transcript).contains("Both hands, and even then."))
        #expect(!turnOutput(of: "take beam", in: transcript).contains("never reached"))
    }

    @Test func reachIsCheckedAheadOfTheLineJustAsItIsAheadOfAnyBeforeRule() async throws {
        let transcript = try await playCannedReply(
            CannedReplyGame(compact: true), ["take gull", "x gull"])
        #expect(turnOutput(of: "take gull", in: transcript).contains("out over the water"))
        #expect(!turnOutput(of: "take gull", in: transcript).contains("It would only bite you."))
        #expect(turnOutput(of: "x gull", in: transcript).contains("Grey, and unbothered."))
    }
}

private struct CannedReplyFixtures: GameContent {
    let ladder: Item

    init(compact: Bool) {
        ladder = Item {
            name("ladder")
            scenery
        }
        _ = compact
    }
}

private struct CannedReplyGame: Game {
    let title = "Canned Reply Test"
    let intro = "Salt on everything."
    let jetty = Location {
        name("Jetty")
        description("Planks, and the sea beyond them.")
    }
    let lamp = Item { name("oil lamp") }
    let can = Item { name("oil can") }
    let chest = Item { name("chest") }
    let rails = Item {
        name("rails")
        plural
    }
    let beam = Item { name("beam") }
    let gull = Item {
        name("gull")
        description("Grey, and unbothered.")
    }
    let keeper = Actor {
        name("Mr. Vane")
        synonyms("keeper")
        properName
    }
    let fixtures: CannedReplyFixtures
    let compact: Bool

    init() {
        self.init(compact: true)
    }

    init(compact: Bool) {
        self.compact = compact
        fixtures = CannedReplyFixtures(compact: compact)
    }

    var content: GameContents { fixtures }

    var map: WorldMap {
        player.starts(in: jetty)
        lamp.starts(in: jetty)
        can.starts(in: jetty)
        chest.starts(in: jetty)
        rails.starts(in: jetty)
        beam.starts(in: jetty)
        gull.starts(in: jetty)
        keeper.starts(in: jetty)
        fixtures.ladder.starts(in: jetty)
    }

    var rules: Rules {
        // The gull is in the room but off the end of the jetty, so stage 0
        // answers before any of these rules is consulted.
        gull.reach(otherwise: "The gull is out over the water.") { false }

        if compact {
            lamp.before(.burn, reply: "That is what it is for. Light it.")
            chest.before(.take, refuse: "Brine-swollen, and going nowhere.")
            can.before(.pour, .empty, refuse: "That oil has one place to go tonight.")
            fixtures.ladder.before(.climb, reply: .naming { "You can't climb onto \($0)." })
            rails.before(.take, refuse: .naming { "\($0.sentenceCased) \($0.verb("is", "are")) bolted down." })
            keeper.before(.greet, .attack, reply: .naming { "\($0.sentenceCased) says nothing." })
            jetty.before(.smell, reply: "Salt, and lamp oil.")
            jetty.before(.swim, refuse: .init(Self.swimming))
            gull.before(.take, reply: "It would only bite you.")

            beam.before(.burn, reply: "Salt-soaked and green.")
            beam.before(.burn) { try reply("never reached") }
            beam.before(.take) { try refuse("Both hands, and even then.") }
            beam.before(.take, refuse: "never reached")
        } else {
            lamp.before(.burn) { try reply("That is what it is for. Light it.") }
            chest.before(.take) { try refuse("Brine-swollen, and going nowhere.") }
            can.before(.pour, .empty) { try refuse("That oil has one place to go tonight.") }
            fixtures.ladder.before(.climb) {
                try reply("You can't climb onto \(fixtures.ladder.definiteName).")
            }
            rails.before(.take) {
                let noun = rails.definiteNoun
                try refuse("\(noun.sentenceCased) \(noun.verb("is", "are")) bolted down.")
            }
            keeper.before(.greet, .attack) {
                try reply("\(keeper.definiteNoun.sentenceCased) says nothing.")
            }
            jetty.before(.smell) { try reply("Salt, and lamp oil.") }
            jetty.before(.swim) { try refuse(Self.swimming) }
            gull.before(.take) { try reply("It would only bite you.") }

            beam.before(.burn) { try reply("Salt-soaked and green.") }
            beam.before(.burn) { try reply("never reached") }
            beam.before(.take) { try refuse("Both hands, and even then.") }
            beam.before(.take) { try refuse("never reached") }
        }
    }

    static let swimming = """
        The sea is right there and it is coming to you. Going to meet it would
        only save it the trip.
        """
}

// `play` caches by game type, but this fixture varies its declarations per
// instance. Build each world afresh so the comparison exercises both forms.
private func playCannedReply(
    _ game: CannedReplyGame, _ commands: [String], seed: UInt64 = 0
) async throws -> String {
    let world = try GameWorld(game: game, seed: seed)
    let io = ScriptedIOHandler(lines: commands)
    await REPL(world: world, io: io).run()
    return io.transcript
}
