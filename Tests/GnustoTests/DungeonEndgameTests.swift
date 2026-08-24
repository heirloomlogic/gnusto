import Foundation
import GnustoTestSupport
import Testing

@testable import Dungeon
@testable import Gnusto

/// Milestone 9 — the Endgame. The thirty-one `RENDGAME` rooms, the Tomb that is
/// their front door, and the last hundred points.
///
/// **Two kinds of test, and the split is deliberate.** The mirror box's
/// geometry is a pure value type, so it is tested as one: `MirrorBox` answers
/// every question the rules ask it without a world, a seed or a turn, and an
/// off-by-forty-five-degrees there would be invisible in a transcript and would
/// make the box quietly unsolvable. Everything else is a transcript test, and
/// each of those has to walk the whole 616-point route first — the endgame's
/// door is a score test, so there is no shorter way in. ``intoTheEndgame`` is
/// that walk, shared.
struct DungeonEndgameTests {
    static let seed: UInt64 = 52

    // MARK: - The box, as a value

    /// The geometry the issue derives from the source, checked at the bearing
    /// the box starts at: mahogany at `MDIR`, pine opposite it, the openable
    /// mirror a quarter turn counterclockwise, the second mirror a quarter turn
    /// clockwise.
    @Test func theBoxsFourSidesAreWhereTheSourcePutsThem() {
        var box = MirrorBox()

        #expect(box.bearing == 270)
        #expect(box.berth == 1)
        #expect(box.pole == .inHole)
        // Standing at 270, the openable mirror faces south — which is what makes
        // the hallway room below it the one you can step into the box from.
        #expect(box.face(at: 180) == .mirror)
        #expect(box.face(at: 0) == .farMirror)
        #expect(box.face(at: 270) == .mahogany)
        #expect(box.face(at: 90) == .pine)

        box.bearing = 0
        #expect(box.face(at: 0) == .mahogany)
        #expect(box.face(at: 180) == .pine)
        #expect(box.face(at: 270) == .mirror)
        #expect(box.face(at: 90) == .farMirror)

        // A box at forty-five degrees has no face square to the hallway at all,
        // and the walking rules read that `nil` as "a corner is in your way".
        box.bearing = 45
        #expect(box.face(at: 0) == nil)
        #expect(!box.isEndOn)
    }

    /// The pole has three resting places and only one of them satisfies the
    /// Guardians. The round hole is `MRB` at the starting bearing and nowhere
    /// else; the channel is any berth with the box square to the hallway.
    @Test func thePoleSettlesWhereTheBoxIsStanding() {
        var box = MirrorBox()
        #expect(box.restingPlace == .inHole)

        box.bearing = 0
        #expect(box.restingPlace == .inChannel)

        box.berth = 3
        box.bearing = 180
        #expect(box.restingPlace == .inChannel)

        box.bearing = 90
        #expect(box.restingPlace == .onFloor)

        // And the hole is the second berth's alone.
        box.berth = 2
        box.bearing = 270
        #expect(box.restingPlace == .onFloor)
    }

    /// The Guardians let a box past on four conditions at once, and every one of
    /// them is necessary. Dropping any single one is fatal.
    @Test func theGuardiansWantAllFourConditionsTogether() {
        var box = MirrorBox()
        box.bearing = 0
        box.pole = .inChannel
        #expect(box.isSafeToPassTheGuardians)

        for spoil in [
            { (box: inout MirrorBox) in box.pole = .onFloor },
            { $0.pole = .raised },
            { $0.mirrorIntact = false },
            { $0.farMirrorIntact = false },
            { $0.mirrorOpen = true },
            { $0.pineOpen = true },
        ] {
            var spoiled = box
            spoil(&spoiled)
            #expect(!spoiled.isSafeToPassTheGuardians)
        }
    }

