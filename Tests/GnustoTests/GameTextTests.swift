import GnustoTestSupport
import Testing

@testable import Gnusto

/// A game that re-skins a couple of stock lines to prove the engine speaks
/// through `GameText`.
private struct SnarkyGame: Game {
    let title = "Snark"
    let intro = "A very small cave."

    let cave = Location {
        name("Cave")
        description("A cave barely big enough to stand in.")
    }

    let pebble = Item {
        name("smooth pebble")
        adjectives("smooth")
    }

    var map: WorldMap {
        player.starts(in: cave)
        pebble.starts(in: cave)
    }

    var text: GameText {
        var text = GameText()
        text.taken = "Snagged."
        text.cantGoThatWay = "Walls exist, you know."
        return text
    }
}

/// Phase 6 GameText: every stock player-facing line lives on a value the
/// game can override; the defaults are the classic voice (covered by the
/// Cloak transcript canary).
struct GameTextTests {
    @Test func overriddenLinesSpeakInTheGamesVoice() async throws {
        let transcript = try await play(SnarkyGame(), ["take pebble", "west"])
        expectInOrder(transcript, ["Snagged.", "Walls exist, you know."])
        #expect(!transcript.contains("Taken."))
    }

    @Test func untouchedLinesKeepTheirDefaults() async throws {
        let transcript = try await play(SnarkyGame(), ["drop pebble"])
        expectInOrder(transcript, ["You aren't carrying that."])
    }
}

/// The shape rule stated on ``GameText`` itself, made checkable.
///
/// The complaint this answers is that reading the type top to bottom showed
/// several shapes with no way to tell which slot obeyed which rule. Naming the
/// rule in a doc comment fixes that for exactly as long as the next line to
/// arrive is written by somebody who read it, so it is asserted here instead:
/// a line is a `String`, a `Line` over a noun, or a label on the list below,
/// which is the taxonomy in executable form.
struct GameTextShapeTests {
    /// The lines that are deliberately *not* ``GameText/Line``s, each for a
    /// stated reason. Adding to this list is a decision; arriving in it by
    /// accident is what the test prevents.
    static let notLines: Set<String> = [
        // Their subject is not a thing in the world but a word the player
        // typed, and `Line` is `ExpressibleByStringLiteral` — one of these as a
        // `Line` would let a game write `text.unknownWord = "Eh?"` and silently
        // drop the word the sentence is about.
        "unknownWord", "noReferent", "missingObject", "multipleNotAllowedWith",
        // Written by the parser, from `Vocabulary`, before any entity is
        // resolved. None carries a verb that agrees with its noun.
        "missingIndirect", "missingTopic", "missingDirection", "ambiguous",
        // A list, a number, a title, or nothing at all.
        "inventorySentence", "scoreLine", "banner", "pitchBlack",
        // A name and a *list*, which is a third thing again: the list is what
        // the verb agrees with, and `Line` has no shape for it.
        "openingReveals", "inTheContainer",
        // Not a line — the stub floor, swept separately.
        "stubs",
    ]

    @Test func everyLineIsAStringAOneNounLineOrADeclaredException() {
        for child in Mirror(reflecting: GameText()).children {
            guard let label = child.label else { continue }
            // Positive identification only. A dynamic cast to a *function*
            // type is not reliable in Swift and an earlier sweep trapped doing
            // it, so the question asked here is "is this a shape we know?" and
            // never "is this a closure of some particular arity?".
            let known =
                child.value is String
                || child.value is GameText.Line<GameText.Noun>
                || child.value is GameText.Line<GameText.Noun?>
                || child.value is GameText.Line<GameText.Holding>
                || child.value is GameText.Line<GameText.Gift>
                || child.value is GameText.Line<GameText.Aboard>
            #expect(
                known || Self.notLines.contains(label),
                """
                `GameText.\(label)` is neither a `String`, a `Line` over a noun, \
                nor a declared exception. Either give it a `Line` — a line about \
                a thing in the world should take a `GameText.Noun`, so its verbs \
                can agree with what it names — or add it to `notLines` with the \
                reason it is not one.
                """)
        }
    }

    /// A line added without being classified fails by name above; a line added
    /// that happens to be a `String` would pass it silently. This is what
    /// catches that one.
    @Test func theSweepSeesEveryLineTheTypeShips() {
        #expect(Mirror(reflecting: GameText()).children.count == 120)
    }
}

