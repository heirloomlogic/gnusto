import GnustoTestSupport
import Synchronization
import Testing

@testable import Gnusto

/// A game that re-skins a few stock lines to prove the engine speaks through
/// `GameText` — and re-skins one of them *live*, so the two spellings of a
/// fixed line sit in one `text` block where they can be compared.
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
        // The same slot type as the two above, widened. Nothing in the engine
        // changed to allow it, and neither of those two paid anything for it.
        text.timePasses = .live {
            pebble.isHeld
                ? "A moment passes, pebble in hand."
                : "A moment passes, empty-handed."
        }
        return text
    }
}

/// Phase 6 GameText: every stock player-facing line lives on a value the
/// game can override; the defaults are the classic voice (covered by the
/// Cloak transcript canary).
struct GameTextTests {
    /// Both fixed lines here are written as plain string literals, which is the
    /// half of the shape rule that has to keep costing nothing.
    @Test func overriddenLinesSpeakInTheGamesVoice() async throws {
        let transcript = try await play(SnarkyGame(), ["take pebble", "west"])
        expectInOrder(transcript, ["Snagged.", "Walls exist, you know."])
        #expect(!transcript.contains("Taken."))
    }

    @Test func untouchedLinesKeepTheirDefaults() async throws {
        let transcript = try await play(SnarkyGame(), ["drop pebble"])
        expectInOrder(transcript, ["You aren't carrying that."])
    }

    /// A fixed line is fixed because the *game* wrote it that way, not because
    /// the engine's own wording for it happens to look at nothing. The same
    /// slot answers differently on two turns here, which is the thing a `String`
    /// could not do and the reason every stock line is a `Line`.
    @Test func aLiveLineIsAskedAgainEveryTurn() async throws {
        let transcript = try await play(
            SnarkyGame(), ["wait", "take pebble", "wait"])
        expectInOrder(
            transcript,
            [
                "A moment passes, empty-handed.",
                "Snagged.",
                "A moment passes, pebble in hand.",
            ])
    }
}

/// The shape rule stated on ``GameText`` itself, made checkable.
///
/// The complaint this answers is that reading the type top to bottom showed
/// several shapes with no way to tell which slot obeyed which rule. Naming the
/// rule in a doc comment fixes that for exactly as long as the next line to
/// arrive is written by somebody who read it, so it is asserted here instead.
///
/// As of #255 the assertion is one cast. Every stock line is a
/// ``GameText/Line``, and every `Line` is a ``StockLine`` whatever it is about,
/// so a subject added tomorrow is classified the day it lands — where the
/// seven-arm disjunction this replaced had to be taught each new shape by hand,
/// in this file and two others.
struct GameTextShapeTests {
    /// The properties that are deliberately *not* ``GameText/Line``s, each for a
    /// stated reason. Adding to this list is a decision; arriving in it by
    /// accident is what the test prevents.
    ///
    /// It used to hold eleven names. Ten of them were lines about something the
    /// sentence could not do without — a word, a prompt, a score — kept out
    /// because `Line` was unconditionally `ExpressibleByStringLiteral` and a
    /// game could have dropped the subject. That is a conformance now
    /// (``DroppableSubject``), so they are `Line`s like everything else and the
    /// list is down to the one property that is not a line at all.
    static let notLines: Set<String> = [
        // Not a line — the stub floor, swept separately.
        "stubs"
    ]