    /// Opening the pine end is fatal wherever the Guardians can see that end:
    /// in their own room always, one room north of them when it faces south,
    /// one room south of them when it faces north. Nowhere else.
    @Test func thePineEndMayNotBeOpenedInTheirView() {
        var box = MirrorBox()

        box.berth = MirrorBox.guardedBerth
        for bearing in stride(from: 0, to: 360, by: 45) {
            box.bearing = bearing
            #expect(box.pineOpensInTheirView, "bearing \(bearing) in their own room")
        }

        // `MRD`, one north of them. The pine end faces south at `MDIR` 0.
        box.berth = MirrorBox.guardedBerth + 1
        box.bearing = 0
        #expect(box.pineOpensInTheirView)
        box.bearing = 180
        #expect(!box.pineOpensInTheirView)

        // `MRC`, one south of them. The other way round.
        box.berth = MirrorBox.guardedBerth - 1
        box.bearing = 180
        #expect(box.pineOpensInTheirView)
        box.bearing = 0
        #expect(!box.pineOpensInTheirView)

        // And at the far end of the run they cannot see it at all.
        box.berth = 0
        for bearing in stride(from: 0, to: 360, by: 45) {
            box.bearing = bearing
            #expect(!box.pineOpensInTheirView, "bearing \(bearing) two rooms away")
        }
    }

    /// The box slides only along the channel, only when it is square to it, and
    /// it stops at both ends of the run.
    @Test func theBoxOnlySlidesWhenItIsSquareToTheChannel() {
        var box = MirrorBox()
        box.bearing = 270
        #expect(box.berthAhead == nil)

        box.bearing = 0
        #expect(box.berthAhead == 2)
        box.bearing = 180
        #expect(box.berthAhead == 0)

        // The mahogany end points the way it goes, so the far end of the run
        // has nowhere further to be pushed.
        box.berth = MirrorBox.berthCount - 1
        box.bearing = 0
        #expect(box.berthAhead == nil)
        box.berth = 0
        box.bearing = 180
        #expect(box.berthAhead == nil)
    }

    /// A stale save has to degrade rather than trap, the way ``RoyalPuzzleGrid``
    /// does: `Global`'s getter `fatalError`s on a payload it cannot decode.
    @Test func aBoxDecodedFromRubbishKeepsItsDefaults() throws {
        let rubbish = try #require(#"{"bearing":"north"}"#.data(using: .utf8))
        let box = try JSONDecoder().decode(MirrorBox.self, from: rubbish)

        #expect(box.bearing == 270)
        #expect(box.berth == MirrorBox.holeBerth)
        #expect(box.pole == .inHole)
        #expect(box.mirrorIntact)
    }

    // MARK: - The ceiling

    /// The last hundred points are all room value, and the award table has to
    /// carry every one of them or `awardOnce` traps rather than paying zero.
    @Test func theEndgamesHundredIsAllRoomValue() throws {
        let (definition, _) = try Bootstrap.build(Dungeon())

        #expect(definition.maxScore == 716)
        #expect(definition.warnings.isEmpty, "\(definition.warnings)")

        let awards = Dungeon().scoring.awards
        let endgame = [
            "crypt": 5, "topOfStairs": 10, "insideMirror": 15,
            "dungeonEntrance": 15, "narrowCorridor": 20, "treasuryOfZork": 35,
        ]
        for (register, points) in endgame {
            #expect(awards[register] == points, "\(register)")
        }
        #expect(endgame.values.reduce(0, +) == 100)

        // No endgame object carries a value. `EG-SCORE-MAX` is room `RVAL` and
        // nothing else, so the treasure roster does not move.
        #expect(Dungeon().treasureRoster.count == 32)
    }

    // MARK: - The way in

    /// The whole 616-point route, then the fifteen turns the herald takes, then
    /// the walk from the Living Room to the Tomb by way of the granite wall and
    /// the gate of Hades.
    ///
    /// There is no shorter way in and there is not meant to be: `SCORE-BLESS`
    /// arms the herald on the score alone, and the herald is what makes the
    /// marble door open instead of killing you.
    static let intoTheEndgame: [String] =
        Array(DungeonWalkthroughTests.route.dropLast(2))
        + Array(repeating: "wait", count: 15)
        + [
            "turn on lamp", "west", "south", "up", "temple",
            "west", "east", "south", "down", "east", "east",
        ]

