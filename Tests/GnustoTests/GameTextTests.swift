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
                "turn on lamps", "turn off lamps",
                "hello hands", "hello scales",
                "follow hands", "follow scales",
                "hands, take scales",
            ])

        // `itemHere` — "There are some metal bins here."
        #expect(transcript.contains("There is some metal bins here."))
        // `actorHere` — "Some stable hands are here."
        #expect(transcript.contains("Some stable hands is here."))
        // `itemInContainer` — "In the wicker hamper are some lead weights."
        // The verb belongs to the *contents*, which the sentence names second.
        #expect(transcript.contains("In the wicker hamper is some lead weights."))
        // `locked` — "The iron gates are locked."
        #expect(transcript.contains("The iron gates is locked."))
        // `closedContainer`, off the travel path — "The iron gates are closed."
        #expect(transcript.contains("The iron gates is closed."))
        // `closedContainer`, off the search path — "The metal bins are closed."
        #expect(transcript.contains("The metal bins is closed."))
        // `emptyContainer` — "The wooden crates are empty."
        #expect(transcript.contains("The wooden crates is empty."))
        // `nowOn` — "The carriage lamps are now on."
        #expect(transcript.contains("The carriage lamps is now on."))
        // `nowOff` — "The carriage lamps are now off."
        #expect(transcript.contains("The carriage lamps is now off."))
        // `greets` — "The stable hands nod, and say nothing."
        #expect(transcript.contains("The stable hands nods, and says nothing."))
        // `cantGreetThat` — "The scales are unlikely to answer."
        #expect(transcript.contains("The scales is unlikely to answer."))
        // `alreadyFollowing` — "The stable hands are right here."
        #expect(transcript.contains("The stable hands is right here."))
        // `cantFollowThat` — "The scales aren't going anywhere."
        #expect(transcript.contains("The scales isn't going anywhere."))
        // `notTakingOrders` — "The stable hands have no intention …"
        #expect(transcript.contains("The stable hands has no intention of taking orders from you."))
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
