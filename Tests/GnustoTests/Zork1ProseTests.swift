import Gnusto
import GnustoTestSupport
import Testing

@testable import Zork1

/// Zork 1's prose, where prose is the subject rather than the mechanic behind
/// it. Today that is the stub-verb floor (#242).
@Suite("Zork 1 prose")
struct Zork1ProseTests {
    // MARK: - The floor speaks in Zork I's voice (#242)

    /// **The sweep, and the only assertion here that cannot go stale.** Every
    /// other test below names one verb; a forty-eighth stub arriving in the
    /// engine tomorrow would slip past all of them. The shared helper derives
    /// its own completeness from ``GameText/StubReplies``, so it fails the
    /// moment one is added rather than letting the new line go unvoiced.
    @Test func noEngineStubLineSurvivesInZork1() {
        expectNoEngineStubLineSurvives(in: Zork1().text.stubs, game: "Zork 1")
    }

    /// The lines a player is most likely to try on purpose, taken verbatim from
    /// `gverbs.zil` and reaching the player through the real pipeline rather
    /// than through the table above — which proves the floor is *installed*, not
    /// merely written.
    @Test func theFamousRepliesAreTheSourcesOwn() async throws {
        let transcript = try await play(
            Zork1(), ["yell", "curse", "wish", "stand", "jump", "kiss mailbox", "swim"])
        expectInOrder(
            transcript,
            [
                // `V-YELL` (gverbs.zil:1616)
                "Aaaarrrrgggghhhh!",
                // `V-CURSES` (gverbs.zil:382)
                "Such language in a high-class establishment like this!",
                // `V-WISH` (gverbs.zil:1613)
                "With luck, your wish will come true.",
                // `V-STAND` (gverbs.zil:1309) — first person, and it stays
                "You are already standing, I think.",
                // `V-SKIP`'s `WHEEEEE` (gverbs.zil:1272)
                "Wheeeeeeeeee!!!!!",
                // `V-KISS` (gverbs.zil:763) — likewise first person
                "I'd sooner kiss a pig.",
                // `V-SWIM` (gverbs.zil:1345)
                "Go jump in a lake!",
            ])
    }

    /// The naming half of #242: four of the source's lines are jokes *about the
    /// thing named*, and no `action(…)` row could tell one object from another.
    @Test func theSensesNameWhatTheyAreAimedAt() async throws {
        let transcript = try await play(
            Zork1(), ["smell mailbox", "listen to mailbox", "touch mailbox", "wake mailbox"])
        expectInOrder(
            transcript,
            [
                // `V-SMELL` (gverbs.zil:1279)
                "It smells like the small mailbox.",
                // `V-LISTEN` (gverbs.zil:853)
                "The small mailbox makes no sound.",
                // `V-RUB` via `HACK-HACK` (gverbs.zil:1165, :2029)
                "Fiddling with the small mailbox has no effect.",
                // `V-ALARM` (gverbs.zil:168)
                "The small mailbox isn't sleeping.",
            ])
    }

    /// And the other half of the same widening: the bare rows, which the source
    /// has no verb for at all, keep a sentence of this game's own.
    @Test func theNamelessRowsStillAnswer() async throws {
        let transcript = try await play(Zork1(), ["smell", "listen", "wave", "wake"])
        expectInOrder(
            transcript,
            [
                "You smell nothing you could put a name to.",
                "You hear nothing you didn't hear before.",
                "Waving your hands about has no effect.",
                "Nothing here is asleep.",
            ])
    }

    /// What the floor buys back. An `action(…)` row returns from
    /// `DefaultActions.run` *before* `requireReach`, so every stub this game
    /// re-skinned had quietly given up the reach guard; assigning the line keeps
    /// it. The bottle is shut, so the water inside is visible and nameable but
    /// out of reach — and `squeeze` must now refuse for reach rather than
    /// shrugging its stock line.
    @Test func theFloorKeepsTheReachGuardTheRowsGaveAway() async throws {
        let transcript = try await play(
            Zork1(),
            ["north", "east", "open window", "enter house", "take bottle", "squeeze water"])
        #expect(turnOutput(of: "squeeze water", in: transcript).contains("can't reach"))
        #expect(!turnOutput(of: "squeeze water", in: transcript).contains("singularly useless"))
    }

    /// The melee plugin claims `.attack` for the whole game, so its refusals —
    /// not the floor's `attack` — are what a player who swings at the scenery
    /// reads. They were the plugin's stock modern lines until #242.
    @Test func swingingAtTheSceneryGetsVAttacksOwnWords() async throws {
        let transcript = try await play(Zork1(), ["attack mailbox"])
        // `V-ATTACK`'s first branch (gverbs.zil:178), indefinite as the
        // source's `A ,PRSO` is.
        expectInOrder(transcript, ["I've known strange people, but fighting a small mailbox?"])
    }