    /// The same, plus the crypt: shut the door, put the lamp out, and wait for
    /// the voice.
    static let pastTheCrypt: [String] =
        intoTheEndgame + [
            "open crypt", "north", "close crypt", "turn off lamp",
            "wait", "wait", "wait",
        ]

    // MARK: - The Tomb and the Crypt

    /// The herald, the marble door, and the fact that the same door was fatal
    /// an hour ago. `HEAD-FUNCTION` answers every verb on it until
    /// `END-GAME!-FLAG` is set, and what it answers with is your death.
    @Test func theHeraldOpensADoorThatWouldOtherwiseHaveKilledYou() async throws {
        let transcript = try await play(Dungeon(), Self.intoTheEndgame, seed: Self.seed)

        expectInOrder(
            transcript,
            [
                "Your score is 616 of a possible 716",
                "You are one of the chosen of Zork",
                "the way to the Dungeon Master lies",
                "Tomb of the Unknown Implementer",
                "shut off by a slab of marble",
            ])
        expectEveryNounAnswered(transcript, "the Tomb of the Unknown Implementer")
    }

    /// The heads. Touching, taking, attacking, burning, opening or rubbing them
    /// is fatal — and `rub` is a synonym of `touch` in this engine as in the
    /// source, so `touch heads` is the trap without ever being spelled out.
    @Test func touchingTheHeadsKillsYou() async throws {
        let transcript = try await play(
            Dungeon(), Self.intoTheEndgame + ["touch heads"], seed: Self.seed)

        #expect(transcript.contains("is lifted quietly away and gone"))
        // The Tomb is still on this side of the crypt, so a death here is an
        // ordinary one: the mainframe's ten points and the walk back from the
        // forest. Only past the crypt is it final.
        #expect(transcript.contains("you find yourself standing among the trees"))
    }

    /// The transition. Three turns of a shut, dark crypt and you are somewhere
    /// else with exactly two things: the lamp, refilled and switched off, and
    /// the sword. The Crypt's five and the stairs' ten are paid.
    @Test func theCryptEmptiesYourHandsAndPaysItsFifteen() async throws {
        let transcript = try await play(
            Dungeon(), Self.pastTheCrypt + ["inventory", "score"], seed: Self.seed)

        expectInOrder(
            transcript,
            [
                "The door must weigh a ton",
                "Crypt",
                "You have passed",
                "Top of Stairs",
                "You are carrying a brass lantern and an elvish sword.",
                "Your score is 631 of a possible 716",
            ])
    }