    @Test func everyLineIsAStockLineOrADeclaredException() {
        for child in Mirror(reflecting: GameText()).children {
            guard let label = child.label else { continue }
            // Positive identification only. A dynamic cast to a *function*
            // type is not reliable in Swift and an earlier sweep trapped doing
            // it, so the question asked here is "is this a line?" and never
            // "is this a closure of some particular arity?".
            #expect(
                child.value is any StockLine || Self.notLines.contains(label),
                """
                `GameText.\(label)` is not a `GameText.Line`, nor a declared \
                exception. Give it a `Line` — a line about a thing in the world \
                takes a `GameText.Noun` so its verbs can agree with what it \
                names, one about nothing in particular takes `Nothing`, and one \
                about anything else takes a subject conforming to \
                `LineSubject` — or add it to `notLines` with the reason it is \
                not one.
                """)
        }
    }

    /// A line added without being classified fails by name above; a raw closure
    /// added straight to ``notLines``, classified but never argued for, would
    /// pass it silently. This is what catches that one.
    @Test func theSweepSeesEveryLineTheTypeShips() {
        #expect(Mirror(reflecting: GameText()).children.count == 124)
    }

    /// The sweep above proves each line *is* a `StockLine`; this proves the
    /// conformance carries its weight. A `samples` that returned nothing would
    /// satisfy every cast in here and leave `engineVoicedStubLines` comparing
    /// empty lists — a floor sweep that passes because it looks at nothing.
    @Test func everyLineRendersAtLeastOneSentenceThroughItsSubject() {
        for child in Mirror(reflecting: GameText()).children {
            guard let label = child.label, let line = child.value as? any StockLine else {
                continue
            }
            #expect(!line.samples.isEmpty, "`GameText.\(label)` renders no sentences.")
            #expect(
                line.samples.allSatisfy { !$0.isEmpty },
                "`GameText.\(label)` renders an empty sentence.")
        }
    }
}

/// The lines whose whole content is what they were handed.
///
/// `Line` is `ExpressibleByStringLiteral` only where the subject is a
/// ``DroppableSubject``, so `text.unknownWord = "Eh?"` does not compile. That is
/// the half of #255 the compiler enforces and a test cannot: what a test *can*
/// pin is that the engine's own wording for each of them actually quotes its
/// subject, since a line that names nothing is what the gate exists to prevent.
struct UndroppableSubjectTests {
    @Test func everyLineAboutAWordQuotesTheWord() {
        let text = GameText()
        #expect(text.unknownWord("frotz").contains("frotz"))
        #expect(text.noReferent("them").contains("them"))
        #expect(text.multipleNotAllowedWith("eat").contains("eat"))
    }

    @Test func everyPromptNamesTheVerbItIsWaitingOn() {
        let text = GameText()
        #expect(text.missingObject("take") == "What do you want to take?")
        #expect(
            text.missingIndirect("put", "the coin", "in") == "What do you want to put the coin in?")
        #expect(
            text.missingTopic("ask", "the troll", "about")
                == "What do you want to ask the troll about?")
        // The optional halves: a topic verb with no object and no preposition.
        #expect(text.missingTopic("mutter", nil, "") == "What do you want to mutter?")
        #expect(
            text.missingDirection("push", "the rock") == "Which way do you want to push the rock?")
    }

    @Test func theRemainingSubjectsPrintWhatTheyWereHanded() {
        let text = GameText()
        #expect(text.ambiguous(["the lamp", "the lantern"]) == "Which do you mean: the lamp or the lantern?")
        #expect(text.banner("Zork", "").contains("Zork"))
        #expect(text.banner("Zork", "Underground").contains("Underground"))
        #expect(text.scoreLine(7, 350, 1) == "Your score is 7 of a possible 350, in 1 turn.")
        // No maximum declared, and more than one turn: both conditionals off.
        #expect(text.scoreLine(7, 0, 12) == "Your score is 7, in 12 turns.")
    }
}

/// ``GameText/Noun/list(_:)`` — several things as one, carrying the number the
/// whole phrase has.
///
/// The number is the point. A list is plural two ways, and the engine used to
/// know only one of them: it counted, so one plural thing in a box printed "In
/// the hamper is some scales." The rule lived in that line's body, where every
/// game re-voicing the line would have had to re-derive it. (#253)
struct ListNounTests {
    static let coin = GameText.Noun("a gold coin")
    static let scales = GameText.Noun("some scales", plural: true)