    /// `V-KNOCK` (`gverbs.zil:765`) branches on `DOORBIT`, and both branches
    /// answer here. The front door is boarded and the window is an exit, so the
    /// two halves of ``Item/isDoor`` are both exercised; the mailbox is the
    /// branch that names what was knocked on. (#247)
    @Test func knockingTellsADoorFromEverythingElse() async throws {
        let transcript = try await play(
            Zork1(),
            ["knock on door", "knock on mailbox", "north", "east", "knock on window"])
        #expect(turnOutput(of: "knock on door", in: transcript).contains("Nobody's home."))
        #expect(turnOutput(of: "knock on window", in: transcript).contains("Nobody's home."))
        // The source writes "Why knock on a " D ,PRSO "?" — an indefinite
        // article the engine's named stub lines do not deal in. See FIDELITY.md.
        #expect(
            turnOutput(of: "knock on mailbox", in: transcript)
                .contains("Why knock on the small mailbox?"))
    }

    // MARK: - Lines that used to claim a frame they never read (#325)

    /// `V-HELLO` (`gverbs.zil:724`) has three branches and this game had one: a
    /// custom `hello` verb whose `action(…)` row answered "Nobody here returns
    /// your greeting." from a table that could not see the room. The troll is
    /// standing in it. The verb is the engine's `.greet` now — ``ZorkSystems``
    /// contributes only the two bare words — so all four frames answer, and the
    /// two that name somebody answer in the source's words.
    @Test func helloReadsWhoIsInTheRoom() async throws {
        let transcript = try await play(
            Zork1(),
            [
                "hello",  // West of House: nobody about, so `HELLOS` answers
                "hello mailbox",  // not a person
                "south", "east", "open window", "west", "west",
                "take sword", "take lantern", "turn on lantern",
                "push rug", "open trap door", "down", "north",  // → Troll Room
                "hi",  // bare, and the one person in the room is who it reaches
                "hello troll",  // named, same branch
            ],
            seed: 39)
        expectInOrder(
            transcript,
            [
                // `HELLOS` (`gverbs.zil:2199`), first of four.
                "Hello.",
                // `V-HELLO`'s non-actor branch (`:731`).
                "It's a well known fact that only schizophrenics say \"Hello\" to the small mailbox.",
                "Troll Room",
                // `V-HELLO`'s actor branch (`:727`), reached twice: the engine
                // resolves a bare greeting to the one person in earshot, so the
                // troll answers whether or not he is named.
                "The troll bows his head to you in greeting.",
                "The troll bows his head to you in greeting.",
            ])
        #expect(!transcript.contains("Nobody here returns your greeting"))
        // And the engine's own stock greeting lines are gone with it.
        #expect(!transcript.contains("nods, and says nothing"))
        #expect(!transcript.contains("unlikely to answer"))
    }

    /// `buy` is an invention — `gsyntax.zil` has no such verb — and the line it
    /// carried said "This is a dungeon, not a bazaar!" in the open field the
    /// game starts in, four rooms above the nearest dungeon. Both frames: the
    /// field, and the cellar the old line was written for.
    @Test func buyingDoesNotAnnounceWhereYouAreStanding() async throws {
        let transcript = try await play(
            Zork1(),
            [
                "buy house",  // West of House, above ground
                "south", "east", "open window", "west", "west",
                "take lantern", "turn on lantern",
                "push rug", "open trap door", "down",  // → Cellar
                "buy lamp",
            ])
        #expect(!transcript.contains("This is a dungeon"))
        #expect(
            occurrences(of: "You're not in a bazaar, and I'm not a merchant.", in: transcript) == 2)
    }

    // MARK: - Listing sentences that were standing in for examine texts

    /// `NEST`'s `FDESC`, `EGG`'s `FDESC` and `LEAVES`'s `LDESC` are all
    /// **listing** lines in `1dungeon.zil`, and all three were declared as the
    /// examine text. So Up a Tree named no nest, the Clearing listed nothing at
    /// all — losing the only hint that there is something here to push — and
    /// `x egg` told a player holding the egg it was still in the nest.
    @Test func theListingLinesListAndTheExamineTextsExamine() async throws {
        let transcript = try await play(
            Zork1(),
            [
                "north", "north", "up", "take egg", "examine egg", "look",
                "down", "north", "x leaves", "push leaves", "x grate",
            ])

        let perch = turnOutput(of: "up", in: transcript)
        #expect(perch.contains("Beside you on the branch is a small bird's nest."))
        #expect(perch.contains("In the bird's nest is a large egg encrusted"))
        #expect(!transcript.contains("On the nest is a jewel-encrusted egg."))

        // In the hand, the egg's own text — and not a claim about the nest.
        let inHand = turnOutput(of: "examine egg", in: transcript)
        #expect(inHand.contains("A large egg encrusted with precious jewels"))
        #expect(!inHand.contains("In the bird's nest is"))

        // The nest's line goes on printing; the egg's stops once it is touched.
        let after = turnOutput(of: "look", in: transcript)
        #expect(after.contains("Beside you on the branch is a small bird's nest."))
        #expect(!after.contains("large egg encrusted"))

        // The Clearing lists its leaves, and examining answers about them.
        #expect(turnOutput(of: "x leaves", in: transcript).contains("Dead leaves, drifted deep"))
        #expect(!turnOutput(of: "x leaves", in: transcript).contains("On the ground is a pile"))
        #expect(turnOutput(of: "push leaves", in: transcript).contains("grating is revealed"))
        // And `grate` is a noun at last: `SYNONYM GRATE GRATING`, undeclared.
        #expect(turnOutput(of: "x grate", in: transcript).contains("A sturdy iron grating"))
    }

    /// `WHITE-HOUSE-F` answers `THROUGH` itself (`1actions.zil:117`): from
    /// behind the house an open window walks you into the Kitchen and a shut one
    /// says so, and from any other side there is no way in. Without that branch
    /// `enter house` fell to `V-THROUGH`'s generic head-butt from every side.
    @Test func enterHouseIsWhiteHouseFsOwnBranch() async throws {
        let transcript = try await play(
            Zork1(),
            [
                "enter house",  // West of House: no way in from this side
                "north", "east",  // round to Behind House
                "go through house",  // still shut
                "open window",
                "enter house",  // and now it walks
                "take bottle",
            ])

        expectInOrder(
            transcript,
            [
                "I can't see how to get in from here.",
                "Behind House",
                "The window is closed.",
                "Opened.",
                "Kitchen",
            ])
        // Really in the kitchen, not merely told about it.
        #expect(turnOutput(of: "take bottle", in: transcript).contains("Taken."))
        #expect(!transcript.contains("hit your head against the white house"))
    }
}
