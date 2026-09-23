import GnustoTestSupport
import Testing

@testable import Gnusto
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

    /// The three description-mode verbs, where Zork I's wording and the
    /// engine's stock wording part company over one hyphen.
    ///
    /// `V-VERBOSE` and `V-BRIEF` (`gverbs.zil:13`, `:18`) are the stock lines
    /// already. `V-SUPER-BRIEF` (`:23`) writes *"Super-brief descriptions."*,
    /// where the engine follows the modern ZIL library and writes the word
    /// closed up — so Zork 1 sets the line back and this is what proves it
    /// reaches the player. See `FIDELITY.md`, "VERBOSE / BRIEF / SUPERBRIEF".
    @Test func theDescriptionModeRepliesAreTheSourcesOwn() async throws {
        let transcript = try await play(Zork1(), ["verbose", "superbrief", "brief"])
        expectInOrder(
            transcript,
            [
                "Maximum verbosity.",
                "Super-brief descriptions.",
                "Brief descriptions.",
            ])
        #expect(!transcript.contains("Superbrief descriptions."))
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

    /// **The postures, once they had something to do it on.** `stand on X` and
    /// `lie on X` are rows the table gained after this floor was written, and
    /// the floor's one-string answers went straight to them: `stand on the
    /// mailbox` replied "You are already standing, I think." — a line that
    /// claims the player is doing the thing he just asked to do — and `lie on
    /// the mailbox` replied with a sentence about the ground. Both halves now,
    /// and the verbatim ones are still the bare ones.
    @Test func thePosturesAnswerTheirObjectAndNotTheGround() async throws {
        let transcript = try await play(
            Zork1(), ["stand on mailbox", "lie on mailbox", "sit on mailbox", "stand", "lie"])
        expectInOrder(
            transcript,
            [
                "Standing on the small mailbox would accomplish nothing.",
                "Lying down on the small mailbox would only get you filthier.",
                // One sentence answers both halves of SIT, so it is unchanged.
                "You didn't come all this way to sit down!",
                // `V-STAND` (gverbs.zil:1309), still verbatim.
                "You are already standing, I think.",
                "You'd only get up again filthy.",
            ])
    }

    /// `lie in the mailbox` answered "Lying down on the small mailbox", because
    /// the line wrote ON itself. It takes the word from the row now.
    @Test func lyingInTheMailboxSaysIn() async throws {
        let turn = turnOutput(
            of: "lie in mailbox", in: try await play(Zork1(), ["lie in mailbox"]))
        #expect(turn.contains("Lying down in the small mailbox would only get you filthier."))
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

    /// The same class again, in the house (#514). `SANDWICH-BAG`, `BOTTLE`,
    /// `ROPE`, `KNIFE` and `SWORD` carry an `FDESC`; all five were declared as
    /// the examine text, so the Kitchen, the Living Room and the Attic listed
    /// their contents in the engine's stock words while `x sack` answered, from
    /// the player's own hand, with a sentence about a table two rooms away. None
    /// of the five has a `TEXT` property, so the examine channel is the stock
    /// line.
    @Test func theHousesListingLinesListAndExamineFallsThrough() async throws {
        let transcript = try await play(
            Zork1(),
            [
                "north", "east", "open window", "west",  // → Kitchen
                "take sack", "take bottle",
                "west", "take lantern", "turn on lantern", "east",  // Living Room, lit → Kitchen
                "up",  // → Attic
                "take rope", "take knife",
                "down", "west", "take sword",  // → Kitchen → Living Room
                "x sack", "x bottle", "x rope", "x knife", "x sword", "x lunch",
            ])

        let livingRoom = turnOutput(ofLast: "west", in: transcript)
        #expect(livingRoom.contains("Above the trophy case hangs an elvish sword of great antiquity."))

        let kitchen = turnOutput(of: "west", in: transcript)
        #expect(kitchen.contains("On the table is an elongated brown sack, smelling of hot peppers."))
        #expect(kitchen.contains("A bottle is sitting on the table."))

        let attic = turnOutput(of: "up", in: transcript)
        #expect(attic.contains("A large coil of rope is lying in the corner."))
        #expect(attic.contains("On a table is a nasty-looking knife."))

        // In hand, each answers about itself — which here means the stock line,
        // and never the sentence that just listed it in a room two floors down.
        for (command, noun, listing) in [
            ("x sack", "brown sack", "On the table is"),
            ("x bottle", "glass bottle", "sitting on the table"),
            ("x rope", "coil of rope", "in the corner"),
            ("x knife", "nasty knife", "On a table is"),
            ("x sword", "elvish sword", "Above the trophy case"),
        ] {
            let answer = turnOutput(of: command, in: transcript)
            #expect(answer.contains("There's nothing special about the \(noun)."))
            #expect(!answer.contains(listing))
        }
    }

    /// Each of those listing lines names where the thing stands, so the world
    /// has to put it there and the noun has to answer. The sack and the bottle
    /// stand on `KITCHEN-TABLE` and the knife on `ATTIC-TABLE`, as in the
    /// source; before this the three sat on the floor, and the Attic had no
    /// table at all, so `x table` there answered "You can't see any such
    /// thing." while the room had just said the knife was on one. (#514)
    @Test func theHousesTablesHoldWhatTheListingLinesSayTheyHold() async throws {
        let transcript = try await play(
            Zork1(),
            [
                "north", "east", "open window", "west",  // → Kitchen
                "x table", "take sack", "look",
                "west", "take lantern", "turn on lantern", "east",  // Living Room, lit → Kitchen
                "up",  // → Attic
                "x table", "take knife", "look",
            ])

        #expect(
            turnOutput(of: "x table", in: transcript)
                .contains("The table is a sturdy one, dusted with flour and scored with knife marks."))
        #expect(
            turnOutput(ofLast: "x table", in: transcript)
                .contains("The table is a plain one, and thick with the dust of the attic."))
        #expect(!transcript.contains("You can't see any such thing."))

        // Lifted off the table, each is listed by the engine's stock words and
        // no longer by a line about a table it is not on.
        let kitchenFloor = turnOutput(of: "look", in: transcript)
        #expect(!kitchenFloor.contains("On the table is an elongated brown sack"))
        let atticFloor = turnOutput(ofLast: "look", in: transcript)
        #expect(!atticFloor.contains("On a table is a nasty-looking knife."))
    }

    /// `LUNCH`'s one sentence is an `LDESC`, which the original prints only for
    /// a sandwich standing directly in a room. The sandwich starts in the sack,
    /// and taking it out is the first touch, so as `firstSight(…)` the line
    /// could print only for an untouched sandwich still in the sack — where the
    /// original lists it in its stock words instead. It is withdrawn, as
    /// Dungeon's was (#205); the sandwich is found by looking in the sack.
    @Test func theLunchHasNoListingLineItCouldNotPrint() async throws {
        let transcript = try await play(
            Zork1(),
            [
                "north", "east", "open window", "west",  // → Kitchen
                "look in sack", "x lunch",
            ])

        #expect(!transcript.contains("A hot pepper sandwich is here."))
        #expect(turnOutput(of: "look in sack", in: transcript).contains("lunch"))
        #expect(turnOutput(of: "x lunch", in: transcript).contains("There's nothing special about the lunch."))
    }

    /// The two treasures of the same class (#514). `PAINTING` and `SCEPTRE` each
    /// carry both an `FDESC` and an `LDESC`; the `LDESC` had been declared as the
    /// examine text, so a banked painting still claimed to be hanging in the
    /// Gallery. The `FDESC` is the listing line and the examine channel is the
    /// stock sentence, as in the original.
    @Test func theTreasuresListingLinesListAndExamineFallsThrough() async throws {
        let transcript = try await play(
            Zork1(),
            Zork1Tests.toGallery + ["take painting", "x painting"],
            // Seed 1, as in `cellarLoopByLanternLight`: the thief keeps away.
            seed: 1)

        let gallery = turnOutput(ofLast: "east", in: transcript)
        #expect(gallery.contains("for on the far wall is a painting of unparalleled beauty"))

        let examined = turnOutput(of: "x painting", in: transcript)
        #expect(examined.contains("There's nothing special about the painting."))
        #expect(!examined.contains("neglected genius"))
    }

    /// The sceptre half of the pair, which needs the temple route.
    @Test func theSceptreIsListedInTheCoffinAndExaminesToTheStockLine() async throws {
        let transcript = try await play(
            Zork1(),
            Zork1TempleTests.toDomeRoom + [
                "tie rope to railing", "down",  // → Torch Room
                "south", "east",  // → Temple → Egyptian Room
                "open coffin", "look",
                "take sceptre", "x sceptre",
            ],
            seed: 0)

        // The coffin's contents are listed in the sceptre's own sentence.
        #expect(
            turnOutput(of: "look", in: transcript)
                .contains("A sceptre, possibly that of ancient Egypt itself, is in the coffin."))

        let examined = turnOutput(of: "x sceptre", in: transcript)
        #expect(examined.contains("There's nothing special about the sceptre."))
        #expect(!examined.contains("tapering to a sharp point, is here"))
    }

    /// The tube and the trunk, of the same class (#617). `TUBE`'s `LDESC` and
    /// `TRUNK`'s `LDESC` had been declared as the examine text, so `x tube`
    /// answered from the player's hand in the Dam Lobby that the tube was
    /// "here". The tube has
    /// a `TEXT`, which `V-EXAMINE` and `V-READ` both print; the trunk answers
    /// `EXAMINE` through `STUPID-CONTAINER`, as the bag of coins does.
    @Test func theDamsTubeAndTrunkListAndExamineFromTheSource() async throws {
        let transcript = try await play(
            Zork1(),
            Zork1Tests.approachTheChargedDam + [
                "north", "north", "look",  // → Dam Lobby → Maintenance Room
                "take tube", "x tube", "read tube", "x toothpaste",
                "south", "examine tube",  // → Dam Lobby, the tube in hand
                "drop tube", "look",
                "south", "turn bolt with wrench", "west",  // → Dam → Reservoir South
                "wait", "wait", "wait", "wait",
                "wait", "wait", "wait", "wait",  // the eight-turn drain completes
                "north",  // onto the drained bed
                "x trunk", "take trunk",
                "south", "examine trunk",  // → Reservoir South, the trunk in hand
            ],
            seed: 39)

        #expect(
            turnOutput(of: "look", in: transcript)
                .contains("There is an object which looks like a tube of toothpaste here."))

        let label = "---> Frobozz Magic Gunk Company <---"
        for command in ["x tube", "read tube", "x toothpaste", "examine tube"] {
            let answer = turnOutput(of: command, in: transcript)
            #expect(answer.contains(label))
            #expect(answer.contains("All-Purpose Gunk"))
            #expect(!answer.contains("toothpaste here"))
        }

        // Once touched, the tube is listed in the engine's stock words; the
        // `LDESC` is `firstSight(…)` and stops at the first touch. See
        // `FIDELITY.md`.
        #expect(turnOutput(ofLast: "look", in: transcript).contains("There is a tube here."))

        #expect(
            turnOutput(ofLast: "north", in: transcript)
                .contains("Lying half buried in the mud is an old trunk, bulging with jewels."))
        for command in ["x trunk", "examine trunk"] {
            let answer = turnOutput(of: command, in: transcript)
            #expect(answer.contains("There are lots of jewels in there."))
            #expect(!answer.contains("trunk here"))
        }
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

    // MARK: - Sentences the source parses (#611)

    /// `CUT OBJECT WITH OBJECT` is the source's only CUT row (`gsyntax.zil:149`), and the knife is a weapon, so `V-CUT` reaches its last branch.
    @Test func cuttingTheRopeWithTheKnifeIsVCutsLastBranch() async throws {
        let transcript = try await play(
            Zork1(),
            [
                "north", "east", "open window", "west", "west",  // into the Living Room
                "take lamp", "turn on lamp", "east", "up",  // lit, into the Attic
                "take knife", "cut rope with knife",
            ])
        #expect(
            turnOutput(of: "cut rope with knife", in: transcript)
                .contains("Strange concept, cutting the coil of rope...."))
    }
}