    @Test func oneSingularThingIsSingular() {
        #expect(GameText.Noun.list([Self.coin]).isPlural == false)
    }

    /// The case counting gets wrong, and the reason the helper exists.
    @Test func oneThingThatIsItselfPluralIsPlural() {
        #expect(GameText.Noun.list([Self.scales]).isPlural == true)
    }

    @Test func severalSingularThingsArePlural() {
        #expect(GameText.Noun.list([Self.coin, Self.coin]).isPlural == true)
    }

    /// No stock line calls one with nothing in it — they all branch on empty
    /// first — but reading as singular would be the same defect one case out.
    @Test func nothingIsPluralAndReadsAsNothing() {
        let empty = GameText.Noun.list([])
        #expect(empty.isPlural == true)
        #expect(empty.phrase.isEmpty)
    }

    @Test func thePhraseIsTheEnglishList() {
        #expect(GameText.Noun.list([Self.coin, Self.scales]).phrase == "a gold coin and some scales")
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

/// The claim #253 was filed on: a game re-voicing a line about a container and
/// its contents inherits the agreement rather than re-deriving it.
///
/// ``ListVoiceLab``'s templates count nothing and know nothing about lists. If
/// they still agree, the grammar is where it belongs.
struct ListVoiceTests {
    /// One session, four cases: the singular control, one thing that is itself
    /// plural, several things, and the line with no verb to agree — which is
    /// what shows the contents arrive already joined.
    @Test func aReVoicedLineInheritsTheAgreementItNeverWrote() async throws {
        let transcript = try await play(
            ListVoiceLab(), ["search bowl", "search hamper", "open crate", "search crate"])
        expectInOrder(
            transcript,
            [
                // Singular: a template that hard-coded "sit" dies here.
                "Inside the clay bowl, sits a ripe pear.",
                // One thing, itself plural — the case counting gets wrong.
                "Inside the wicker hamper, sit some lead weights.",
                // No verb to agree, so what this proves is the joining.
                "The pine crate gives up a red apple and a wax candle.",
                // Several things.
                "Inside the pine crate, sit a red apple and a wax candle.",
            ])
    }
}

/// How many times ``VoiceLab``'s computed `text` has been built. The number is
/// stamped into the lines themselves, so a line can say which build it came
/// from — which is the only way to tell a stored table from a rebuilt one that
/// happens to say the same words.
private let voiceBuilds = Atomic(0)

/// A bundle whose rules answer in the *host game's* stock voice.
///
/// A ``GameContent`` declares no `text` of its own, so before ``gameText``
/// there was no way for one to reach the game's lines at all and bundles
/// re-typed the host's wording by hand.
private struct VoiceCellar: GameContent {
    let vault = Location {
        name("Vault")
        description("A stone vault under the house.")
    }

    let locker = Item {
        name("tin locker")
        adjectives("tin")
        openable
    }

    var map: WorldMap {
        locker.starts(in: vault)
    }

    var rules: Rules {
        locker.before(.close) {
            try require(locker.isOpen, else: gameText.alreadyClosed())
            locker.isOpen = false
            try reply("The locker clicks shut.")
        }
    }
}

/// A game with the ordinary *computed* `text`, re-voicing two lines and
/// stamping each with the build it came from.
///
/// Three things read those lines on the way through: the engine's own default
/// action (through `crate`, which has no rules), a rule in the game
/// (`hatch`), and a rule in a bundle (`locker`). All three must show the same
/// build number, because there is only supposed to be one table.
private struct VoiceLab: Game {
    let title = "Voice"
    let intro = "A vault with three lids."

    let cellar = VoiceCellar()

    let hatch = Item {
        name("iron hatch")
        adjectives("iron")
        openable
    }

    /// No rules at all, so its OPEN and CLOSE are the engine's own and its
    /// refusals come from the table the engine is holding.
    let crate = Item {
        name("pine crate")
        adjectives("pine")
        openable
        startsOpen
    }

    var content: GameContents {
        cellar
    }

    var text: GameText {
        let build = voiceBuilds.wrappingAdd(1, ordering: .relaxed).newValue
        var text = GameText()
        text.alreadyOpen = "It is already open. (build \(build))"
        text.alreadyClosed = "It is already closed. (build \(build))"
        return text
    }

    var rules: Rules {
        hatch.before(.open) {
            try require(!hatch.isOpen, else: gameText.alreadyOpen())
            hatch.isOpen = true
            try reply("The hatch swings up.")
        }
    }

    var map: WorldMap {
        hatch.starts(in: cellar.vault)
        crate.starts(in: cellar.vault)
        player.starts(in: cellar.vault)
    }
}

/// ``gameText`` — the stock lines a rule body answers in, read off the
/// definition the engine is already using rather than rebuilt from the game's
/// own computed property. (#256)
struct GameVoiceTests {
    /// The build number stamped into every re-voiced line in one transcript.
    private func builds(in transcript: String) -> [Substring] {
        transcript.split(separator: "(build ").dropFirst().map { chunk in
            chunk.prefix { $0.isNumber }
        }
    }

    /// The whole claim in one session: the engine's own refusal, a rule's, and
    /// a bundle rule's all quote the same build of the table.
    ///
    /// Comparing the stamps rather than counting the builds is what makes this
    /// independent of how many other tests in the process have booted the same
    /// game — the question is never "how many tables exist" but "is the one the
    /// rule read the one the engine is speaking from".
    @Test func everyReaderQuotesTheSameTable() async throws {
        let transcript = try await play(
            VoiceLab(),
            [
                // The engine's own default actions, no rule involved.
                "open crate", "close crate", "close crate",
                // A rule in the game.
                "open hatch", "open hatch",
                // A rule in a content bundle, which has no `text` of its own.
                "open locker", "close locker", "close locker",
            ])

        // The words, in order, so a failure says which reader went wrong and
        // not merely that the numbers disagreed.
        expectInOrder(
            transcript,
            [
                "It is already open. (build",  // the engine's own `open`
                "It is already closed. (build",  // the engine's own `close`
                "The hatch swings up.",
                "It is already open. (build",  // a rule in the game
                "The locker clicks shut.",
                "It is already closed. (build",  // a rule in a bundle
            ])

        // …and the numbers, which is where a rebuilt table gives itself away.
        // The four stamps above are one build or the reader that disagreed was
        // reading its own copy.
        #expect(Set(builds(in: transcript)).count == 1)

        // No reader fell through to the engine's own wording, which is the way
        // this could pass by saying nothing at all.
        #expect(!transcript.contains("That's already open."))
        #expect(!transcript.contains("That's already closed."))
    }

    /// `stockFragment` is the other half of the same idea, for the lines a game
    /// asserts it never falls through to. A fragment that matched nothing would
    /// make every caller pass silently, so the two shapes are pinned by hand:
    /// a line about nothing is its own sentence, and a line that names its
    /// subject keeps whichever end the noun does not eat.
    @Test func aStockLineRendersToTheWordsNoSubjectCanVary() {
        let text = GameText()

        // `Line<Nothing>` — one sample, and the fragment is all of it.
        #expect(stockFragment(of: text.cantTurnOnThat) == "You can't turn that on.")

        // `Line<Noun>` with the noun at the end: the prefix survives.
        #expect(stockFragment(of: text.cantEnterThat) == "You can't get into the ")

        // And with the noun at the front, where number agreement eats the
        // prefix down to "The ", the suffix is the longer invariant.
        #expect(stockFragment(of: text.stubs.pull) == "n't budge.")

        // Every fragment is non-empty, or a caller naming that line asserts
        // nothing at all.
        for (label, line) in Mirror(reflecting: text).children
        where line is any StockLine {
            #expect(!stockFragment(of: line as! any StockLine).isEmpty, "\(label ?? "?")")
        }
    }
}