    /// The grue goes out with the light and comes back with the door.
    ///
    /// The Crypt is the one room in the game whose solution is to stand in the
    /// dark on purpose, so shutting the door suspends `DangerousDark` — and
    /// changing your mind has to hand the dark back, or the player has bought
    /// permanent safety with a door they can open. Reopening it re-arms the
    /// three-turn fuse's cancellation *and* the grue; lingering in the dark
    /// Crypt on this side of the transition kills you as any dark room would.
    ///
    /// Suspending is `DangerousDark/suspended`, not `stopDaemon("grue")`:
    /// stopping freezes the dark-turn count, so a player who shut the door
    /// already deep in the dark would come back out onto a dice turn with no
    /// warning. `DangerousDarkTests` pins that invariant directly.
    @Test func reopeningTheCryptHandsTheDarkBack() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.intoTheEndgame + [
                "open crypt", "north", "turn off lamp", "close crypt",
                "open crypt",
            ] + Array(repeating: "wait", count: 8),
            seed: Self.seed)

        // The door shut and opened again, and no transition: the fuse was
        // cancelled, so the Crypt never took him anywhere.
        #expect(!transcript.contains("You have passed"))
        #expect(!transcript.contains("Top of Stairs"))
        // And the dark is dangerous again.
        #expect(transcript.contains("slavering fangs of a lurking grue"))
    }

    // MARK: - The mirror box

    /// The whole northward run: break the beam, press the button, step through
    /// the mirror, turn the box north, drop the pole into the channel, and push
    /// it three rooms — the third of which is the Guardians'.
    ///
    /// The mirror's seven turns are what makes this a clock rather than a
    /// sequence: it has shut again by the time the box reaches them, which is
    /// one of the four conditions they insist on.
    @Test func theBoxCarriesYouPastTheGuardians() async throws {
        let transcript = try await play(
            Dungeon(), Self.pastTheCrypt + Self.throughTheBox + ["score"], seed: Self.seed)

        expectInOrder(
            transcript,
            [
                "The button clicks",
                "The beam stops short",
                "Inside Mirror",
                "The pole comes up out of the floor",
                "The arrow is pointing north.",
                "seats itself in the stone channel",
                "The box slides smoothly",
                "fierce blue light",
                "The pine wall swings out",
                "Dungeon Entrance",
                "Your score is 661 of a possible 716",
            ])
        #expect(!transcript.contains("The Guardians"))
        expectEveryNounAnswered(transcript, "the mirror box and the hallway")
    }

    /// **The pine end names the room it opens on.** The line used to say
    /// "Beyond it is the hallway" whatever the box was standing across, which is
    /// only true when the box has been turned square to the channel. At the
    /// opening bearing the pine end faces east, into a narrow room — the frame
    /// the 2026-08-11 round (#233) caught it printing in, one turn before
    /// stepping east into the room it had just called a hallway.
    @Test func thePineEndNamesWhatIsBeyondIt() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.pastTheCrypt + Self.toTheOpenMirror + ["in", "push pine", "east"],
            seed: Self.seed)

        expectInOrder(
            transcript,
            [
                "Inside Mirror",
                "The pine wall swings out on its hinges. Beyond it is the Narrow Room.",
                "Narrow Room",
            ])
        #expect(!transcript.contains("Beyond it is the hallway"))
    }

    /// **The two halves of one doorway agreed all along about the mirror, and
    /// only about the mirror.** `MIRIN` lets you in through the mirror alone;
    /// `MIROUT` lets you out through either end. Nothing pinned that, so a
    /// contributor reading the disagreement as a bug could have "fixed" it by
    /// making the pine end an entrance, which the source is against. (#233)
    @Test func onlyTheMirrorIsAWayIntoTheBox() {
        var box = MirrorBox()
        box.mirrorOpen = true
        box.pineOpen = true

        // At the opening bearing the mirror faces south and the pine end east.
        // Both are gaps, and every sentence about the box says so; only one of
        // them is a way in, and every step asks that of the face rather than of
        // the angle.
        #expect(box.openFace(at: 180) == .mirror)
        #expect(box.openFace(at: 90) == .pine)
        #expect(box.openFace(at: 270) == nil)
        #expect(box.openFace(at: 180)?.admitsEntry == true)
        #expect(box.openFace(at: 90)?.admitsEntry == false)

        box.mirrorOpen = false
        #expect(box.openFace(at: 180) == nil)
        #expect(box.openFace(at: 90) == .pine)

        // And the glass that decides a refusal is the glass on that face.
        box.mirrorIntact = false
        #expect(!box.glassIsIntact(at: 180))
        #expect(box.glassIsIntact(at: 0))
    }

    /// **The pine end shuts behind you as you step out of it.** It did not, so
    /// the wooden end stayed swung open in a hallway that would not let anybody
    /// back in — "There is no opening in the side facing you.", said to the
    /// player who had walked through that face the turn before. The source has
    /// the missing line, and the refusal it leaves behind is a claim about the
    /// side actually in the way. (#233)
    @Test func thePineEndShutsBehindYouAndTheRefusalSaysWhatIsInTheWay() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.pastTheCrypt + Self.toTheOpenMirror + ["in", "push pine", "x pine wall", "east"]
                + ["x box", "in"],
            seed: Self.seed)

        expectInOrder(
            transcript,
            [
                "The pine wall swings out on its hinges.",
                "As you leave, the door swings shut.",
                "Narrow Room",
            ])

        // `turnOutput` is no use this deep in: the route is the 716-point
        // walkthrough, so every short command has been typed before. The
        // closing line is unique, and the two sides of it are the two frames.
        let halves = transcript.components(separatedBy: "As you leave, the door swings shut.")
        let inside = halves[0]
        let outside = halves[1]

        // Inside, with it open, the wall says so — the control.
        #expect(inside.contains("stands swung open on its hinges, and there is a way through"))

        // Outside, it is a wall again, it says which wall, and the box no longer
        // offers a doorway it will not honour.
        #expect(outside.contains("a wall of pale pine"))
        #expect(!outside.contains("swung open"))
        #expect(outside.contains("The structure blocks your way."))
        #expect(!transcript.contains("There is no opening in the side facing you"))
    }

    /// **"The walls of the box are shut on every side of you." is a claim, and
    /// two frames make it false.** A named direction with the other end open is
    /// a wall that is shut, not a box that is; and a box standing on a diagonal
    /// has its opening on the corner where two walls meet, which `push pine`
    /// and `push mahogany` both say for themselves one turn earlier. `out` said
    /// the box was shut on every side, with a mirror standing open in it.
    /// (#280/#286 class 1)
    @Test func aBoxWithAWayOutSaysWhichWayIsShutAndWhereItGives() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.pastTheCrypt + Self.toTheOpenMirror
                + ["in", "north", "raise pole", "push red panel", "lower pole"]
                + ["push pine", "out"],
            seed: Self.seed)

        // The route is the 716-point walkthrough, so every short command has
        // been typed before it: split on the box's own unique lines instead.
        let inside = output(after: "Inside Mirror", in: transcript)
        #expect(inside.contains("That wall of the box is shut."))
        #expect(inside.contains("The opening gives on the corner where two walls meet"))
        #expect(!inside.contains("The walls of the box are shut on every side of you."))
    }

    /// **With both ends open, you leave by the door you asked for.** The two
    /// tests were written as separate `if`s rather than a choice, so the pine end
    /// shadowed the mirror: `south` out of a box whose mirror stood open to the
    /// south answered "The walls of the box are shut on every side of you."
    /// (#233)
    @Test func anOpenPineEndDoesNotBlockTheOpenMirror() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.pastTheCrypt + Self.toTheOpenMirror + ["in", "push pine", "south", "look"],
            seed: Self.seed)

        // Everything after the pine end opens, for the reason the test above
        // gives: this route has typed every short command already.
        let afterOpening = transcript.components(
            separatedBy: "The pine wall swings out on its hinges.")[1]
        #expect(!afterOpening.contains("The walls of the box are shut on every side of you."))
        // Back out where the mirror let you in, and the hallway now reports the
        // opening it never used to mention at all.
        #expect(afterOpening.contains("Hallway"))
        #expect(afterOpening.contains("The mirror on this side is swung open."))
    }

    /// And the box answers the verb by its name, not just by the direction: with
    /// the mirror open beside you, `enter box` is the way in. Left alone it fell
    /// to the game-wide answer for a thing that is neither doorway nor vehicle,
    /// which is a strange thing to say about a box you are about to walk into.
    @Test func theBoxCanBeEnteredByName() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.pastTheCrypt + Self.toTheOpenMirror + ["enter box"],
            seed: Self.seed)

        let arrival = transcript.components(separatedBy: "> enter box")[1]
        #expect(arrival.contains("Inside Mirror"))
        #expect(!arrival.contains("as you attempt this feat"))
    }

    /// **The blade reports the danger, not your grip on it.** Putting the sword
    /// down one berth from the Guardians printed "The blue light goes out of the
    /// sword", and picking it straight back up printed the warning again — two
    /// sentences about a danger that had not moved, on turns when only the
    /// player's hands had. The daemon now asks whether the sword is
    /// *perceivable*, which is `DungeonHouse/timers`' question about the
    /// lantern. (#233)
    @Test func theSwordReportsTheDangerAndNotYourGripOnIt() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.pastTheCrypt + Self.throughTheBoxToMRD
                // *blade*, not *sword*: the 616-point route this is built on
                // already spends "take sword", and `turnOutput` matches the
                // first occurrence of a command.
                + ["drop blade", "take blade"] + Self.outOfTheBox,
            seed: Self.seed)

        // The controls, at both ends of the ride: the danger really was
        // reported on the way in, and really is reported on the way out.
        expectInOrder(
            transcript,
            [
                "The sword has come up to a fierce blue light.",
                "The sword shows a faint blue edge.",
                "The blue light goes out of the sword.",
            ])

        // And nothing at all from the two turns that only changed hands.
        let dropped = turnOutput(of: "drop blade", in: transcript)
        #expect(dropped.contains("Dropped."))
        #expect(!dropped.contains("blue"))
        let taken = turnOutput(of: "take blade", in: transcript)
        #expect(taken.contains("Taken."))
        #expect(!taken.contains("blue"))
    }

    /// **A sword you have walked away from says nothing.** Its light did not go
    /// out; you left the room it is lighting. The record goes back to nothing
    /// silently, so the next sight of the blade warns again. (#233)
    @Test func aSwordLeftBehindGoesQuietRatherThanGoingOut() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.pastTheCrypt + Self.throughTheBoxToMRD
                + Self.outOfTheBox.dropLast() + ["drop blade", "out"],
            seed: Self.seed)

        // The control: it was glowing, and it was still glowing when it was put
        // down inside the box.
        #expect(transcript.contains("The sword shows a faint blue edge."))
        #expect(!turnOutput(of: "drop blade", in: transcript).contains("blue"))
        // And stepping out of the box, leaving it behind, is not the light
        // going out.
        #expect(!turnOutput(of: "out", in: transcript).contains("The blue light goes out"))
    }

    /// **`x sword` is the one command a player would use to check the warning,
    /// and it said nothing about it.** `SWORD-FCN` answers EXAMINE with the glow
    /// in the source too; the blade here keeps its own description and gains a
    /// clause. Cross-bundle, so the rule is the host's. (#233)
    @Test func theSwordsDescriptionCarriesWhatItIsDoing() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.pastTheCrypt + ["x blade"] + Self.throughTheBoxToMRD
                + ["examine blade"],
            seed: Self.seed)

        // At the top of the stairs it is a sword and nothing more.
        let quiet = turnOutput(of: "x blade", in: transcript)
        #expect(quiet.contains("A long elvish blade"))
        #expect(!quiet.contains("blue"))
        // One berth past the Guardians it is a sword that is doing something.
        let glowing = turnOutput(of: "examine blade", in: transcript)
        #expect(glowing.contains("A long elvish blade"))
        #expect(glowing.contains("A faint blue edge runs the length of it."))
    }

    /// Walking into the Guardians' reach on foot is fatal, and death in the
    /// endgame is final however many resurrections were left over.
    @Test func walkingIntoTheGuardiansKillsYouForGood() async throws {
        // Down the hallway on foot as far as it goes: past the box on the
        // diagonal, then north again into their room.
        let transcript = try await play(
            Dungeon(),
            Self.pastTheCrypt + Self.throughTheBox + ["southwest"],
            seed: Self.seed)

        // The box is standing in `MRD` now, end-on, so a diagonal out of the
        // Dungeon Entrance squeezes past it — into the narrow room beside it,
        // which is inside the Guardians' reach.
        //
        // The statue's own line ahead of the banner: the death is raised by the
        // room's `onEnter` rule, reached through `enter(_:)`, rather than by a
        // check standing in front of the move — and the transcript must not be
        // able to tell which.
        expectInOrder(transcript, ["the nearer statue moves", "*** You have died ***"])
        // And death past the crypt is final: no ten-point toll, no forest.
        #expect(!transcript.contains("you find yourself standing among the trees"))
    }

    /// Breaking a mirror does not kill you and does not refuse. It simply makes
    /// the game unwinnable, which is the source's own answer, and the box says
    /// so plainly enough that a player knows what they have done.
    @Test func breakingAMirrorIsAllowedAndCostsTheGame() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.pastTheCrypt + [
                "down", "north", "drop lamp", "south", "push red button",
                "north", "north", "in", "attack first mirror with sword",
                "examine first mirror", "raise pole", "push red panel",
                "push red panel", "lower pole", "push mahogany", "push mahogany",
            ],
            seed: Self.seed)

        #expect(transcript.contains("The glass goes down in a sheet"))
        #expect(transcript.contains("You have died"))
    }

    // MARK: - The Dungeon Master

    /// Three questions drawn from eight, and the door opens on the third right
    /// answer. Seed 52 draws the robber's hideaway, "Hello, Sailor!" and the
    /// Altar, in that order.
    @Test func threeRightAnswersOpenTheWoodenDoor() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.pastTheCrypt + Self.throughTheBox + Self.theQuiz + ["north", "score"],
            seed: Self.seed)

        expectInOrder(
            transcript,
            [
                "three questions stand",
                "robber's hideaway",
                "\"Correct,\" says the voice.",
                "Hello, Sailor!",
                "Beside the Temple",
                "You may pass.",
                "Narrow Corridor",
                "Your score is 681 of a possible 716",
            ])
    }

    /// **He waits a turn before he repeats himself, and a knock restarts the
    /// wait.** Knocking with a question outstanding puts the question again —
    /// and the daemon, whose patience was already half spent, then put it a
    /// *second* time on the same turn, prefaced by "The voice waits". The
    /// right-answer path guards against exactly this and says so in a comment;
    /// the re-knock path was the same case with the fix missing. (#233)
    @Test func aSecondKnockRestartsTheVoicesPatience() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.pastTheCrypt + Self.throughTheBox + [
                // *oaken*, not a second "knock on door": `turnOutput` matches
                // the first occurrence of a command.
                "knock on door", "knock on oaken door", "examine oaken door", "listen",
            ],
            seed: Self.seed)

        // He answers the knock with the question he is still waiting on, once,
        // and does not also complain that you have kept him waiting.
        let reknock = turnOutput(of: "knock on oaken door", in: transcript)
        #expect(occurrences(of: "robber's hideaway", in: reknock) == 1)
        #expect(!reknock.contains("The voice waits, and then puts the question again."))

        // The control, both ways: the clock restarted rather than stopping. The
        // repeat lands one turn later, and the turn after that is quiet again.
        #expect(
            turnOutput(of: "examine oaken door", in: transcript)
                .contains("The voice waits, and then puts the question again."))
        #expect(!turnOutput(of: "listen", in: transcript).contains("The voice waits"))
    }

    /// Five wrong answers to one question ends the examination for good, and
    /// nothing afterwards reopens it.
    @Test func fiveWrongAnswersEndTheExaminationForGood() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.pastTheCrypt + Self.throughTheBox + [
                // Five that are all wrong for the question seed 52 puts first,
                // which is the robber's hideaway and answers to *temple*.
                "knock on door", "answer forest", "answer flask", "answer rub",
                "answer skeleton", "answer knife", "knock on door", "open door",
            ],
            seed: Self.seed)

        #expect(transcript.contains("You have had answers enough"))
        #expect(transcript.contains("has finished with you"))
    }

    // MARK: - The prison, and the end of it

    /// The solve entire: dock cell four, leave the Dungeon Master on the
    /// parapet, get into the cell, and from inside it order him to send the
    /// carousel somewhere else. You ride cell four out of the slot, and cell
    /// four is the one with the bronze door.
    @Test func ridingCellFourOutOfTheSlotWinsTheGame() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.pastTheCrypt + Self.throughTheBox + Self.theQuiz + Self.thePrison,
            seed: Self.seed)

        expectInOrder(
            transcript,
            [
                "Parapet",
                "comes to rest at four",
                "a cell has come around",
                "nods and stands where he is",
                "Prison Cell",
                "a door of bronze",
                "Somewhere above you the dial turns",
                "the whole cell begins to move",
                "Treasury of Zork",
                "You are Master of the Dungeon.",
                "Your score is 716 of a possible 716",
            ])
        expectEveryNounAnswered(transcript, "the prison and the Treasury of Zork")
    }

    /// He carries an order out in his own room, which is the whole reason he
    /// exists — and he will not set foot in a cell, which is what makes the
    /// order necessary.
    @Test func theDungeonMasterObeysFromARoomYouAreNotIn() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.pastTheCrypt + Self.throughTheBox + Self.theQuiz + [
                "north", "west", "north", "north", "dungeon master, stay",
                "south", "dungeon master, south", "attack dungeon master with sword",
            ],
            seed: Self.seed)

        #expect(transcript.contains("The Dungeon Master nods and stands where he is."))
        #expect(transcript.contains("You have died"))
    }

    /// `set dial to four` is the source's own spelling, and it went missing for a
    /// milestone: naming a number needs one object per number, and issue #174's
    /// stack budget could not afford eight more. The budget is a real number now
    /// and they are back — by word, by digit, and refusing anything that is not a
    /// number at all rather than rounding it to one.
    @Test func theDialTakesANumberByNameAndByDigit() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.pastTheCrypt + Self.throughTheBox + Self.theQuiz + [
                "north", "north", "west", "north",
                // One room short of the parapet: the numerals are on the dial's
                // face, so `four` is a thing there and nowhere else in the game.
                "examine four",
                "north",
                "set dial to four", "read dial",
                "set dial to 7", "read dial",
                "set dial to sword",
                "examine four",
            ],
            seed: Self.seed)

        expectInOrder(
            transcript,
            [
                "You can't see any such thing",
                "comes to rest at four",
                "The pointer stands at four.",
                "comes to rest at seven",
                "The pointer stands at seven.",
                "The dial takes a number from one to eight, and nothing else.",
                "A numeral cut into the stone",
            ])
    }

    /// `knock` is the game's own default answer, not this bundle's interception
    /// of every knock anywhere — a door somewhere else has to be able to answer
    /// for itself, which claiming the whole intent made impossible for good.
    ///
    /// It is also `V-KNOCK`'s two branches, in one transcript. The front door is
    /// a door and gets the door line; the mailbox is not and gets named. Both
    /// commands are typed in the same room, so the only thing that separated
    /// them is the thing being knocked on. (#247)
    @Test func knockingAnywhereElseGetsTheGamesOwnAnswer() async throws {
        let transcript = try await play(
            Dungeon(),
            ["knock on door", "knock on mailbox"],
            seed: Self.seed)

        expectInOrder(
            transcript,
            [
                "You knock, and nobody answers.",
                "You knock on the small mailbox. It is not something that answers.",
            ])
        #expect(occurrences(of: "You knock, and nobody answers.", in: transcript) == 1)
    }

    // MARK: - The route, in pieces

    /// The mirror box, from the Top of Stairs to the Dungeon Entrance.
    static let throughTheBox: [String] = throughTheBoxToMRD + outOfTheBox

    /// Down to the Stone Room, the lamp left where it breaks the beam, the red
    /// button pushed, and up the hallway to the room the open mirror faces. The
    /// head of ``throughTheBoxToMRD``, named because five tests stand here.
    static let toTheOpenMirror: [String] = [
        "down", "north", "drop lamp", "south", "push red button",
        "north", "north",
    ]

    /// The first half of that ride, stopping with the box at `MRD` — one berth
    /// past the Guardians, so the blade is at its faint rung and a test has a
    /// frame where a dropped sword would be wrong about something.
    static let throughTheBoxToMRD: [String] =
        toTheOpenMirror + [
            "in",
            "raise pole", "push red panel", "push red panel", "lower pole",
            "push mahogany", "push mahogany", "push mahogany",
        ]

    /// And the second: turn the box back end-on the other way, open the pine
    /// end and step out of it.
    static let outOfTheBox: [String] = [
        "raise pole", "push red panel", "push red panel", "push red panel",
        "push red panel", "lower pole", "push pine", "north",
    ]

    /// Knocking, and seed 52's three answers. The voice draws its three from
    /// eight by rejection sampling (`Endgame+Master.swift`), so both which
    /// questions are asked and how many draws that costs move with the seed —
    /// which is why this list is re-derived rather than re-ordered whenever the
    /// walkthrough's seed does.
    static let theQuiz: [String] = [
        "knock on door", "answer temple", "answer nowhere", "answer forest",
    ]

    /// The corridors, the sundial, and the cell that rides out of the slot.
    static let thePrison: [String] = [
        "north", "north", "west", "north", "north",
        "turn dial", "turn dial", "turn dial",
        "push button", "dungeon master, stay",
        "south", "open cell door", "south",
        "dungeon master, turn dial", "dungeon master, push button",
        "open bronze door", "north",
    ]
}