/// What the stock lines on `GameText` proper say about a thing that is
/// grammatically plural.
///
/// **These assertions pin a defect.** Every sentence in
/// ``aPluralThingGetsSingularVerbsFromEveryLineThatCarriesOne`` is ungrammatical
/// and every one of them is what the engine prints today, because the lines that
/// produce them interpolate a bare `String` into a sentence whose verb was
/// written once, in the singular, by the engine. ``GameText/Noun`` exists to make
/// that unwritable and #245 spent it on the stub floor; `GameText` proper is the
/// half that was left.
///
/// They are pinned *before* the fix rather than written after it so that the set
/// of sentences that move is a matter of record — anything that moves and is not
/// in this list is a regression, not a correction. When the lines learn to agree,
/// this test flips wholesale to the wording named in each comment, and the two
/// neighbouring tests must not move at all.
struct PluralAgreementTests {
    /// The defect, line by line. Each `#expect` is today's wording; the comment
    /// beside it is what it becomes.
    @Test func aPluralThingGetsSingularVerbsFromEveryLineThatCarriesOne() async throws {
        let transcript = try await play(
            PluralLab(),
            [
                "open gates", "north", "search bins", "search crates",
                "search hamper", "turn on lamps", "turn off lamps",
                "hello hands", "hello scales",
                "follow hands", "follow scales",
                "hands, take scales",
            ])

        // `itemHere` — "There are some metal bins here."
        #expect(transcript.contains("There are some metal bins here."))
        // `actorHere` — "Some stable hands are here."
        #expect(transcript.contains("Some stable hands are here."))
        // `itemInContainer` — the verb belongs to the *contents*, which the
        // sentence names second.
        #expect(transcript.contains("In the wicker hamper are some lead weights."))
        // `locked` — "The iron gates are locked."
        #expect(transcript.contains("The iron gates are locked."))
        // `closedContainer`, off the travel path — "The iron gates are closed."
        #expect(transcript.contains("The iron gates are closed."))
        // `closedContainer`, off the search path — "The metal bins are closed."
        #expect(transcript.contains("The metal bins are closed."))
        // `emptyContainer` — "The wooden crates are empty."
        #expect(transcript.contains("The wooden crates are empty."))
        // `nowOn` — "The carriage lamps are now on."
        #expect(transcript.contains("The carriage lamps are now on."))
        // `nowOff` — "The carriage lamps are now off."
        #expect(transcript.contains("The carriage lamps are now off."))
        // `greets` — "The stable hands nod, and say nothing."
        #expect(transcript.contains("The stable hands nod, and say nothing."))
        // `cantGreetThat` — "The scales are unlikely to answer."
        #expect(transcript.contains("The scales are unlikely to answer."))
        // `alreadyFollowing` — "The stable hands are right here."
        #expect(transcript.contains("The stable hands are right here."))
        // `cantFollowThat` — "The scales aren't going anywhere."
        #expect(transcript.contains("The scales aren't going anywhere."))
        // `notTakingOrders` — "The stable hands have no intention …"
        #expect(transcript.contains("The stable hands have no intention of taking orders from you."))
        // `inTheContainer` — the search path, where the verb used to be chosen
        // by *counting* the contents. One plural thing is one thing, so it said
        // "is"; the rule is plural when there are several **or** when the only
        // one is itself plural.
        #expect(transcript.contains("In the wicker hamper are some lead weights."))
    }

    /// The same lines, aimed at the singular twin of each plural thing. This is
    /// what stops the fix from being "always say *are*": a line that agrees by
    /// dropping its verb, or by hard-coding the plural instead, passes the test
    /// above and fails this one.
    ///
    /// Nothing here may ever move.
    @Test func theSingularTwinOfEveryPluralThingReadsCorrectlyAndStaysThatWay() async throws {
        let transcript = try await play(
            PluralLab(),
            [
                "open chest", "search chest", "search jar",
                "turn on lantern", "turn off lantern",
                "hello butler", "hello rod",
                "follow butler",
                "butler, take scales",
            ])

        #expect(transcript.contains("There is a brass rod here."))  // itemHere
        #expect(transcript.contains("A butler is here."))  // actorHere
        #expect(transcript.contains("The oak chest is locked."))  // locked
        #expect(transcript.contains("The oak chest is closed."))  // closedContainer
        #expect(transcript.contains("The stoneware jar is empty."))  // emptyContainer
        #expect(transcript.contains("The tin lantern is now on."))  // nowOn
        #expect(transcript.contains("The tin lantern is now off."))  // nowOff
        #expect(transcript.contains("The butler nods, and says nothing."))  // greets
        #expect(transcript.contains("The brass rod is unlikely to answer."))  // cantGreetThat
        #expect(transcript.contains("The butler is right here."))  // alreadyFollowing
        #expect(  // notTakingOrders
            transcript.contains("The butler has no intention of taking orders from you."))
    }

    /// The lines that name a plural thing and have **no verb to agree with it**
    /// — a modal ("would take exception"), a verb belonging to the player ("you
    /// find"), or no verb at all. They read correctly today for both numbers and
    /// must still read that way afterwards: converting them buys uniformity, not
    /// a fix, and a diff that moves one of these has changed prose it was only
    /// supposed to retype.
    ///
    /// ``GameText/doesNotKnowHow`` is the control. It is the one line on
    /// `GameText` proper that has taken a ``GameText/Noun`` all along, so it
    /// already agrees — proof that the currency works end to end before anything
    /// else moves to it.
    @Test func theLinesWithNoVerbToAgreeSayTheSameThingForBothNumbers() async throws {
        let transcript = try await play(
            PluralLab(),
            [
                "take pins", "search scales", "search rod", "x scales", "x rod",
                "take hands", "take butler", "search hands", "search butler",
                "twins, take scales",
            ])

        #expect(transcript.contains("You can't reach the steel pins."))  // cantReach
        #expect(transcript.contains("You find nothing of interest in the scales."))
        #expect(transcript.contains("You find nothing of interest in the brass rod."))
        #expect(transcript.contains("You see nothing special about the scales."))
        #expect(transcript.contains("You see nothing special about the brass rod."))
        #expect(transcript.contains("The stable hands would take exception to that."))
        #expect(transcript.contains("The butler would take exception to that."))
        #expect(transcript.contains("The stable hands would have something to say about that."))
        #expect(transcript.contains("The butler would have something to say about that."))

        // The control: already a `Noun`, already agreeing.
        #expect(transcript.contains("The twins do not know how to do that."))
    }
}
