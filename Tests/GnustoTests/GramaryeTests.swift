import Foundation
import Gnusto
import GnustoTestSupport
import Testing

@testable import Gramarye

/// End-to-end play of the spellcasting demo: the win path threads all four
/// casting paradigms — cantrip (glow), memorized (unbar), scroll (passwall),
/// and energy (firebolt) — and the surrounding tests pin each paradigm's
/// refusal and consumption behavior in the real game.
struct GramaryeTests {
    /// The book in hand and the warded door open again: the state every walk
    /// past the first gate starts from.
    static let toTheGallery = ["take spellbook", "memorize unbar", "cast unbar", "west"]

    /// Standing in the gallery with the granite turned to mist, which needs the
    /// scroll the cantrip finds. Routes derive from routes, so a change to the
    /// first gate lands everywhere at once.
    static let toTheMist = [
        "take spellbook", "cast glow", "take scroll",
        "memorize unbar", "cast unbar", "west", "cast passwall",
    ]

    /// And through it.
    static let toTheUndercroft = toTheMist + ["north"]

    @Test func theFullWalkthroughRecoversTheAmulet() async throws {
        let transcript = try await play(
            Gramarye(),
            [
                "take spellbook",
                "cast glow",  // cantrip reveals the hidden scroll
                "take passwall scroll",
                "memorize unbar",  // prepared, needs the spellbook in hand
                "cast unbar",  // opens the warded door
                "west",
                "cast passwall",  // scroll opens the granite wall
                "north",
                "cast firebolt at golem",  // energy destroys the guardian
                "take amulet",
            ],
            // No random draws today; pinned so the walkthrough in
            // `docs/games/gramarye.md` replays exactly if the game ever grows one.
            seed: 0)

        expectInOrder(
            transcript,
            [
                "in the niche it finds a rolled parchment",
                "You fix the unbar spell in your memory.",
                "the door drifts open",
                "The Long Gallery",
                "the granite before you turns to a soft grey mist",
                "The Undercroft",
                "it slumps to rubble, and behind it the amulet gleams",
                "You lift the master's amulet",
                "Your score is 10 of a possible 10",
            ])
    }

    @Test func glowIsAnAtWillCantripThatFindsNothingOnceTheNicheIsEmpty() async throws {
        let transcript = try await play(Gramarye(), ["cast glow", "cast glow"])
        expectInOrder(
            transcript,
            [
                "in the niche it finds a rolled parchment",
                "there is nothing hidden here to find",  // free to recast, but nothing left
            ])
    }

    @Test func castingUnbarBeforeMemorizingItIsRefused() async throws {
        let transcript = try await play(Gramarye(), ["cast unbar"])
        #expect(transcript.contains("You don't have the unbar spell prepared."))
    }

    @Test func memorizingUnbarNeedsTheSpellbookInHand() async throws {
        // The spellbook starts on the desk, where the intro says it is — in the
        // room, in reach, and not held.
        let transcript = try await play(Gramarye(), ["memorize unbar", "take spellbook", "memorize unbar"])
        expectInOrder(
            transcript,
            [
                "You need your spellbook in hand to memorize unbar.",
                "You fix the unbar spell in your memory.",
            ])
    }

    @Test func fireboltWashesOffAnIncombustibleTarget() async throws {
        let transcript = try await play(Gramarye(), ["take spellbook", "cast firebolt at spellbook"])
        #expect(transcript.contains("The firebolt washes over the spellbook and leaves it untouched."))
    }

    @Test func theWardedDoorResistsAnOrdinaryOpen() async throws {
        // The door starts open with its wards dormant; it only resists an
        // ordinary hand once the draught has sealed it a couple of turns in.
        let transcript = try await play(
            Gramarye(), ["examine window", "examine niche", "open warded door"])
        #expect(transcript.contains("The warding-marks hold the door fast"))
    }

    // MARK: - Clueing and dynamic descriptions

    @Test func theSpellbookOffersOneAccidentPerObstacle() async throws {
        // Each read serves the current obstacle: the apprentice looks for
        // what he thinks he needs and stumbles on what the player needs.
        let transcript = try await play(
            Gramarye(),
            [
                "take spellbook",
                "examine niche",  // let the draught seal the door first
                "read spellbook",  // doors? no — a nightlight
                "cast glow", "take scroll",
                "read spellbook",  // doors again — unbar, with small print
                "memorize unbar", "cast unbar", "west",
                "read spellbook",  // walls — nothing but a receipt
                "cast passwall", "north",
                "read spellbook",  // golems — pottery
                "cast firebolt at golem",
                "read spellbook",  // nothing left
                "take amulet",
            ])
        expectInOrder(
            transcript,
            [
                "a cantrip called glow",
                "unbar, the unbinding",
                "one parchment, best quality",
                "a spell related to pottery",
                "nothing to teach you",
            ])
    }

