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
    static let seed: UInt64 = 2

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
            Self.pastTheCrypt
                + ["down", "north", "drop lamp", "south", "push red button"]
                + ["north", "north", "in", "push pine", "east"],
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
    /// answer. Seed 2 draws the Altar, "Hello, Sailor!" and the haunted object,
    /// in that order.
    @Test func threeRightAnswersOpenTheWoodenDoor() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.pastTheCrypt + Self.throughTheBox + Self.theQuiz + ["north", "score"],
            seed: Self.seed)

        expectInOrder(
            transcript,
            [
                "three questions stand",
                "Beside the Temple",
                "\"Correct,\" says the voice.",
                "Hello, Sailor!",
                "haunted",
                "You may pass.",
                "Narrow Corridor",
                "Your score is 681 of a possible 716",
            ])
    }

    /// Five wrong answers to one question ends the examination for good, and
    /// nothing afterwards reopens it.
    @Test func fiveWrongAnswersEndTheExaminationForGood() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.pastTheCrypt + Self.throughTheBox + [
                "knock on door", "answer temple", "answer flask", "answer rub",
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

    /// `knock` is the game's own default answer now, not this bundle's
    /// interception of every knock anywhere. The line a player sees is the same;
    /// what changed is that a door somewhere else can answer for itself, which a
    /// `world.before` rule made impossible for good.
    @Test func knockingAnywhereElseGetsTheGamesOwnAnswer() async throws {
        let transcript = try await play(
            Dungeon(),
            ["knock on door", "knock on mailbox"],
            seed: Self.seed)

        #expect(occurrences(of: "You knock, and nobody answers.", in: transcript) == 2)
        #expect(!transcript.contains("Nobody answers."))
    }

    // MARK: - The route, in pieces

    /// The mirror box, from the Top of Stairs to the Dungeon Entrance.
    static let throughTheBox: [String] = [
        "down", "north", "drop lamp", "south", "push red button",
        "north", "north", "in",
        "raise pole", "push red panel", "push red panel", "lower pole",
        "push mahogany", "push mahogany", "push mahogany",
        "raise pole", "push red panel", "push red panel", "push red panel",
        "push red panel", "lower pole", "push pine", "north",
    ]

    /// Knocking, and seed 2's three answers.
    static let theQuiz: [String] = [
        "knock on door", "answer forest", "answer nowhere", "answer knife",
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