    @Test func theSpellbookNeverReadsAhead() async throws {
        // Once the door has sealed, the first read gives away only the
        // finding-light — nothing about the spells further down the chain.
        let transcript = try await play(
            Gramarye(), ["examine window", "examine niche", "read spellbook"])
        #expect(transcript.contains("a cantrip called glow"))
        #expect(!transcript.contains("unbar"))
        #expect(!transcript.contains("firebolt"))
        #expect(!transcript.contains("pottery"))
    }

    /// All four states, and the fourth is the one that was missing: the scroll
    /// is `vanish()`ed by the reading, and the old ladder asked only whether it
    /// was *held*, so a spent scroll fell into the branch written for "revealed
    /// and not yet picked up" and re-advertised a parchment that was ash.
    @Test func theNicheKeepsItsSecretUntilGlow() async throws {
        let transcript = try await play(
            Gramarye(),
            [
                "examine niche", "cast glow", "examine niche", "take scroll", "examine niche",
                "take spellbook", "memorize unbar", "cast unbar", "west", "cast passwall",
                "east", "examine niche",
            ])
        expectInOrder(
            transcript,
            [
                "no unaided eye will find it",
                "in the niche it finds a rolled parchment",
                "a rolled parchment rests in the niche",
                "What it kept, you carry now",
                "the shadow has gone back to keeping nothing",
            ])
    }

    /// The niche is a `container` and the scroll is genuinely in it, so the
    /// three ways of asking agree: the room listing, `x niche`, and `search`.
    @Test func theNicheHoldsTheScrollAndSaysSo() async throws {
        let transcript = try await play(
            Gramarye(), ["cast glow", "look", "search niche", "look in niche", "examine niche"])

        // The listing puts it in the niche, not loose on the study floor.
        #expect(turnOutput(of: "look", in: transcript).contains("In the shadowed niche is a passwall scroll"))
        #expect(!transcript.contains("There is a passwall scroll here"))
        // And `search` no longer refuses what the description advertises.
        #expect(turnOutput(of: "search niche", in: transcript).contains("passwall scroll"))
        #expect(turnOutput(of: "look in niche", in: transcript).contains("passwall scroll"))
        #expect(!transcript.contains("You find nothing of interest"))
    }

    @Test func theDoorAndStudyShowTheUnbarringWhenItIsDone() async throws {
        let transcript = try await play(
            Gramarye(),
            ["take spellbook", "memorize unbar", "cast unbar", "examine door", "look"])
        expectInOrder(
            transcript,
            [
                "the door drifts open",
                "The warding-marks are dark and dead.",
                "stands open, its warding-marks dark",
            ])
    }

    @Test func theGalleryShowsTheMistArchAfterPasswall() async throws {
        let transcript = try await play(
            Gramarye(),
            [
                "take spellbook", "cast glow", "take scroll",
                "memorize unbar", "cast unbar", "west",
                "cast passwall", "look",
            ])
        expectInOrder(
            transcript,
            [
                "the passage is stopped by a blank wall of dressed granite",
                "an archway of grey mist breathes cellar-cold air",
            ])
        // Both gallery states point the way home correctly.
        #expect(transcript.contains("The way east runs back to the study"))
    }

    @Test func failedOpensPointTowardTheMagic() async throws {
        let transcript = try await play(
            Gramarye(),
            [
                "examine window", "examine niche",  // let the door seal first
                "open door",
                "take spellbook", "memorize unbar", "cast unbar", "west",
                "open wall",
            ])
        expectInOrder(
            transcript,
            [
                "the master's book would know the word",
                "stone keeps other laws than doors do",
            ])
    }

    @Test func spellIsFillerInACastingCommand() async throws {
        // The spellcasting layer adds "spell" to the noise words, so natural
        // phrasings parse the same as the bare verbs.
        let transcript = try await play(
            Gramarye(),
            ["cast the glow spell", "take spellbook", "memorize the unbar spell"])
        expectInOrder(
            transcript,
            [
                "in the niche it finds a rolled parchment",
                "You fix the unbar spell in your memory.",
            ])
    }

    @Test func passwallAwayFromTheWallRefusesAndKeepsTheScroll() async throws {
        let transcript = try await play(
            Gramarye(),
            [
                "take spellbook", "cast glow", "take scroll",
                "cast passwall",  // in the study: no stone here — scroll kept
                "memorize unbar", "cast unbar", "west",
                "cast passwall",  // the kept scroll still works at the wall
            ])
        expectInOrder(
            transcript,
            [
                "the working wants a wall of stone before you, and there is none here",
                "the granite before you turns to a soft grey mist",
            ])
    }

    @Test func glowFindsNothingOutsideTheStudy() async throws {
        let transcript = try await play(
            Gramarye(),
            [
                "take spellbook", "memorize unbar", "cast unbar", "west",
                "cast glow",  // the scroll hides in the study, not here
                "east", "examine niche",
            ])
        expectInOrder(
            transcript,
            [
                "there is nothing hidden here to find",
                "no unaided eye will find it",  // still unrevealed back home
            ])
    }

    // MARK: - The new premise: a door that seals itself

    @Test func theDoorSealsItselfAFewTurnsIn() async throws {
        // The door starts open and dormant; a draught seals it a couple of
        // turns in, and that slam is the moment the puzzle actually begins.
        let transcript = try await play(
            Gramarye(), ["examine window", "examine niche", "look"])
        #expect(transcript.contains("meets its frame with a boom"))
        // Before the slam the study shows the open, dormant door; after it,
        // the shut one.
        expectInOrder(
            transcript,
            [
                "stands open, its warding-marks dark",  // opening look
                "meets its frame with a boom",  // the seal
                "stands shut in the west wall",  // the look after
            ])
    }

    @Test func theSpellbookHasNothingToSayBeforeTheSeal() async throws {
        // Read before the draught catches the door and the book agrees that
        // nothing is wrong — no spell clue is handed out yet.
        let transcript = try await play(Gramarye(), ["take spellbook", "read spellbook"])
        #expect(transcript.contains("Nothing is currently wrong"))
        #expect(!transcript.contains("a cantrip called glow"))
    }

    @Test func mindingTheTowerMeansNotLeavingIt() async throws {
        // The apprentice was left to mind the tower; the road is refused.
        let transcript = try await play(Gramarye(), ["out", "down"])
        #expect(transcript.contains("A tower cannot be minded from the road"))
    }

    @Test func theStudyWindowIsTheQuietCulprit() async throws {
        // Hiding in plain sight for replayers: the open window whose draught
        // does the sealing.
        let transcript = try await play(Gramarye(), ["examine window"])
        #expect(transcript.contains("the least suspicious thing in the tower"))
    }

    @Test func theMasterReturnsAndLaughsWhenTheAmuletIsTaken() async throws {
        // The win is a scene: the master steps through his own dispersed wall,
        // names the window as the culprit, and — to your relief — laughs.
        let transcript = try await play(
            Gramarye(),
            [
                "take spellbook",
                "cast glow", "take passwall scroll",
                "memorize unbar", "cast unbar", "west",
                "cast passwall", "north",
                "cast firebolt at golem", "take amulet",
            ])
        expectInOrder(
            transcript,
            [
                "You lift the master's amulet",
                "\"The window,\" he says",
                "he begins — quite helplessly — to laugh",
                "Your score is 10 of a possible 10",
            ])
        // The other half of the ending's one branch: this walk leaves the door
        // open, and the inventory says so.
        #expect(transcript.contains("the warded door unbound"))
    }

    // MARK: - Neither barrier can be shut into an unwinnable game (#98)

    /// Two commands used to end the game silently: `west`, `close door` left the
    /// apprentice in the gallery with both exits shut and the book on the far
    /// side of one of them. He declines.
    @Test func theWardedDoorRefusesToShutOnTheBook() async throws {
        let transcript = try await play(Gramarye(), ["west", "close door", "east"], seed: 0)

        #expect(
            turnOutput(of: "close door", in: transcript)
                .contains("the master's book is on the wrong side of it"))
        // Refused, so the way home is still open.
        #expect(turnOutput(of: "east", in: transcript).contains("The Study"))
    }

    /// The same refusal from the other side, which is the same softlock: the
    /// book left in the gallery and the door shut on the study.
    @Test func theDoorWillNotBeShutOnABookLeftInTheGallery() async throws {
        let transcript = try await play(
            Gramarye(),
            Self.toTheGallery + ["drop spellbook", "east", "close door"],
            seed: 0)

        #expect(
            turnOutput(of: "close door", in: transcript)
                .contains("the master's book is on the wrong side of it"))
    }

    /// And with the book in hand it closes, the wards catch, and `unbar` — which
    /// is repeatable, one door per sitting — gets him back through. That is what
    /// makes the close survivable rather than fatal.
    @Test func shuttingTheDoorWithTheBookInHandIsSurvivable() async throws {
        let transcript = try await play(
            Gramarye(),
            Self.toTheGallery + ["close door", "memorize unbar", "cast unbar", "east"],
            seed: 0)

        expectInOrder(
            transcript,
            [
                "The warding-marks take light and settle into a steady burn",
                "the door drifts open",
                "The Study",
            ])
    }

    /// The granite refuses outright, because `passwall` is the only thing that
    /// can reopen it and the scroll is ash by the time anybody could try.
    @Test func theMistCannotBeClosedBehindYou() async throws {
        let transcript = try await play(
            Gramarye(),
            Self.toTheMist + ["close wall", "north"],
            seed: 0)

        #expect(
            turnOutput(of: "close wall", in: transcript)
                .contains("it did not leave you anything to take hold of"))
        #expect(turnOutput(of: "north", in: transcript).contains("The Undercroft"))
    }

    /// The fuse used to narrate a slam over a door the player had shut with his
    /// own hands, insisting "You touched nothing" — and the book's ladder,
    /// keyed on the flag only the fuse wrote, went on saying nothing was wrong.
    @Test func theFuseStandsDownIfTheApprenticeShutsTheDoorHimself() async throws {
        let transcript = try await play(
            Gramarye(), ["take spellbook", "close door", "read spellbook", "wait", "wait"], seed: 0)

        #expect(!transcript.contains("meets its frame with a boom"))
        #expect(!transcript.contains("You touched nothing"))
        // The book knows the door is shut however it got shut.
        #expect(!transcript.contains("Nothing is currently wrong"))
        #expect(transcript.contains("a cantrip called glow"))
    }

    /// The ending inventories the world it is standing in, and the door is the
    /// one item of it the player can still change.
    @Test func theEndingNamesTheDoorItFinds() async throws {
        let transcript = try await play(
            Gramarye(),
            [
                "take spellbook", "cast glow", "take scroll", "memorize unbar", "cast unbar",
                "west", "close door", "cast passwall", "north", "cast firebolt at golem",
                "take amulet",
            ],
            seed: 0)

        #expect(transcript.contains("the warded door shut again and burning quietly to itself"))
        #expect(!transcript.contains("the warded door unbound"))
        #expect(transcript.contains("Your score is 10 of a possible 10"))
    }

    // MARK: - Lines that used to print in a frame they weren't true of (#101)

    /// `wardedDoor.before(.open)` has always had an `isOpen` guard and the
    /// granite hadn't, so the hint pointing at `passwall` went on being offered
    /// after the mage had unfit the stone and the scroll was ash.
    @Test func theOpenedGraniteStopsOfferingTheHint() async throws {
        let transcript = try await play(
            Gramarye(),
            Self.toTheMist + ["open wall"],
            seed: 0)

        #expect(turnOutput(of: "open wall", in: transcript).contains("There is nothing left here to open"))
        #expect(!transcript.contains("stone keeps other laws than doors do"))
    }

    /// The book files firebolt under the firing of kilns and notes that raw clay
    /// cannot abide it, so "You have no way to set fire to the clay golem" was
    /// the one thing the game could not say about the golem.
    @Test func burningTheGolemPointsAtTheFirebolt() async throws {
        let transcript = try await play(Gramarye(), Self.toTheUndercroft + ["burn golem"], seed: 0)

        #expect(turnOutput(of: "burn golem", in: transcript).contains("will have to come out of you"))
        #expect(!transcript.contains("You have no way to set fire to"))
    }

    /// `glow` can be cast without ever opening the book, so the rung that used
    /// to say "a second time … this time it relents" back-referenced a refusal
    /// the player never saw.
    @Test func theBookNeverClaimsAReadThatDidNotHappen() async throws {
        let transcript = try await play(
            Gramarye(), ["cast glow", "wait", "take spellbook", "read spellbook"], seed: 0)

        #expect(turnOutput(of: "read spellbook", in: transcript).contains("unbar, the unbinding"))
        #expect(!transcript.contains("a second time"))
        #expect(!transcript.contains("this time it relents"))
    }

    /// The refusal wrote its own definite article in front of `name`. The player
    /// item is called "yourself" and is a proper name, so `definiteName` is what
    /// keeps the line from reading "the yourself".
    @Test func fireboltAtYourselfDoesNotSayTheYourself() async throws {
        let transcript = try await play(Gramarye(), ["cast firebolt at me"], seed: 0)

        #expect(!transcript.contains("the yourself"))
        #expect(transcript.contains("The book is silent on apprentices who set fire to themselves"))
    }

    /// The one room that had a single state, described the same before and after
    /// the golem, never mentioned the way back, and never named the hook the
    /// ending says the amulet was lifted from.
    @Test func theUndercroftShowsTheRubbleOnceTheGolemIsGone() async throws {
        let transcript = try await play(
            Gramarye(), Self.toTheUndercroft + ["cast firebolt at golem", "look"], seed: 0)

        expectInOrder(
            transcript,
            [
                "an iron hook is driven into the stone at head height",
                "it slumps to rubble",
                "the floor wears an even layer of what used to be a golem",
            ])
        // The hook holds the amulet, so the listing agrees with the prose.
        #expect(transcript.contains("On the iron hook is a silver amulet"))
    }

    // MARK: - Every noun the tower prints (#99)

    /// The intro alone names thirteen things and the parser knew four of them.
    /// `desk` is the sharpest: the last sentence is the game's one instruction
    /// to the player, and the desk is the first thing they reach for.
    @Test func theIntroAnswersToEveryNounItPrints() async throws {
        let transcript = try await play(
            Gramarye(),
            [
                "x tower", "x master", "x desk", "x cloak", "x staff", "x letters",
                "x hat", "x circle", "x cauldrons", "x robes", "x hill", "x road",
            ],
            seed: 0)

        expectEveryNounAnswered(transcript)
        #expect(turnOutput(of: "x desk", in: transcript).contains("exactly the size of the book"))
    }

    /// The Study, whose description carries the noun the entire first puzzle is
    /// about. `x warding-marks` used to answer *I don't know the word "warding"*,
    /// because the tokenizer splits the hyphen the prose writes.
    @Test func theStudyAnswersToItsOwnDescription() async throws {
        let transcript = try await play(
            Gramarye(),
            [
                "x books", "x wall", "x candle", "x frame", "x warding-marks", "x wards",
                "x stone", "x inkwells", "x draught", "x window", "x niche", "x door",
            ],
            seed: 0)

        expectEveryNounAnswered(transcript)
        #expect(turnOutput(of: "x warding-marks", in: transcript).contains("Cut deep into the door's frame"))
    }

    /// The spellbook's own description and its six read rungs name eight parts
    /// of one book, and all eight answer with the book.
    @Test func theSpellbookAnswersToItsOwnPages() async throws {
        let transcript = try await play(
            Gramarye(),
            [
                "x pages", "x margins", "x notes", "x leather",
                "x index", "x receipt", "x bookmark", "x newts",
            ],
            seed: 0)

        expectEveryNounAnswered(transcript)
    }

    /// The gallery, and the mist archway that is the visible reward for solving
    /// the third puzzle and could not be looked at.
    @Test func theGalleryAnswersToItsOwnDescription() async throws {
        let standing = try await play(
            Gramarye(),
            Self.toTheGallery + ["x granite", "x wall", "x seams", "x passage", "x stone", "x air", "x gallery"],
            seed: 0)
        expectEveryNounAnswered(standing, "wall standing")

        let dispersed = try await play(
            Gramarye(),
            Self.toTheMist + ["x mist", "x archway", "x arch", "x wall"],
            seed: 0)
        expectEveryNounAnswered(dispersed, "wall dispersed")
        #expect(turnOutput(of: "x archway", in: dispersed).contains("soft grey mist"))
    }

    /// The Undercroft, and the hook the master shouts about from the threshold
    /// that the one room containing it did not know the word for.
    @Test func theUndercroftAnswersToItsOwnDescription() async throws {
        let transcript = try await play(
            Gramarye(),
            Self.toTheUndercroft
                + [
                    "x cellar", "x air", "x magic", "x hook", "x clay", "x golem", "x vault",
                    "cast firebolt at golem", "x rubble", "x shards", "x amulet",
                ],
            seed: 0)

        expectEveryNounAnswered(transcript)
        #expect(turnOutput(of: "x hook", in: transcript).contains("bent up at the tip"))
    }
}
